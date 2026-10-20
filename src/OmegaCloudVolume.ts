import * as THREE from 'three'
import type { GlobeQuality } from './OmegaGlobe'

/**
 * Camera-facing shell ray marching over static NASA Blue Marble cloud imagery.
 * This approximates optical depth, attenuation and forward-scattering.
 * NOT a meteorological forecast or a physically complete fluid simulation.
 */
export type CloudSystem = {
  group: THREE.Group
  inner: THREE.Mesh
  outer: THREE.Mesh
  update: (elapsedSeconds: number, camera: THREE.Camera) => void
}

export function makeSatelliteCloudSystem(
  image: THREE.Texture,
  tier: GlobeQuality,
  sun: THREE.Vector3,
): CloudSystem {
  const segments = tier === 'ultra' ? 96 : tier === 'eco' ? 38 : 64
  const rings = tier === 'ultra' ? 60 : tier === 'eco' ? 24 : 42
  const steps = tier === 'ultra' ? 10 : tier === 'eco' ? 3 : 6
  const group = new THREE.Group()
  const cameraLocal = new THREE.Vector3(0, 0, 5.7)
  const uniforms = {
    uCloud: { value: image },
    uSun: { value: sun },
    uCameraLocal: { value: cameraLocal },
    uWind: { value: 0 },
    uOpacity: { value: tier === 'ultra' ? 0.83 : 0.7 },
  }

  const cloudMaterial = new THREE.ShaderMaterial({
    uniforms,
    transparent: true,
    depthWrite: false,
    depthTest: true,
    side: THREE.FrontSide,
    blending: THREE.NormalBlending,
    vertexShader: `
      varying vec3 vLocal;
      varying vec3 vWorld;
      void main() {
        vLocal = position;
        vec4 world = modelMatrix * vec4(position, 1.0);
        vWorld = world.xyz;
        gl_Position = projectionMatrix * viewMatrix * world;
      }
    `,
    fragmentShader: `
      uniform sampler2D uCloud;
      uniform vec3 uSun;
      uniform vec3 uCameraLocal;
      uniform float uWind;
      uniform float uOpacity;
      varying vec3 vLocal;
      varying vec3 vWorld;

      float hash(vec3 p) {
        p = fract(p * 0.1031);
        p += dot(p, p.yzx + 33.33);
        return fract((p.x + p.y) * p.z);
      }
      float smoothNoise(vec3 p) {
        vec3 i = floor(p);
        vec3 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        float a = mix(hash(i), hash(i+vec3(1,0,0)), f.x);
        float b = mix(hash(i+vec3(0,1,0)), hash(i+vec3(1,1,0)), f.x);
        float c = mix(hash(i+vec3(0,0,1)), hash(i+vec3(1,0,1)), f.x);
        float d = mix(hash(i+vec3(0,1,1)), hash(i+vec3(1,1,1)), f.x);
        return mix(mix(a,b,f.y), mix(c,d,f.y), f.z);
      }
      vec2 cloudUV(vec3 normal) {
        vec3 n = normalize(normal);
        float u = atan(n.z, -n.x) / 6.28318530718;
        float v = 0.5 + asin(clamp(n.y, -1.0, 1.0)) / 3.14159265359;
        return vec2(u, v);
      }

      void main() {
        vec3 ray = normalize(vLocal - uCameraLocal);
        vec3 outward = normalize(vLocal);
        float incidence = max(dot(outward, -ray), 0.19);
        // Spherical cloud shell, 1.573 to 1.665 above 1.55-radius land sphere.
        float pathLength = min(0.34, 0.092 / incidence);
        float stepSize = pathLength / float(CLOUD_STEPS);
        vec3 light = normalize(uSun);
        float through = 1.0;
        vec3 scattering = vec3(0.0);
        float forward = pow(max(dot(-ray, light), 0.0), 8.0);

        for (int i = 0; i < CLOUD_STEPS; i++) {
          vec3 point = vLocal + ray * (float(i) + 0.5) * stepSize;
          float radial = length(point);
          if (radial < 1.573 || radial > 1.675) continue;
          float altitude = (radial - 1.573) / 0.102;
          float profile = smoothstep(0.00, 0.24, altitude) *
            (1.0 - smoothstep(0.70, 1.00, altitude));
          vec2 uv = cloudUV(point);
          uv.x += uWind * 0.0047;
          float satelliteCoverage = dot(texture2D(uCloud, uv).rgb, vec3(0.299, 0.587, 0.114));
          float coverage = smoothstep(0.20, 0.80, satelliteCoverage);
          float detail = smoothNoise(point * 11.8 + vec3(uWind * 0.026, 0., 0.)) * 0.72
            + smoothNoise(point * 28.0 - vec3(0.0, uWind * 0.018, 0.)) * 0.28;
          float density = coverage * profile * mix(0.35, 1.4, detail);
          float sampleAlpha = 1.0 - exp(-density * 10.8 * stepSize);
          float dayLight = smoothstep(-0.30, 0.50,
            dot(normalize(mat3(modelMatrix) * point), light));
          float scatteringLight = 0.16 + dayLight * 0.79 + forward * dayLight * 0.25;
          vec3 shaded = mix(vec3(0.12, 0.23, 0.42), vec3(0.87, 0.96, 1.0),
            clamp(scatteringLight, 0.0, 1.0));
          scattering += through * sampleAlpha * shaded;
          through *= (1.0 - sampleAlpha);
          if (through < 0.022) break;
        }
        float opacity = clamp((1.0 - through) * uOpacity, 0.0, 0.87);
        if (opacity < 0.006) discard;
        gl_FragColor = vec4(scattering / max(1.0 - through, 0.01), opacity);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }
    `.replaceAll('CLOUD_STEPS', String(steps)),
  })

  const outer = new THREE.Mesh(
    new THREE.SphereGeometry(1.665, segments, rings),
    cloudMaterial,
  )
  const inner = new THREE.Mesh(
    new THREE.SphereGeometry(1.593, Math.max(32, segments - 24), Math.max(22, rings - 14)),
    new THREE.MeshBasicMaterial({
      color: 0xb6ebff,
      alphaMap: image,
      opacity: tier === 'ultra' ? 0.095 : 0.07,
      transparent: true,
      depthWrite: false,
      side: THREE.FrontSide,
    }),
  )
  outer.renderOrder = 3
  inner.renderOrder = 2
  group.add(inner, outer)
  return {
    group, inner, outer,
    update(elapsedSeconds, camera) {
      group.updateWorldMatrix(true, true)
      cameraLocal.copy(camera.position)
      outer.worldToLocal(cameraLocal)
      uniforms.uWind.value = elapsedSeconds
    },
  }
}
