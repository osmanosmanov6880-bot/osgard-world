import * as THREE from 'three'
import type { GlobeQuality } from './OmegaGlobe'

/**
 * NASA Blue Marble 2004 day albedo + NASA Black Marble 2016 night lights.
 * Illumination is cinematic; globe/camera freely rotate; no claim of live imagery.
 */
export type SatelliteTextures = {
  day: THREE.Texture
  night: THREE.Texture
  clouds: THREE.Texture | null
}

export async function loadSatelliteTextures(
  tier: GlobeQuality,
  cancelled: AbortSignal,
): Promise<SatelliteTextures> {
  const loader = new THREE.TextureLoader()
  const loaded: THREE.Texture[] = []
  const load = async (path: string, colorSpace: THREE.ColorSpace) => {
    const texture = await loader.loadAsync(path)
    loaded.push(texture)
    if (cancelled.aborted) throw new Error('satellite loading cancelled')
    texture.colorSpace = colorSpace
    texture.wrapS = THREE.RepeatWrapping
    texture.minFilter = THREE.LinearMipmapLinearFilter
    texture.magFilter = THREE.LinearFilter
    texture.anisotropy = tier === 'ultra' ? 4 : tier === 'eco' ? 1 : 2
    texture.needsUpdate = true
    return texture
  }
  try {
    const day = await load(
      tier === 'ultra' ? '/brand/nasa/earth-day-4096.jpg' : '/brand/nasa/earth-day-2048.jpg',
      THREE.SRGBColorSpace,
    )
    const night = await load('/brand/nasa/earth-night-2048.jpg', THREE.SRGBColorSpace)
    let clouds: THREE.Texture | null = null
    if (tier !== 'eco') {
      try {
        clouds = await load('/brand/nasa/earth-clouds-2048.jpg', THREE.NoColorSpace)
      } catch (error) {
        if (cancelled.aborted) throw error
        // Satellite day/night maps remain useful without the optional cloud asset.
      }
    }
    return { day, night, clouds }
  } catch (error) {
    loaded.forEach(texture => texture.dispose())
    throw error
  }
}

/** Satellite day/night surface with a twilight terminator and ocean Fresnel. */
export function satelliteSurfaceMaterial(
  images: SatelliteTextures,
  sunWorld: THREE.Vector3,
): THREE.ShaderMaterial {
  return new THREE.ShaderMaterial({
    uniforms: {
      uDay: { value: images.day },
      uNight: { value: images.night },
      uSun: { value: sunWorld },
      uNightStrength: { value: 1.05 },
    },
    vertexShader: `
      varying vec2 vEarthUv;
      varying vec3 vEarthWorldNormal;
      varying vec3 vEarthWorldPosition;
      void main() {
        vEarthUv = uv;
        vec4 world = modelMatrix * vec4(position, 1.0);
        vEarthWorldPosition = world.xyz;
        vEarthWorldNormal = normalize(mat3(modelMatrix) * normal);
        gl_Position = projectionMatrix * viewMatrix * world;
      }
    `,
    fragmentShader: `
      uniform sampler2D uDay;
      uniform sampler2D uNight;
      uniform vec3 uSun;
      uniform float uNightStrength;
      varying vec2 vEarthUv;
      varying vec3 vEarthWorldNormal;
      varying vec3 vEarthWorldPosition;

      void main() {
        vec3 N = normalize(vEarthWorldNormal);
        vec3 L = normalize(uSun);
        vec3 V = normalize(cameraPosition - vEarthWorldPosition);
        vec3 H = normalize(L + V);
        float ndl = dot(N, L);
        float twilight = smoothstep(-0.13, 0.17, ndl);
        float diffuse = max(ndl, 0.0);

        vec3 albedo = texture2D(uDay, vEarthUv).rgb;
        vec3 night = texture2D(uNight, vEarthUv).rgb;

        // Dark-blue albedo approximates an ocean mask, not precise GIS water data.
        float ocean = smoothstep(0.015, 0.15,
          albedo.b - (albedo.r * 0.82 + albedo.g * 0.18));
        ocean *= 1.0 - smoothstep(0.23, 0.78, dot(albedo, vec3(0.3333)));

        // Schlick-inspired Fresnel and a narrow directional ocean glint.
        float fresnel = pow(1.0 - max(dot(N, V), 0.0), 5.0);
        float specular = pow(max(dot(N, H), 0.0), 96.0) * diffuse;
        float reflection = ocean * (specular * 1.25 + fresnel * 0.105 * diffuse);
        vec3 sea = mix(albedo, albedo * vec3(0.75, 1.02, 1.13), ocean * 0.48);
        vec3 day = sea * (0.19 + 0.9 * diffuse);
        day += vec3(0.55, 0.79, 0.95) * reflection;

        // Real NASA nighttime lights appear only where the rotating Earth is dark.
        float lightMap = dot(night, vec3(0.299, 0.587, 0.114));
        float nightMask = 1.0 - smoothstep(-0.1, 0.08, ndl);
        vec3 cityLights = vec3(1.00, 0.73, 0.43) *
          pow(max(lightMap - 0.045, 0.0), 1.17) * uNightStrength * nightMask * 1.8;
        vec3 twilightRim = vec3(0.10, 0.32, 0.43) *
          exp(-pow(ndl / 0.13, 2.0)) * 0.12;

        vec3 color = mix(albedo * vec3(0.035, 0.048, 0.09), day, twilight);
        color += cityLights + twilightRim;
        gl_FragColor = vec4(max(color, vec3(0.0)), 1.0);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }
    `,
  })
}

/** Rayleigh/Mie-inspired atmospheric limb; not a spectral weather simulation. */
export function atmosphereMaterial(sunWorld: THREE.Vector3): THREE.ShaderMaterial {
  return new THREE.ShaderMaterial({
    uniforms: {
      uSun: { value: sunWorld },
      uDensity: { value: 0.63 },
    },
    transparent: true,
    depthWrite: false,
    side: THREE.FrontSide,
    blending: THREE.AdditiveBlending,
    vertexShader: `
      varying vec3 vNormalWorld;
      varying vec3 vPositionWorld;
      void main() {
        vec4 world = modelMatrix * vec4(position, 1.0);
        vPositionWorld = world.xyz;
        vNormalWorld = normalize(mat3(modelMatrix) * normal);
        gl_Position = projectionMatrix * viewMatrix * world;
      }
    `,
    fragmentShader: `
      uniform vec3 uSun;
      uniform float uDensity;
      varying vec3 vNormalWorld;
      varying vec3 vPositionWorld;
      void main() {
        vec3 N = normalize(vNormalWorld);
        vec3 V = normalize(cameraPosition - vPositionWorld);
        vec3 L = normalize(uSun);
        float limb = pow(1.0 - max(dot(N, V), 0.0), 3.25);
        float sunlight = dot(N, L);
        float dayPart = smoothstep(-0.27, 0.26, sunlight);
        float dusk = exp(-pow(sunlight / 0.19, 2.0));
        vec3 rayleigh = vec3(0.12, 0.52, 1.0) * (0.35 + 0.65 * dayPart);
        vec3 mie = vec3(1.0, 0.36, 0.19) * dusk * 0.55;
        vec3 color = rayleigh + mie;
        float alpha = limb * (0.25 + dayPart * 0.37 + dusk * 0.19) * uDensity;
        gl_FragColor = vec4(color, min(alpha, 0.62));
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }
    `,
  })
}
