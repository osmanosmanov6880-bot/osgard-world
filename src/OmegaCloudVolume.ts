import * as THREE from 'three'

/** Eight-sample ray-marched cloud-shell approximation for desktop Ultra mode.
 * The base density is procedural artwork; this is not real-time weather or
 * a validated physical radiative-transfer simulation.
 */
export function createCloudVolume(texture: THREE.Texture, sunDirection: THREE.Vector3): THREE.Mesh {
  const material = new THREE.ShaderMaterial({
    uniforms: {
      uCloudMap: { value: texture },
      uSun: { value: sunDirection },
      uTime: { value: 0 },
    },
    vertexShader: "\nvarying vec3 vCloudPoint;\nvoid main() {\n  vec4 p = modelMatrix * vec4(position,1.0);\n  vCloudPoint = p.xyz;\n  gl_Position = projectionMatrix * viewMatrix * p;\n}",
    fragmentShader: "\nuniform sampler2D uCloudMap;\nuniform vec3 uSun;\nuniform float uTime;\nvarying vec3 vCloudPoint;\nconst float PI = 3.14159265359;\nvoid main() {\n  vec3 ray = normalize(vCloudPoint - cameraPosition);\n  float remaining = 1.0;\n  vec3 accumulated = vec3(0.0);\n  // Eight short transparent samples approximate cloud optical depth.\n  // The source is procedural 2D density, not real 3D satellite weather.\n  for (int i = 0; i < 8; ++i) {\n    vec3 p = vCloudPoint + ray * (float(i) * 0.013);\n    float r = length(p);\n    if (r < 1.596 || r > 1.664) continue;\n    vec3 n = normalize(p);\n    vec2 uv = vec2(atan(n.z,n.x) / (2.0 * PI) + 0.5, asin(n.y) / PI + 0.5);\n    uv.x += uTime * 0.00042;\n    float fieldA = texture2D(uCloudMap,uv).a;\n    float fieldB = texture2D(uCloudMap,uv * vec2(2.0, 1.3) + vec2(0.31, -0.08)).a;\n    float density = mix(fieldA,fieldB,0.22);\n    float height = smoothstep(1.596,1.612,r) * (1.0 - smoothstep(1.642,1.662,r));\n    float absorb = clamp(density * height * 0.18, 0.0, 0.42);\n    float light = 0.30 + max(dot(n,normalize(uSun)),0.0) * 0.70;\n    vec3 scattered = mix(vec3(0.19,0.58,0.76), vec3(0.88,0.96,1.00),light);\n    accumulated += scattered * absorb * remaining;\n    remaining *= (1.0 - absorb);\n  }\n  float alpha = clamp(1.0 - remaining, 0.0, 0.60);\n  gl_FragColor = vec4(accumulated * 1.45, alpha * 0.68);\n}",
    transparent: true,
    depthWrite: false,
    side: THREE.FrontSide,
  })
  return new THREE.Mesh(new THREE.SphereGeometry(1.655, 88, 58), material)
}
