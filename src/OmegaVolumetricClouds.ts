import * as THREE from 'three'

/**
 * Real-time thin-shell volumetric clouds for the premium OSGARD Earth.
 *
 * Unlike two transparent textured spheres, this shader ray-marches samples
 * through the altitude between two radii, integrates optical depth, models
 * changing density with altitude and shades it relative to the sun.
 *
 * Cloud coverage is PROCEDURAL, not a live weather map. The camera, textures
 * and lights remain entirely client-side; no remote API or tracking.
 *
 * Desktop Auto: 7 samples (may drop to 4 under load); Ultra: 12 samples.
 * Eco and mobile Auto retain the significantly cheaper two-layer fallback.
 */

export type CloudSampleCount = 4 | 7 | 12

export interface VolumetricClouds {
  material: THREE.ShaderMaterial
  maxSamples: CloudSampleCount
  setSamples: (samples: CloudSampleCount) => void
  update: (camera: THREE.PerspectiveCamera, mesh: THREE.Mesh, sun: THREE.Vector3) => void
}

const VERTEX_SHADER = [
  'varying vec3 vOmegaCloudPos;',
  'void main() {',
  '  vOmegaCloudPos = position;',
  '  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);',
  '}',
].join('\n')

const FRAGMENT_SHADER = [
  'precision highp float;',
  'varying vec3 vOmegaCloudPos;',
  'uniform sampler2D uCloudMap;',
  'uniform vec3 uCameraLocal;',
  'uniform vec3 uSunLocal;',
  'uniform int uSamples;',
  '',
  '// SphereGeometry uses north at v=1 and phi=atan(z,-x).',
  'vec2 cloudUV(vec3 position) {',
  '  vec3 n = normalize(position);',
  '  float lon = atan(n.z, -n.x);',
  '  float lat = acos(clamp(n.y, -1.0, 1.0));',
  '  return vec2(fract(lon / 6.28318530718 + 1.0), 1.0 - lat / 3.14159265359);',
  '}',
  '',
  'float densityAt(vec3 p) {',
  '  float r = length(p);',
  '  float height = clamp((r - 1.580) / 0.038, 0.0, 1.0);',
  '  float altitude = smoothstep(0.04, 0.25, height) * (1.0 - smoothstep(0.68, 1.0, height));',
  '  vec2 uv = cloudUV(p);',
  '  float coverage = texture2D(uCloudMap, uv).a;',
  '  // A subtle third dimension creates changing sub-cloud density.',
  '  float turbulence = sin(dot(p, vec3(137.1, 88.7, 152.5))) *',
  '                     sin(dot(p, vec3(63.5, 171.3, 94.9)));',
  '  return smoothstep(0.19, 0.82, coverage + 0.065 * turbulence) * altitude;',
  '}',
  '',
  'void main() {',
  '  vec3 outward = normalize(vOmegaCloudPos);',
  '  vec3 ray = normalize(vOmegaCloudPos - uCameraLocal);',
  '  float radialRay = dot(vOmegaCloudPos, ray);',
  '  // From the exterior cloud surface, find the first interior hit.',
  '  float innerRadius = 1.580;',
  '  float discriminant = radialRay * radialRay -',
  '                       dot(vOmegaCloudPos, vOmegaCloudPos) + innerRadius * innerRadius;',
  '  float distanceThrough = discriminant > 0.0',
  '    ? max(0.0, -radialRay - sqrt(discriminant))',
  '    : max(0.0, -2.0 * radialRay);',
  '  distanceThrough = min(distanceThrough, 0.36);',
  '  if (distanceThrough < 0.0001) discard;',
  '',
  '  float stepLength = distanceThrough / float(uSamples);',
  '  float transmittance = 1.0;',
  '  float illuminated = 0.0;',
  '  vec3 light = normalize(uSunLocal);',
  '  for (int i = 0; i < 12; i++) {',
  '    if (i >= uSamples) break;',
  '    vec3 point = vOmegaCloudPos + ray * ((float(i) + 0.5) * stepLength);',
  '    float density = densityAt(point);',
  '    float opticalDepth = density * stepLength * 53.0;',
  '    float absorbed = 1.0 - exp(-opticalDepth);',
  '    float sunAngle = dot(normalize(point), light);',
  '    float daylight = smoothstep(-0.30, 0.52, sunAngle);',
  '    illuminated += transmittance * absorbed * daylight;',
  '    transmittance *= 1.0 - absorbed;',
  '    if (transmittance < 0.035) break;',
  '  }',
  '',
  '  float opacity = clamp(1.0 - transmittance, 0.0, 0.86);',
  '  if (opacity < 0.006) discard;',
  '  float dayFraction = clamp(illuminated / max(opacity, 0.015), 0.0, 1.0);',
  '  float forwardScattering = pow(max(dot(light, -ray), 0.0), 7.0);',
  '  float edge = pow(1.0 - max(dot(outward, -ray), 0.0), 2.7);',
  '  vec3 night = vec3(0.035, 0.073, 0.116);',
  '  vec3 day = vec3(0.83, 0.92, 0.98);',
  '  vec3 cloudColor = mix(night, day, dayFraction);',
  '  cloudColor += vec3(0.17, 0.32, 0.40) * forwardScattering * edge * dayFraction;',
  '  gl_FragColor = vec4(cloudColor, opacity);',
  '}',
].join('\n')

/**
 * Uses the SAME procedural coverage texture as cheap cloud shells and surface
 * shadowing. Only an additional shader/material is allocated; no network fetch.
 */
export function createVolumetricClouds(
  cloudTexture: THREE.Texture,
  maxSamples: CloudSampleCount,
): VolumetricClouds {
  const localCamera = new THREE.Vector3(0, 0, 6)
  const localSun = new THREE.Vector3(0, 1, 0)
  const sampleUniform = { value: maxSamples }
  const inverseMatrix = new THREE.Matrix4()
  const material = new THREE.ShaderMaterial({
    uniforms: {
      uCloudMap: { value: cloudTexture },
      uCameraLocal: { value: localCamera },
      uSunLocal: { value: localSun },
      uSamples: sampleUniform,
    },
    vertexShader: VERTEX_SHADER,
    fragmentShader: FRAGMENT_SHADER,
    side: THREE.FrontSide,
    transparent: true,
    depthTest: true,
    depthWrite: false,
    blending: THREE.NormalBlending,
  })
  material.name = 'OSGARD_VOLUMETRIC_CLOUDS'
  return {
    material,
    maxSamples,
    setSamples: samples => {
      sampleUniform.value = Math.min(maxSamples, Math.max(4, samples))
    },
    update: (camera, mesh, sun) => {
      inverseMatrix.copy(mesh.matrixWorld).invert()
      localCamera.copy(camera.position).applyMatrix4(inverseMatrix)
      localSun.copy(sun).transformDirection(inverseMatrix)
    },
  }
}
