# Berry IT WinForge Utility

**Windows optimisation, configuration and maintenance — by Berry IT.**

WinForge Utility is a Windows maintenance and configuration tool

WinForge brings common Windows administration tasks together in one graphical interface, with Berry IT branding and a streamlined startup experience.

**Website:** [berry.it.com](https://berry.it.com)  
**GitHub:** [BERRY-2508/WinForge](https://github.com/BERRY-2508/WinForge)  
**WinForge website:** [winforge.berry.it.com](https://winforge.berry.it.com) *(coming soon)*

---

## Features

WinForge Utility provides several categories of Windows administration tools:

- **Install:** Install and manage commonly used Windows applications.
- **Tweaks:** Adjust Windows settings, privacy preferences and performance options.
- **Config:** Access Windows configuration, repair and maintenance utilities.
- **Updates:** Manage Windows Update settings.
- **AppX:** Manage supported Windows app packages.
- **Presets:** Apply predefined selections for common configuration scenarios.

WinForge also features a custom Berry IT interface, branding and animated startup splash screen.

Some available operations make system-wide changes. Review each option carefully and back up important data before applying modifications.

---

## Getting Started

### Requirements

- A supported Windows installation
- Windows PowerShell or PowerShell 7
- Administrator privileges
- An internet connection for operations that download applications or other resources

### Run WinForge locally

1. Download the WinForge PowerShell script from the project repository or a future official release.
2. Save it as `winutil.ps1`.
3. Open PowerShell or Windows Terminal as Administrator.
4. Navigate to the folder containing the script.
5. Run:

```powershell
.\winutil.ps1
```

The Berry IT startup splash screen will appear before the main WinForge interface opens.

**Online launch command:** Coming soon. The official endpoint will be announced once hosting is configured and verified.

### Automation and presets

WinForge supports configuration presets through its command-line interface.

For example:

```powershell
.\winutil.ps1 -Preset Standard
```

Available preset names include `Standard`, `Minimal` and `Advanced`. Review each preset's configuration before using it.

To apply an exported configuration file:

```powershell
.\winutil.ps1 -Config "C:\Path\To\Config.json"
```

These operations can change system settings without requiring interaction with the main interface.

---

## Development

WinForge Utility is currently under active development.

The application is built from PowerShell source files, configuration files and WPF/XAML interface definitions.

To compile from source:

```powershell
.\Compile.ps1
```

This generates the standalone `winutil.ps1` script.

The project will continue to receive branding updates, interface improvements, bug fixes and compatibility testing before its first public release.

---

## Documentation and support

- [Berry IT website](https://berry.it.com)
- [WinForge GitHub repository](https://github.com/BERRY-2508/WinForge)
- [Report a WinForge issue](https://github.com/BERRY-2508/WinForge/issues)
- [Original WinUtil documentation](https://winutil.christitus.com/)

Some features retain links to the original WinUtil documentation while WinForge-specific documentation is being developed.

---

## Credits and acknowledgements

Berry IT WinForge Utility is based on the open-source **Chris Titus Tech Windows Utility (WinUtil)**.

Credit and appreciation go to:

- **Chris Titus Tech / CT Tech Group LLC** — original WinUtil project and development.
- **@DeveloperDurp** — original runspace contributions.
- **The WinUtil contributors** — development and ongoing improvements to the upstream project.
- **Berry IT** — WinForge branding, customisation and project development.

WinForge is an independently maintained derivative project and is not presented as an official Chris Titus Tech release.

Third-party components and features retain their respective ownership and attribution.

---

## Licence

WinForge Utility is distributed under the **MIT Licence**, in accordance with the original WinUtil project's licence.

The original copyright and licence notice are retained in the repository's [LICENSE](LICENSE) file and incorporated into compiled distributions.

---

**Developed by Berry IT**  
[berry.it.com](https://berry.it.com)
