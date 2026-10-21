import * as THREE from 'three'

export type EarthTextureTier = 512 | 1024 | 2048 | 4096
export type SatelliteEarthTextures = {
  surface: THREE.Texture
  night: THREE.Texture
  roughness: THREE.Texture
  tier: EarthTextureTier
}
export type EarthSurfaceUniforms = {
  sunDirection: { value: THREE.Vector3 }
  cloudMap: { value: THREE.Texture }
  cloudOffset: { value: number }
}

/**
 * NASA Blue Marble July 2004 / Black Marble 2016.
 * These files are bundled and delivered from OSGARD's own origin.
 * A failed image decode must NEVER make the page unusable.
 */
export async function loadSatelliteTextures(tier: EarthTextureTier): Promise<SatelliteEarthTextures> {
  const loader = new THREE.TextureLoader()
  const allocated: THREE.Texture[] = []
  const load = async (file: string, width: number, srgb: boolean): Promise<THREE.Texture> => {
    const texture = await loader.loadAsync('/brand/earth/' + file)
    allocated.push(texture)
    const image = texture.image as HTMLImageElement | undefined
    const actualWidth = image?.naturalWidth ?? image?.width ?? 0
    const actualHeight = image?.naturalHeight ?? image?.height ?? 0
    if (actualWidth !== width || actualHeight !== width / 2) {
      throw new Error('Invalid NASA Earth image resolution: ' + file)
    }
    texture.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace
    texture.wrapS = THREE.RepeatWrapping
    texture.wrapT = THREE.ClampToEdgeWrapping
    texture.anisotropy = tier === 4096 ? 8 : 4
    texture.generateMipmaps = true
    return texture
  }
  try {
    const surface = await load('blue-marble-' + tier + '.webp', tier, true)
    const night = await load('black-marble-lights-2048.webp', 2048, true)
    const roughness = await load('earth-roughness-2048.webp', 2048, false)
    return { surface, night, roughness, tier }
  } catch (error) {
    for (const texture of allocated) texture.dispose()
    throw error
  }
}

export function disposeSatelliteTextures(textures: SatelliteEarthTextures) {
  textures.surface.dispose()
  textures.night.dispose()
  textures.roughness.dispose()
}

/**
 * Match nighttime emissions to Earth's sun-facing hemisphere and cast subtle
 * moving cloud shadows. Based on standard Three.js PBR shading, so land,
 * oceans and material reflections retain physically based response.
 */
export function enhanceEarthSurface(
  material: THREE.MeshStandardMaterial,
  sunDirection: THREE.Vector3,
  cloudMap: THREE.Texture,
): EarthSurfaceUniforms {
  const uniforms: EarthSurfaceUniforms = {
    sunDirection: { value: sunDirection },
    cloudMap: { value: cloudMap },
    cloudOffset: { value: 0 },
  }
  material.onBeforeCompile = shader => {
    shader.uniforms.uOmegaSun = uniforms.sunDirection
    shader.uniforms.uOmegaCloud = uniforms.cloudMap
    shader.uniforms.uOmegaCloudOffset = uniforms.cloudOffset
    shader.vertexShader = shader.vertexShader
      .replace('#include <common>', '#include <common>\nvarying vec3 vOmegaWorldNormal;\nvarying vec2 vOmegaUV;')
      .replace('#include <begin_vertex>', '#include <begin_vertex>\nvOmegaWorldNormal = normalize(mat3(modelMatrix) * normal);\nvOmegaUV = uv;')
    shader.fragmentShader = shader.fragmentShader
      .replace('#include <common>', [
        '#include <common>',
        'varying vec3 vOmegaWorldNormal;',
        'varying vec2 vOmegaUV;',
        'uniform vec3 uOmegaSun;',
        'uniform sampler2D uOmegaCloud;',
        'uniform float uOmegaCloudOffset;',
        'float omegaSunlight() {',
        ' return smoothstep(-0.18, 0.24, dot(normalize(vOmegaWorldNormal), normalize(uOmegaSun)));',
        '}',
      ].join('\n'))
      .replace('#include <map_fragment>', [
        '#include <map_fragment>',
        'float omegaCloudCoverage = texture2D(uOmegaCloud, vec2(fract(vOmegaUV.x + uOmegaCloudOffset), vOmegaUV.y)).a;',
        'diffuseColor.rgb *= 1.0 - 0.28 * omegaCloudCoverage * omegaSunlight();',
      ].join('\n'))
      .replace('#include <emissivemap_fragment>', [
        '#include <emissivemap_fragment>',
        // Cities are visible in darkness, not as glowing dots on the illuminated day side.
        'totalEmissiveRadiance *= 1.0 - omegaSunlight();',
      ].join('\n'))
  }
  material.customProgramCacheKey = () => 'osgard-satellite-earth-pbr-2'
  return uniforms
}

/** Sun-aware scattering: Rayleigh-like blue limb, faint warm terminator and
 * camera Fresnel. A lightweight approximation, not full volumetric ray marching. */
export function createSunlitAtmosphere(
  sunDirection: THREE.Vector3,
  eco: boolean,
): THREE.Mesh<THREE.SphereGeometry, THREE.ShaderMaterial> {
  const material = new THREE.ShaderMaterial({
    uniforms: { uOmegaSun: { value: sunDirection } },
    vertexShader: [
      'varying vec3 vOmegaNormal;',
      'varying vec3 vOmegaWorldPos;',
      'void main() {',
      ' vec4 world = modelMatrix * vec4(position, 1.0);',
      ' vOmegaWorldPos = world.xyz;',
      ' vOmegaNormal = normalize(mat3(modelMatrix) * normal);',
      ' gl_Position = projectionMatrix * viewMatrix * world;',
      '}',
    ].join('\n'),
    fragmentShader: [
      'uniform vec3 uOmegaSun;',
      'varying vec3 vOmegaNormal;',
      'varying vec3 vOmegaWorldPos;',
      'void main() {',
      ' vec3 normal = normalize(vOmegaNormal);',
      ' vec3 eye = normalize(cameraPosition - vOmegaWorldPos);',
      ' float viewAngle = max(dot(normal, eye), 0.0);',
      ' float rim = pow(1.0 - viewAngle, 3.3);',
      ' float lit = smoothstep(-0.3, 0.5, dot(normal, normalize(uOmegaSun)));',
      ' float twilight = 1.0 - smoothstep(0.0, 0.42, abs(dot(normal, normalize(uOmegaSun))));',
      ' vec3 dayBlue = vec3(0.09, 0.57, 1.0);',
      ' vec3 dusk = vec3(1.0, 0.37, 0.19);',
      ' vec3 tone = mix(dayBlue * 0.28, dayBlue, lit);',
      ' tone = mix(tone, dusk, twilight * 0.23);',
      ' float alpha = rim * (0.19 + 0.68 * lit);',
      ' gl_FragColor = vec4(tone, min(alpha, 0.8));',
      '}',
    ].join('\n'),
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
    side: THREE.FrontSide,
  })
  const geometry = new THREE.SphereGeometry(1.65, eco ? 36 : 80, eco ? 24 : 52)
  return new THREE.Mesh(geometry, material)
}
