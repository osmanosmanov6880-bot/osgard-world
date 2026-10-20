import * as THREE from 'three'

export type EarthQuality = 'auto' | 'eco' | 'ultra'
export type EarthDetail = '1k' | '2k' | '4k'

export function chooseEarthDetail(quality: EarthQuality, mobile: boolean): EarthDetail {
  if (quality === 'eco') return '1k'
  if (quality === 'ultra') return mobile ? '2k' : '4k'
  return mobile ? '1k' : '2k'
}

function loadTexture(url: string, signal: AbortSignal): Promise<THREE.Texture> {
  return new Promise((resolve, reject) => {
    const image = new Image()
    image.decoding = 'async'
    let done = false
    const clean = () => signal.removeEventListener('abort', onAbort)
    const onAbort = () => fail(new Error('Texture request aborted'))
    const fail = (error: Error) => {
      if (done) return
      done = true
      clean()
      image.onload = image.onerror = null
      image.removeAttribute('src')
      reject(error)
    }
    image.onload = () => {
      if (done) return
      done = true
      clean()
      const texture = new THREE.Texture(image)
      texture.needsUpdate = true
      texture.colorSpace = THREE.SRGBColorSpace
      texture.wrapS = THREE.RepeatWrapping
      texture.anisotropy = 2
      resolve(texture)
    }
    image.onerror = () => fail(new Error('NASA texture unavailable: ' + url))
    if (signal.aborted) { onAbort(); return }
    signal.addEventListener('abort', onAbort, { once: true })
    image.src = url
  })
}

export async function loadNasaTextures(detail: EarthDetail, signal: AbortSignal): Promise<{
  day: THREE.Texture
  night: THREE.Texture
}> {
  const maps = await Promise.allSettled([
    loadTexture('/brand/omega-nasa-day-' + detail + '.webp', signal),
    loadTexture('/brand/omega-nasa-night-' + detail + '.webp', signal),
  ])
  if (maps.some(result => result.status !== 'fulfilled')) {
    for (const result of maps) if (result.status === 'fulfilled') result.value.dispose()
    throw new Error('NASA texture set incomplete; keep geospatial fallback')
  }
  return {
    day: (maps[0] as PromiseFulfilledResult<THREE.Texture>).value,
    night: (maps[1] as PromiseFulfilledResult<THREE.Texture>).value,
  }
}

/** Physically inspired daylight terminator and NASA nighttime luminosity.
 * The textures are historical composites, not live observations.
 */
