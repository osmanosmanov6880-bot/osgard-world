// Read-only public contract for a genuine, bootable Godot Web shell.
// R23 exposes accessibility attributes on <canvas>; comparing the whole opening
// tag as a literal falsely rejects a valid native Web export.
export function isNativeNebulaShell(html) {
  if (typeof html !== 'string' || html.length < 1000) return false
  const actualCanvas = /<canvas\b(?=[^>]*\bid=["']canvas["'])(?![^>]*\bhidden\b)[^>]*>/i.test(html)
  return html.includes('<title>REMIX ARENA - NEBULA 3D</title>') &&
    actualCanvas &&
    /<script\s+src=["']index\.js["']\s*><\/script>/i.test(html) &&
    html.includes('new Engine(GODOT_CONFIG)') &&
    /["']index\.wasm["']/.test(html) &&
    /["']index\.pck["']/.test(html) &&
    html.includes("document.documentElement.lang = 'ru'") &&
    html.includes('Для запуска игры требуется WebGL 2.') &&
    html.includes("backLink.href = '/games/#catalog'")
}
