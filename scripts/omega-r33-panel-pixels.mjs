// R87.1: pixel-normalized original Godot government dock evidence.
// Real Chromium compositor PNGs are 960x540 when CDP downscales and 1366x768
// when the fallback captures full viewport. Every sample is at the same
// FRACTIONAL location, so image size cannot create fake 'new golden text'.
export const PANEL_COLUMNS = 110
export const PANEL_ROWS = 100

export function samplePanelPixels(png, xa, xb, ya, yb) {
  const width = png?.width, height = png?.height, data = png?.data
  if (!Number.isInteger(width) || !Number.isInteger(height) ||
      width < 160 || height < 160 ||
      !data || data.length < width * height * 4)
    throw new Error('Original RGBA PNG pixels missing or invalid')
  if (![xa, xb, ya, yb].every(Number.isFinite) ||
      xa < 0 || xb > 1 || ya < 0 || yb > 1 || xa >= xb || ya >= yb)
    throw new Error('Unsafe normalized government-panel sampling region')
  let gold = 0, dark = 0
  for (let yi = 0; yi < PANEL_ROWS; yi++) {
    const y = Math.min(height - 1,
      Math.floor(height * (ya + (yb - ya) * (yi + 0.5) / PANEL_ROWS)))
    for (let xi = 0; xi < PANEL_COLUMNS; xi++) {
      const x = Math.min(width - 1,
        Math.floor(width * (xa + (xb - xa) * (xi + 0.5) / PANEL_COLUMNS)))
      const at = (y * width + x) * 4
      const r = data[at], g = data[at + 1], b = data[at + 2]
      const luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
      if (r > 140 && g > 100 && r > g * 1.05 && g > b * 1.25) gold++
      if (luma < 35) dark++
    }
  }
  const total = PANEL_ROWS * PANEL_COLUMNS
  return {goldPixels: gold, darkRatio: dark / total, sampledPixels: total}
}
