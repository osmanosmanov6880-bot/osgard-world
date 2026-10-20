import { useEffect, useRef, useState } from 'react'
import * as THREE from 'three'

/**
 * OSGARD WORLD decorative 3D Earth.
 * Land geometry: Natural Earth 1:110m, public domain, simplified offline.
 * No external CDN, user-tracking, geolocation, audio or untrusted shaders.
 * The existing CSS sphere remains the accessible, low-power fallback.
 */
type Ring = number[][]
type LandPolygons = {
  type: 'land-polygons'
  polygons: Ring[][]
}
type GlobeStatus = 'loading' | 'webgl' | 'fallback'

function createLandTexture(data: LandPolygons, width: number): THREE.CanvasTexture {
  const height = width / 2
  const canvas = document.createElement('canvas')
  canvas.width = width
  canvas.height = height
  const ctx = canvas.getContext('2d')
  if (!ctx) throw new Error('Canvas texture is unavailable')

  const sea = ctx.createLinearGradient(0, 0, width, height)
  sea.addColorStop(0, '#062a49')
  sea.addColorStop(0.52, '#041a34')
  sea.addColorStop(1, '#06172e')
  ctx.fillStyle = sea
  ctx.fillRect(0, 0, width, height)

  ctx.lineWidth = 0.65
  ctx.strokeStyle = 'rgba(72, 183, 230, .18)'
  for (let longitude = -150; longitude <= 150; longitude += 30) {
    const x = (longitude + 180) / 360 * width
    ctx.beginPath()
    ctx.moveTo(x, 0)
    ctx.lineTo(x, height)
    ctx.stroke()
  }
  for (let latitude = -60; latitude <= 60; latitude += 15) {
    const y = (90 - latitude) / 180 * height
    ctx.beginPath()
    ctx.moveTo(0, y)
    ctx.lineTo(width, y)
    ctx.stroke()
  }

  const coord = (point: number[]) => [
    (point[0] + 180) / 360 * width,
    (90 - point[1]) / 180 * height,
  ] as const

  for (const polygon of data.polygons) {
    const path = new Path2D()
    for (const ring of polygon) {
      for (let i = 0; i < ring.length; i++) {
        const [x, y] = coord(ring[i])
        if (i === 0) path.moveTo(x, y)
        else path.lineTo(x, y)
      }
      path.closePath()
    }
    ctx.fillStyle = '#146478'
    ctx.fill(path, 'evenodd')
    ctx.strokeStyle = 'rgba(64, 238, 241, .44)'
    ctx.lineWidth = width / 620
    ctx.shadowColor = 'rgba(29, 219, 242, .72)'
    ctx.shadowBlur = width / 210
    ctx.stroke(path)
    ctx.shadowBlur = 0
    ctx.lineWidth = width / 1350
    ctx.strokeStyle = 'rgba(164, 255, 254, .8)'
    ctx.stroke(path)

    // Deterministic city-like points clipped to actual land, not invented coastlines.
    const outer = polygon[0]
    if (!outer || outer.length < 4) continue
    const xs = outer.map(p => coord(p)[0])
    const ys = outer.map(p => coord(p)[1])
    const left = Math.min(...xs), right = Math.max(...xs)
    const top = Math.min(...ys), bottom = Math.max(...ys)
    let seed = Math.round(left * 37 + top * 67 + outer.length * 117) >>> 0
    for (let i = 0; i < 15; i++) {
      seed = (1664525 * seed + 1013904223) >>> 0
      const x = left + (seed / 4294967296) * (right - left)
      seed = (1664525 * seed + 1013904223) >>> 0
      const y = top + (seed / 4294967296) * (bottom - top)
      if (!ctx.isPointInPath(path, x, y, 'evenodd')) continue
      ctx.fillStyle = i % 5 === 0 ? '#c8fffa' : 'rgba(94, 232, 237, .66)'
      ctx.fillRect(x, y, width > 1500 ? 2 : 1, width > 1500 ? 2 : 1)
    }
  }

  const texture = new THREE.CanvasTexture(canvas)
  texture.colorSpace = THREE.SRGBColorSpace
  texture.wrapS = THREE.RepeatWrapping
  texture.anisotropy = 2
  return texture
}