export function makeNasaEarthMaterial(day: THREE.Texture, night: THREE.Texture, sun: THREE.Vector3): THREE.ShaderMaterial {
  return new THREE.ShaderMaterial({
    uniforms: {
      uDay: { value: day },
      uNight: { value: night },
      uSun: { value: sun },
      uNightIntensity: { value: 2.15 },
    },
    vertexShader: "\nvarying vec2 vEarthUv;\nvarying vec3 vEarthNormal;\nvarying vec3 vEarthPosition;\nvoid main() {\n  vEarthUv = uv;\n  vec4 worldPosition = modelMatrix * vec4(position, 1.0);\n  vEarthPosition = worldPosition.xyz;\n  vEarthNormal = normalize(mat3(modelMatrix) * normal);\n  gl_Position = projectionMatrix * viewMatrix * worldPosition;\n}",
    fragmentShader: "\nuniform sampler2D uDay;\nuniform sampler2D uNight;\nuniform vec3 uSun;\nuniform float uNightIntensity;\nvarying vec2 vEarthUv;\nvarying vec3 vEarthNormal;\nvarying vec3 vEarthPosition;\nvoid main() {\n  vec3 normalDir = normalize(vEarthNormal);\n  vec3 sunDir = normalize(uSun);\n  vec3 eyeDir = normalize(cameraPosition - vEarthPosition);\n  float ndl = dot(normalDir, sunDir);\n  float daylight = smoothstep(-0.17, 0.21, ndl);\n  float diffuse = max(ndl, 0.0);\n  vec3 albedo = texture2D(uDay, vEarthUv).rgb;\n  vec3 night = texture2D(uNight, vEarthUv).rgb;\n  vec3 daylightColor = albedo * (0.085 + 1.28 * diffuse);\n  float lightLum = dot(night, vec3(0.28, 0.59, 0.13));\n  float luminance = max(0.0, lightLum - 0.07);\n  vec3 nightLights = night * pow(luminance, 0.62) * uNightIntensity;\n  float ocean = smoothstep(0.015, 0.24, albedo.b - albedo.r);\n  vec3 reflected = reflect(-sunDir, normalDir);\n  float specular = pow(max(dot(reflected, eyeDir), 0.0), 70.0);\n  vec3 oceanGlint = vec3(0.30, 0.89, 1.0) * specular * ocean * 1.45 * daylight;\n  float horizon = pow(1.0 - max(dot(normalDir, eyeDir), 0.0), 4.0);\n  vec3 atmosphereTint = vec3(0.055, 0.35, 0.68) * horizon * 0.19;\n  vec3 twilight = vec3(0.31, 0.095, 0.045) * (1.0 - abs(ndl) / 0.20) *\n      step(abs(ndl), 0.20) * 0.24;\n  vec3 darkBlue = vec3(0.003, 0.012, 0.027);\n  vec3 finalColor = mix(nightLights + darkBlue, daylightColor, daylight)\n      + oceanGlint + atmosphereTint + twilight;\n  gl_FragColor = vec4(max(finalColor, vec3(0.0)), 1.0);\n  #include <tonemapping_fragment>\n  #include <colorspace_fragment>\n}",
    toneMapped: true,
  })
}

/** Atmospheric limb-scattering approximation, not a scientific atmosphere model. */
export function makeScatteringAtmosphere(sun: THREE.Vector3, detail: EarthDetail): THREE.Mesh {
  const material = new THREE.ShaderMaterial({
    uniforms: {
      uSun: { value: sun },
      uDensity: { value: detail === '4k' ? 1.0 : 0.84 },
    },
    vertexShader: "\nvarying vec3 vNormalWorld;\nvarying vec3 vWorldPos;\nvoid main() {\n  vec4 p = modelMatrix * vec4(position, 1.0);\n  vWorldPos = p.xyz;\n  vNormalWorld = normalize(mat3(modelMatrix) * normal);\n  gl_Position = projectionMatrix * viewMatrix * p;\n}",
    fragmentShader: "\nuniform vec3 uSun;\nuniform float uDensity;\nvarying vec3 vNormalWorld;\nvarying vec3 vWorldPos;\nvoid main() {\n  vec3 n = normalize(vNormalWorld);\n  vec3 v = normalize(cameraPosition - vWorldPos);\n  float limb = pow(1.0 - max(dot(n, v), 0.0), 3.3);\n  float solar = dot(n, normalize(uSun));\n  float daylight = smoothstep(-0.25, 0.40, solar);\n  float dawn = exp(-pow(solar * 7.0, 2.0)) * 0.85;\n  vec3 rayleigh = mix(vec3(0.01, 0.15, 0.34), vec3(0.10, 0.60, 1.00), daylight);\n  vec3 mie = vec3(1.0, 0.39, 0.10) * dawn;\n  vec3 color = rayleigh + mie;\n  float alpha = clamp(limb * (0.31 + 0.50 * daylight) * uDensity, 0.0, 0.79);\n  gl_FragColor = vec4(color, alpha);\n}",
    transparent: true,
    blending: THREE.AdditiveBlending,
    depthWrite: false,
    side: THREE.BackSide,
  })
  return new THREE.Mesh(
    new THREE.SphereGeometry(1.72, detail === '4k' ? 96 : 56, detail === '4k' ? 64 : 38),
    material,
  )
}
