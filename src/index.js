// BERRY IT WinForge launcher. Serve the current compiled PowerShell bundle.
// Worker route: winforge.berry.it.com/win
const SCRIPT_URL = "https://raw.githubusercontent.com/BERRY-2508/WinForge/main/winutil.ps1";

export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname !== "/win") return new Response("Not found", { status: 404 });
    if (request.method !== "GET") return new Response("Method not allowed", {
      status: 405, headers: { "Allow": "GET" }
    });

    try {
      // Bypass any stale Cloudflare cache of raw.githubusercontent.com.
      const upstreamURL = new URL(SCRIPT_URL);
      upstreamURL.searchParams.set("_winforge_refresh", String(Date.now()));
      const upstream = await fetch(upstreamURL.toString(), {
        headers: { "Accept": "text/plain", "Cache-Control": "no-cache" },
        cf: { cacheTtl: 0, cacheEverything: false }
      });
      if (!upstream.ok) return new Response("WinForge script unavailable", { status: 502 });

      const script = await upstream.text();
      if (!script.trim() ||
          /<!doctype html|<html/i.test(script.slice(0, 500)) ||
          !script.includes("Start-WinUtilUserInterface")) {
        return new Response("WinForge script validation failed", { status: 502 });
      }
      return new Response(script, {
        headers: {
          "Content-Type": "text/plain; charset=utf-8",
          "Cache-Control": "private, no-store, no-cache, max-age=0, must-revalidate",
          "CDN-Cache-Control": "no-store",
          "Cloudflare-CDN-Cache-Control": "no-store",
          "Pragma": "no-cache",
          "X-Content-Type-Options": "nosniff",
          "X-WinForge-Worker": "live-github-no-cache"
        }
      });
    } catch {
      return new Response("WinForge script temporarily unavailable", { status: 502 });
    }
  }
};