function vectorOnEarth(latitude: number, longitude: number, radius: number): THREE.Vector3 {
  const phi = THREE.MathUtils.degToRad(longitude)
  const theta = THREE.MathUtils.degToRad(latitude)
  return new THREE.Vector3(
    radius * Math.cos(theta) * Math.cos(phi),
    radius * Math.sin(theta),
    -radius * Math.cos(theta) * Math.sin(phi),
  )
}

function earthGrid(): THREE.Group {
  const grid = new THREE.Group()
  const color = 0x81bcd9
  const material = new THREE.LineBasicMaterial({ color, transparent: true, opacity: 0.14, depthWrite: false })
  for (let latitude = -60; latitude <= 60; latitude += 30) {
    const points: THREE.Vector3[] = []
    for (let longitude = -180; longitude <= 180; longitude += 3) points.push(vectorOnEarth(latitude, longitude, 1.563))
    grid.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(points), material))
  }
  for (let longitude = -150; longitude <= 180; longitude += 30) {
    const points: THREE.Vector3[] = []
    for (let latitude = -90; latitude <= 90; latitude += 3) points.push(vectorOnEarth(latitude, longitude, 1.563))
    grid.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(points), material))
  }
  return grid
}

function orbit(radiusX: number, radiusY: number, color: number, opacity: number, tilt: number): THREE.LineLoop {
  const points: THREE.Vector3[] = []
  for (let i = 0; i < 240; i++) {
    const t = i / 240 * Math.PI * 2
    points.push(new THREE.Vector3(Math.cos(t) * radiusX, Math.sin(t) * radiusY, 0))
  }
  const line = new THREE.LineLoop(
    new THREE.BufferGeometry().setFromPoints(points),
    new THREE.LineBasicMaterial({ color, transparent: true, opacity, depthWrite: false }),
  )
  line.rotation.set(tilt, -0.15, tilt * 0.55)
  return line
}

function decorateScene(scene: THREE.Scene, detail: number) {
  let seed = 184731
  const next = () => {
    seed = (1664525 * seed + 1013904223) >>> 0
    return seed / 4294967296
  }
  const points = new Float32Array(detail * 3)
  for (let i = 0; i < detail; i++) {
    points[i * 3] = (next() - 0.5) * 11
    points[i * 3 + 1] = (next() - 0.5) * 8
    points[i * 3 + 2] = -2 - next() * 3
  }
  const geometry = new THREE.BufferGeometry()
  geometry.setAttribute('position', new THREE.BufferAttribute(points, 3))
  scene.add(new THREE.Points(geometry, new THREE.PointsMaterial({
    size: 0.023, color: 0x96eaff, opacity: 0.55, transparent: true, depthWrite: false,
  })))
  const hemi = new THREE.HemisphereLight(0x98f5ff, 0x051228, 2.1)
  scene.add(hemi)
  const key = new THREE.DirectionalLight(0x92f6ff, 3.6)
  key.position.set(-2.5, 3, 5)
  scene.add(key)
  const fill = new THREE.DirectionalLight(0x526dff, 1.45)
  fill.position.set(3, -1.8, -2)
  scene.add(fill)
}

function disposeScene(scene: THREE.Scene) {
  const geometries = new Set<THREE.BufferGeometry>()
  const materials = new Set<THREE.Material>()
  const textures = new Set<THREE.Texture>()
  scene.traverse(object => {
    if (object instanceof THREE.Mesh || object instanceof THREE.Line || object instanceof THREE.Points) {
      geometries.add(object.geometry)
      const attached = Array.isArray(object.material) ? object.material : [object.material]
      for (const material of attached) {
        materials.add(material)
        const mapped = material as THREE.Material & { map?: THREE.Texture }
        if (mapped.map) textures.add(mapped.map)
      }
    }
  })
  geometries.forEach(geometry => geometry.dispose())
  materials.forEach(material => material.dispose())
  textures.forEach(texture => texture.dispose())
}

