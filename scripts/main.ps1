$Host.UI.RawUI.WindowTitle = "Berry IT WinForge Utility"
Clear-Host

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase

# Load the configuration files

$sync.configs.applicationsHashtable = @{}
$sync.configs.applications.PSObject.Properties | ForEach-Object {
    $sync.configs.applicationsHashtable[$_.Name] = $_.Value
}

$sync.configs.appxHashtable = @{}
$sync.configs.appx.PSObject.Properties | ForEach-Object {
    $sync.configs.appxHashtable[$_.Name] = $_.Value
}
$sync.preferences.theme = "Auto"
$sync.preferences.packagemanager = "Winget"

function Remove-WinUtilTempScript {
    <#
    .SYNOPSIS
        Removes the temporary script downloaded by windev.ps1.

    .DESCRIPTION
        Deletes the current script only when it is a winutil-*.ps1 file in
        the system temporary directory. This preserves normal file-backed
        and in-memory WinUtil launches.
    #>

    $scriptPath = $PSCommandPath
    $tempPath = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')

    if (
        $scriptPath -and
        [IO.Path]::GetDirectoryName($scriptPath) -eq $tempPath -and
        [IO.Path]::GetFileName($scriptPath) -like 'winutil-*.ps1'
    ) {
        Remove-Item -LiteralPath $scriptPath -Force -ErrorAction SilentlyContinue
    }
}

#===========================================================================
# Headless runs never build a window
#===========================================================================

if ($Preset -or $Config) {
    $headlessCode = 1
    try {
        Initialize-WinUtilRunspacePool | Out-Null

        if ($Preset) {
            if (-not $sync.configs.preset.$Preset) {
                throw "There is no preset called '$Preset'. Available: $(($sync.configs.preset.PSObject.Properties.Name) -join ', ')"
            }
            Write-WinUtilLog -Component "AutoRun" -Message "Applying preset '$Preset'."
            # SkipUnknown so a retired entry in a preset is named and stepped over rather than
            # ending a headless run that has nobody to read the error
            $skipped = @(Update-WinUtilSelections -flatJson $sync.configs.preset.$Preset -SkipUnknown)
            if ($skipped.Count -gt 0) {
                Write-WinUtilLog -Level "WARN" -Component "AutoRun" -Message "Preset '$Preset' names $($skipped.Count) entr(y/ies) this version does not have: $($skipped -join ', ')"
            }
        }

        # Both may be given: the preset sets a baseline and the config adds to it
        if ($Config) {
            Write-WinUtilLog -Component "AutoRun" -Message "Importing selections from '$Config'."
            Invoke-WPFImpex -type "import" -Config $Config -Merge:([bool]$Preset) -ThrowOnError
        }

        $summary = Invoke-WinUtilAutoRun
        $headlessCode = Write-WinUtilAutoRunSummary -Summary $summary
    } catch {
        Write-WinUtilErrorRecord -ErrorRecord $_ -Component "AutoRun" -Context "Headless run"
        Write-Host "WinUtil could not complete the headless run: $($_.Exception.Message)" -ForegroundColor Red
        $headlessCode = 1
    } finally {
        Close-WinUtilRunspacePool
        [System.GC]::Collect()
        Remove-WinUtilTempScript
        Stop-Transcript | Out-Null
    }

    # An isolated elevated child and an explicit file launch own their process. The documented
    # in-memory invocation runs inside the caller's terminal and must return without closing it.
    if ($env:WINUTIL_HEADLESS_CHILD -eq "1" -or $script:WinUtilIsFileProcess) {
        exit $headlessCode
    }
    $global:LASTEXITCODE = $headlessCode
    return $headlessCode
}

#===========================================================================
# Start the interface on its own thread and manage it from here
#===========================================================================
#
# The main thread stays out of the window's way. It creates the dedicated STA runspace the
# interface lives on, waits for that window to close, and reports anything the interface
# thread failed with. Work started from the interface goes to the worker pool through
# Start-WinUtilJob, so neither the window nor this thread is ever blocked by it.

