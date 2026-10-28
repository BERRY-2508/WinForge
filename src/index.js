// WinForge launcher. Attach to the Cloudflare Worker route winforge.berry.it.com/win.
// The existing GitHub Pages homepage remains responsible for other paths.
const SCRIPT_URL = "https://raw.githubusercontent.com/BERRY-2508/WinForge/main/winutil.ps1";
export default {
  async fetch(request) {
    const { pathname } = new URL(request.url);
    if (pathname !== "/win") return new Response("Not found", { status: 404 });
    if (request.method !== "GET") return new Response("Method not allowed", { status: 405, headers: { Allow: "GET" } });

    try {
      const upstream = await fetch(SCRIPT_URL, { headers: { Accept: "text/plain" }, cf: { cacheTtl: 0 } });
      if (!upstream.ok) return new Response("WinForge script is not published yet.", { status: 502 });
      const script = await upstream.text();
      // Fail closed: never serve HTML, error messages or empty content to a PowerShell execution command.
      if (!script.trim() || /<!doctype html|<html/i.test(script.slice(0, 500))) {
        return new Response("WinForge script is unavailable.", { status: 502 });
      }
      return new Response(script, {
        headers: {
          "Content-Type": "text/plain; charset=utf-8",
          "Cache-Control": "no-store",
          "X-Content-Type-Options": "nosniff"
        }
      });
    } catch {
      return new Response("WinForge script is temporarily unavailable.", { status: 502 });
    }
  }
};