export default function OmegaGlobe() {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const stageRef = useRef<HTMLDivElement>(null)
  const [status, setStatus] = useState<GlobeStatus>('loading')

  useEffect(() => {
    const canvas = canvasRef.current
    const stage = stageRef.current
    const sky = stage?.closest('.omega-sky')
    const hero = stage?.closest('.omega-hero')
    if (!canvas || !stage || !sky || !hero) return

    let alive = true, started = false, visible = true, lastFrame = 0, frameId = 0
    let renderer: THREE.WebGLRenderer | null = null
    let scene: THREE.Scene | null = null
    let camera: THREE.PerspectiveCamera | null = null
    let globe: THREE.Group | null = null
    let resizeObserver: ResizeObserver | null = null
    let targetX = 0, targetY = 0, x = 0, y = 0
    let turn = 0
    const media = window.matchMedia('(prefers-reduced-motion: reduce)')
    const controller = new AbortController()
    const mobile = window.matchMedia('(max-width: 760px)').matches
    const allowed = () => !media.matches && document.documentElement.dataset.motion !== 'off'
    const onMove = (event: PointerEvent) => {
      if (event.pointerType === 'touch') return
      const bounds = hero.getBoundingClientRect()
      targetX = THREE.MathUtils.clamp((event.clientX - bounds.left) / bounds.width * 2 - 1, -1, 1)
      targetY = THREE.MathUtils.clamp((event.clientY - bounds.top) / bounds.height * 2 - 1, -1, 1)
    }
    const onLeave = () => { targetX = 0; targetY = 0 }
    const resize = () => {
      if (!renderer || !camera) return
      const bounds = sky.getBoundingClientRect()
      const width = Math.max(1, Math.round(bounds.width))
      const height = Math.max(1, Math.round(bounds.height))
      renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, mobile ? 1.25 : 1.6))
      renderer.setSize(width, height, false)
      camera.aspect = width / height
      camera.updateProjectionMatrix()
      renderer.render(scene!, camera)
    }
    const animate = (time: number) => {
      if (!alive || !renderer || !scene || !camera || !globe) return
      frameId = requestAnimationFrame(animate)
      if (!visible || document.hidden || !allowed()) return
      const interval = mobile ? 33.4 : 16.7
      if (time - lastFrame < interval) return
      const delta = Math.min(50, Math.max(0, time - (lastFrame || time)))
      lastFrame = time
      turn += delta * 0.000055
      x += (targetX - x) * 0.025
      y += (targetY - y) * 0.025
      globe.rotation.y = turn
      globe.rotation.x = -0.14 + y * 0.075
      camera.position.x = x * 0.17
      camera.position.y = -y * 0.13
      camera.lookAt(0, 0, 0)
      renderer.render(scene, camera)
    }
    const init = async () => {
      if (started || !visible || !allowed() || !alive) return
      started = true
      try {
        // Fetch stays on the same origin; any failure leaves the existing CSS globe intact.
        const response = await fetch('/brand/omega-earth-land.json', { signal: controller.signal })
        if (!response.ok) throw new Error('Earth coastline asset unavailable')
        const data = await response.json() as LandPolygons
        if (data.type !== 'land-polygons' || !Array.isArray(data.polygons) || data.polygons.length < 50) {
          throw new Error('Invalid Earth coastline asset')
        }
        if (!alive) return
        const gl = canvas.getContext('webgl2', { alpha: true, antialias: true, powerPreference: 'low-power' })
        if (!gl) throw new Error('WebGL2 not supported')
        renderer = new THREE.WebGLRenderer({ canvas, context: gl, antialias: true, alpha: true, powerPreference: 'low-power' })
        renderer.outputColorSpace = THREE.SRGBColorSpace
        renderer.setClearColor(0x000000, 0)
        scene = new THREE.Scene()
        camera = new THREE.PerspectiveCamera(45, 1, 0.1, 80)
        camera.position.set(0, 0, 5.7)
        decorateScene(scene, mobile ? 90 : 230)

        globe = new THREE.Group()
        const geography = new THREE.Group()
        geography.rotation.y = -Math.PI / 2
        globe.add(geography)
        const landTexture = createLandTexture(data, mobile ? 1024 : 2048)
        const sphere = new THREE.Mesh(
          new THREE.SphereGeometry(1.55, mobile ? 48 : 80, mobile ? 32 : 56),
          new THREE.MeshStandardMaterial({
            map: landTexture, metalness: 0.18, roughness: 0.78,
            emissive: 0x07506a, emissiveIntensity: 0.38,
          }),
        )
        geography.add(sphere)
        geography.add(earthGrid())

        const atmosphere = new THREE.Mesh(
          new THREE.SphereGeometry(1.64, mobile ? 40 : 64, mobile ? 24 : 40),
          new THREE.ShaderMaterial({
            transparent: true,
            depthWrite: false,
            blending: THREE.AdditiveBlending,
            vertexShader: [
              'varying vec3 vNormal;',
              'varying vec3 vWorldPos;',
              'void main() {',
              '  vec4 world = modelMatrix * vec4(position, 1.0);',
              '  vWorldPos = world.xyz;',
              '  vNormal = normalize(mat3(modelMatrix) * normal);',
              '  gl_Position = projectionMatrix * viewMatrix * world;',
              '}',
            ].join('\n'),
            fragmentShader: [
              'varying vec3 vNormal;',
              'varying vec3 vWorldPos;',
              'void main() {',
              '  vec3 eye = normalize(cameraPosition - vWorldPos);',
              '  float rim = pow(1.0 - max(0.0, dot(normalize(vNormal), eye)), 3.0);',
              '  gl_FragColor = vec4(0.18, 0.79, 1.0, rim * 0.48);',
              '}',
            ].join('\n'),
          }),
        )
        globe.add(atmosphere)
        scene.add(globe)
        scene.add(orbit(2.05, 1.03, 0x77efff, 0.34, 0.35))
        scene.add(orbit(2.13, 1.12, 0xbb8dff, 0.27, -0.85))
        scene.add(orbit(2.28, 0.49, 0x3bb3f3, 0.24, 0.97))

        if (!alive) return
        resizeObserver = new ResizeObserver(resize)
        resizeObserver.observe(sky)
        resize()
        sky.classList.add('omega-webgl-ready')
        setStatus('webgl')
        frameId = requestAnimationFrame(animate)
      } catch {
        if (alive) {
          sky.classList.remove('omega-webgl-ready')
          setStatus('fallback')
        }
      }
    }
    const observer = new IntersectionObserver(entries => {
      visible = Boolean(entries[0]?.isIntersecting)
      if (visible) void init()
    }, { rootMargin: '180px' })
    observer.observe(hero)
    const mutation = new MutationObserver(() => { if (allowed()) void init() })
    mutation.observe(document.documentElement, { attributes: true, attributeFilter: ['data-motion'] })
    const onMotion = () => { if (allowed()) void init() }
    media.addEventListener('change', onMotion)
    hero.addEventListener('pointermove', onMove, { passive: true })
    hero.addEventListener('pointerleave', onLeave)
    const contextLost = (event: Event) => {
      event.preventDefault()
      sky.classList.remove('omega-webgl-ready')
      setStatus('fallback')
      visible = false
    }
    canvas.addEventListener('webglcontextlost', contextLost)
    return () => {
      alive = false
      controller.abort()
      cancelAnimationFrame(frameId)
      observer.disconnect()
      mutation.disconnect()
      resizeObserver?.disconnect()
      media.removeEventListener('change', onMotion)
      hero.removeEventListener('pointermove', onMove)
      hero.removeEventListener('pointerleave', onLeave)
      canvas.removeEventListener('webglcontextlost', contextLost)
      sky.classList.remove('omega-webgl-ready')
      if (scene) disposeScene(scene)
      renderer?.dispose()
    }
  }, [])

  return <div className="omega-webgl-stage" data-globe-status={status} ref={stageRef}>
    <canvas ref={canvasRef} className="omega-webgl-canvas" aria-hidden="true" />
  </div>
}
