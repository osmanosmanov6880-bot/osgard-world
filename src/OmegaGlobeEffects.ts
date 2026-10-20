import * as THREE from 'three'

/**
 * GPU-conscious procedural materials for the OSGARD Earth.
 * Cloud distribution and points of light are artistic visualizations,
 * not meteorological imagery or verified settlement coordinates.
 * Everything is generated in the visitor's browser; no third-party fetches.
 */
type Ring = number[][]
type LandPolygons = { type: 'land-polygons'; polygons: Ring[][] }

const smooth = (t: number) => t * t * (3 - 2 * t)
const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value))
const hash = (x: number, y: number) => {
  let n = (Math.imul(x + 1, 374761393) ^ Math.imul(y + 1, 668265263)) >>> 0
  n = Math.imul(n ^ (n >>> 13), 1274126177) >>> 0
  return ((n ^ (n >>> 16)) >>> 0) / 4294967295
}

function periodicNoise(u: number, v: number, cellsX: number, cellsY: number): number {
  const fx = u * cellsX
  const fy = v * cellsY
  const x = Math.floor(fx)
  const y = Math.floor(fy)
  const dx = smooth(fx - x)
  const dy = smooth(fy - y)
  const wrap = (n: number, count: number) => (n % count + count) % count
  const a = hash(wrap(x, cellsX), wrap(y, cellsY))
  const b = hash(wrap(x + 1, cellsX), wrap(y, cellsY))
  const c = hash(wrap(x, cellsX), wrap(y + 1, cellsY))
  const d = hash(wrap(x + 1, cellsX), wrap(y + 1, cellsY))
  return (a * (1 - dx) + b * dx) * (1 - dy) +
    (c * (1 - dx) + d * dx) * dy
}

export function createCloudTexture(mobile: boolean): THREE.CanvasTexture {
  const width = mobile ? 384 : 768
  const height = width / 2
  const canvas = document.createElement('canvas')
  canvas.width = width
  canvas.height = height
  const ctx = canvas.getContext('2d')
  if (!ctx) throw new Error('Unable to create procedural cloud texture')
  const pixels = ctx.createImageData(width, height)
  for (let y = 0; y < height; y++) {
    const v = y / height
    // Distortion curves move cloud belts naturally, while preserving the UV seam.
    const lat = (v - 0.5) * Math.PI
    const bands = 0.035 * Math.sin(lat * 9) + 0.025 * Math.sin(lat * 21)
    for (let x = 0; x < width; x++) {
      const u = x / width
      const distortion = periodicNoise(u, v, 7, 5) * 0.042
      const n1 = periodicNoise(u + distortion, v, 9, 5)
      const n2 = periodicNoise(u - distortion, v, 23, 11)
      const n3 = periodicNoise(u, v, 51, 25)
      const fbm = n1 * 0.52 + n2 * 0.33 + n3 * 0.15 + bands
      const coverage = clamp((fbm - 0.47) * 4.2, 0, 1)
      const softness = smooth(coverage)
      const i = (y * width + x) * 4
      pixels.data[i] = Math.round(204 + 42 * n1)
      pixels.data[i + 1] = Math.round(227 + 25 * n2)
      pixels.data[i + 2] = 255
      pixels.data[i + 3] = Math.round(softness * 204)
    }
  }
  ctx.putImageData(pixels, 0, 0)
  const texture = new THREE.CanvasTexture(canvas)
  texture.colorSpace = THREE.SRGBColorSpace
  texture.wrapS = THREE.RepeatWrapping
  texture.anisotropy = 2
  return texture
}

export function createCloudLayers(mobile: boolean): {
  group: THREE.Group
  inner: THREE.Mesh
  outer: THREE.Mesh
} {
  const texture = createCloudTexture(mobile)
  const group = new THREE.Group()
  const inner = new THREE.Mesh(
    new THREE.SphereGeometry(1.602, mobile ? 40 : 72, mobile ? 28 : 48),
    new THREE.MeshStandardMaterial({
      map: texture,
      color: 0xc0f2ff,
      emissive: 0x23556b,
      emissiveIntensity: 0.12,
      metalness: 0,
      roughness: 0.94,
      transparent: true,
      opacity: 0.53,
      depthWrite: false,
      side: THREE.FrontSide,
    }),
  )
  const outer = new THREE.Mesh(
    new THREE.SphereGeometry(1.618, mobile ? 32 : 58, mobile ? 24 : 38),
    new THREE.MeshBasicMaterial({
      map: texture,
      color: 0xbceaff,
      transparent: true,
      opacity: mobile ? 0.13 : 0.21,
      depthWrite: false,
      side: THREE.FrontSide,
    }),
  )
  inner.rotation.y = 0.18
  outer.rotation.y = -0.31
  outer.rotation.z = 0.07
  group.add(inner, outer)
  return { group, inner, outer }
}

export function createCityLightsTexture(data: LandPolygons, mobile: boolean): THREE.CanvasTexture {
  const width = mobile ? 512 : 1024
  const height = width / 2
  const canvas = document.createElement('canvas')
  canvas.width = width
  canvas.height = height
  const ctx = canvas.getContext('2d')
  if (!ctx) throw new Error('Unable to create night lights texture')
  ctx.fillStyle = '#000000'
  ctx.fillRect(0, 0, width, height)
  const toXY = (coord: number[]) =>
    [(coord[0] + 180) / 360 * width, (90 - coord[1]) / 180 * height] as const

  let seed = 58130071
  const random = () => {
    seed = (Math.imul(1664525, seed) + 1013904223) >>> 0
    return seed / 4294967296
  }

  for (const polygon of data.polygons) {
    for (const outer of polygon.slice(0, 1)) {
      if (outer.length < 4) continue
      const path = new Path2D()
      const coordinates = outer.map(toXY)
      coordinates.forEach(([x, y], i) => i ? path.lineTo(x, y) : path.moveTo(x, y))
      path.closePath()
      const xs = coordinates.map(([x]) => x)
      const ys = coordinates.map(([, y]) => y)
      const left = Math.min(...xs), right = Math.max(...xs)
      const top = Math.min(...ys), bottom = Math.max(...ys)
      const area = Math.max(0, right - left) * Math.max(0, bottom - top)
      const count = clamp(Math.round(area / 420), 1, mobile ? 25 : 55)
      for (let i = 0; i < count * 3; i++) {
        const x = left + random() * (right - left)
        const y = top + random() * (bottom - top)
        if (!ctx.isPointInPath(path, x, y)) continue
        const radius = 1.1 + random() * (mobile ? 0.9 : 2.4)
        const glow = ctx.createRadialGradient(x, y, 0, x, y, radius * 3.5)
        glow.addColorStop(0, 'rgba(185,252,255,.96)')
        glow.addColorStop(0.25, 'rgba(56,222,252,.73)')
        glow.addColorStop(1, 'rgba(0,36,70,0)')
        ctx.fillStyle = glow
        ctx.beginPath()
        ctx.arc(x, y, radius * 3.5, 0, Math.PI * 2)
        ctx.fill()
        if (i > count && random() > 0.25) break
      }
    }
  }
  const texture = new THREE.CanvasTexture(canvas)
  texture.colorSpace = THREE.SRGBColorSpace
  texture.wrapS = THREE.RepeatWrapping
  return texture
}