# Show the splash only for interactive UI launches (never for -Preset / -Config).
# UI runs on its existing STA runspace; the current STA thread owns the splash.
$sync.WinForgeUIBuilt = $false
$sync.WinForgeUIReady = $false
$sync.WinForgeUIStartupFailed = $false

[xml]$splashXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Berry IT WinForge Utility"
        Width="620"
        Height="360"
        WindowStartupLocation="CenterScreen"
        WindowStyle="None"
        ResizeMode="NoResize"
        ShowInTaskbar="False"
        Topmost="True"
        AllowsTransparency="True"
        Background="Transparent"
        UseLayoutRounding="True">
    <Border CornerRadius="18"
            Background="#111111"
            BorderBrush="#D00000"
            BorderThickness="2"
            Padding="26">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <Border Grid.Row="0"
                    Background="#1A1A1A"
                    CornerRadius="10"
                    Padding="12,6"
                    HorizontalAlignment="Right">
                <TextBlock Text="BERRY IT"
                           Foreground="#FF3C3C"
                           FontWeight="Bold"
                           FontSize="12"/>
            </Border>

            <StackPanel Grid.Row="1"
                        VerticalAlignment="Center"
                        HorizontalAlignment="Center"
                        Margin="0,10,0,10">

                <Border Width="260"
                        Height="90"
                        CornerRadius="16"
                        Background="#444444"
                        BorderBrush="#333333"
                        BorderThickness="1"
                        Padding="16"
                        Margin="0,0,0,20">
                    <Viewbox Stretch="Uniform">
                        <Grid x:Name="LogoHost"/>
                    </Viewbox>
                </Border>

                <TextBlock Text="WINFORGE UTILITY"
                           Foreground="White"
                           FontSize="28"
                           FontWeight="Bold"
                           HorizontalAlignment="Center"/>

                <TextBlock Text="Windows management, optimisation and configuration"
                           Foreground="#D0D0D0"
                           FontSize="13"
                           Margin="0,10,0,0"
                           HorizontalAlignment="Center"/>
            </StackPanel>

            <StackPanel Grid.Row="2"
                        Margin="0,10,0,0">
                <ProgressBar x:Name="SplashProgress" Height="8" Minimum="0" Maximum="100" Value="0" IsIndeterminate="False" Foreground="#FF3030" Background="#303030" BorderThickness="0"/>
                <DockPanel Margin="0,10,0,0">
                    <TextBlock Text="Initialising WinForge..."
                               Foreground="#FF3C3C"
                               FontSize="11"
                               DockPanel.Dock="Left"/>
                    <TextBlock Text="Launching WinForge"
                               Foreground="#A8A8A8"
                               FontSize="11"
                               DockPanel.Dock="Right"
                               HorizontalAlignment="Right"/>
                </DockPanel>
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $splashXaml
$splashWindow = [Windows.Markup.XamlReader]::Load($reader)

$logoHost = $splashWindow.FindName("LogoHost")
$logoAsset = Invoke-WinUtilAssets -Type "logo" -Size 200

# Use the embedded bitmap directly without the square sizing
$splashLogo = New-Object System.Windows.Controls.Image
$splashLogo.Source = $logoAsset.Source
$splashLogo.Width = 225
$splashLogo.Height = 70
$splashLogo.Stretch = [System.Windows.Media.Stretch]::Uniform

$logoHost.Children.Add($splashLogo) | Out-Null

$splashProgress = $splashWindow.FindName("SplashProgress")

$sync.UIRunspace = [runspacefactory]::CreateRunspace($Host, (New-WinUtilSessionState))
$sync.UIRunspace.ApartmentState = "STA"
$sync.UIRunspace.ThreadOptions = "ReuseThread"
$sync.UIRunspace.Open()

$uiShell = [powershell]::Create()
$uiShell.Runspace = $sync.UIRunspace
[void]$uiShell.AddScript({ Start-WinUtilUserInterface })

Write-WinUtilLog -Component "UI" -Message "Starting the interface thread."
$uiHandle = $uiShell.BeginInvoke()

# Preserve overlay rendering on this thread, as in the working application.
Start-WinUtilAssetRendering | Out-Null

# Display a smooth *visual* loading animation. UI readiness remains the actual
# gate for closing the splash; the bar does not measure units of startup work.
$splashMinimumMs = 1500
$splashAnimationMs = 1250
$splashCompleteHoldMs = 250
$splashStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$splashWindow.Tag = [long]-1 # Time when the bar first reached 100%

$splashTimer = New-Object System.Windows.Threading.DispatcherTimer
$splashTimer.Interval = [TimeSpan]::FromMilliseconds(30)
$splashTimer.Add_Tick({
    $elapsedMs = $splashStopwatch.ElapsedMilliseconds

    if ($uiHandle.IsCompleted -and -not $sync.WinForgeUIReady) {
        # Do not leave a failed startup trapped behind the splash.
        $sync.WinForgeUIStartupFailed = $true
        $splashTimer.Stop()
        $splashWindow.Close()
        return
    }

    # Animate the bar towards 95%; reserve completion for actual UI readiness.
    $fraction = [Math]::Min(1.0, $elapsedMs / [double]$splashAnimationMs)
    $visualValue = [Math]::Floor(95 * $fraction)
    if ($sync.WinForgeUIBuilt -and $visualValue -lt 75) {
        $visualValue = 75
    }

    if ($sync.WinForgeUIReady -and $elapsedMs -ge $splashAnimationMs) {
        $splashProgress.Value = 100
        if ([long]$splashWindow.Tag -lt 0) {
            $splashWindow.Tag = [long]$elapsedMs
        }
        if ($elapsedMs -ge $splashMinimumMs -and
            ($elapsedMs - [long]$splashWindow.Tag) -ge $splashCompleteHoldMs) {
            $splashTimer.Stop()
            $splashWindow.Close()
        }
    }
    else {
        $splashProgress.Value = $visualValue
    }
})
$splashProgress.Value = 0
$splashTimer.Start()
try {
    [void]$splashWindow.ShowDialog()
}
finally {
    $splashTimer.Stop()
}

# This is the original lifecycle wait: it runs after the splash closes and
# lasts until the user closes the main WinForge window.
$uiHandle.AsyncWaitHandle.WaitOne() | Out-Null

$uiFailed = [bool]$sync.WinForgeUIStartupFailed
if ($uiFailed) {
    Write-WinUtilLog -Level "ERROR" -Component "UI" -Message "Interface thread ended before WinForge signalled readiness."
}
try {
    $uiShell.EndInvoke($uiHandle) | Out-Null
} catch {
    $uiFailed = $true
    Write-WinUtilErrorRecord -ErrorRecord $_ -Component "UI" -Context "Interface thread stopped"
}

foreach ($uiWarning in $uiShell.Streams.Warning) {
    Write-WinUtilLog -Level "WARN" -Component "UI" -Message $uiWarning.Message
}

foreach ($uiError in $uiShell.Streams.Error) {
    Write-WinUtilErrorRecord -ErrorRecord $uiError -Component "UI" -Context "Interface thread"
}

$uiShell.Dispose()
$sync.UIRunspace.Dispose()
$sync.Remove("UIRunspace")

# The window may have been closed over a job that the user chose to let finish. It is still on
# the worker pool, so the pool cannot be closed until it is done.
Wait-WinUtilRemainingWork

Close-WinUtilRunspacePool
[System.GC]::Collect()

Remove-WinUtilTempScript
Write-Host "Bye bye!" -ForegroundColor Cyan
Stop-Transcript

if ($uiFailed) {
    $global:LASTEXITCODE = 1
    if ($script:WinUtilIsFileProcess) { exit 1 }
    return 1
}
