/* INHERIT R24 — horizon-matched ocean with camera-space specular response.
 * Real 3D wave normals, Schlick Fresnel and a wide atmospheric falloff remove
 * the rectangular ocean boundary. No textures, CDN, save writes or extra rAF.
 */
const clamp=(v,a=0,b=1)=>Math.min(b,Math.max(a,v));
export function horizonCoverage(x,z,start=.66){
 const radial=Math.hypot(x/70,z/55),startSafe=clamp(start,.05,.98);
 const t=clamp((radial-startSafe)/(1-startSafe));
 return 1-t*t*(3-2*t);
}
export function swell(x,z,time,wind=1){
 const t=time*.42;
 return (
  Math.sin(x*.31+z*.08+t*.9)*.096+
  Math.sin(z*.47-x*.11-t*.72)*.072+
  Math.sin((x+z)*.75+t*1.55)*(.023+.014*wind)
 )*(.68+.32*wind);
}
const WAVE=[
 'float wave(vec2 p,float t,float w){',
 ' float h=sin(p.x*.31+p.y*.08+t*.38)*.096;',
 ' h+=sin(p.y*.47-p.x*.11-t*.3)*.072;',
 ' h+=sin((p.x+p.y)*.75+t*.65)*(.023+.014*w);',
 ' return h*(.68+.32*w);',
 '}'
];
export const waterVertex=[
 'precision highp float;',
 'uniform float uTime;',
 'uniform float uWind;',
 'varying vec2 vPlane;',
 'varying float vCrest;',
 'varying vec3 vEye;',
 'varying vec3 vEyeAxisX;',
 'varying vec3 vEyeAxisY;',
 'varying vec3 vEyeNormal;',
 'varying vec3 vSunEye;',
 ...WAVE,
 'void main(){',
 ' vec3 p=position;',
 ' float height=wave(p.xy,uTime,uWind);',
 ' p.z+=height;',
 ' vCrest=height;vPlane=p.xy;',
 ' vec4 eye=modelViewMatrix*vec4(p,1.0);',
 ' vEye=-eye.xyz;',
 ' vEyeAxisX=normalize(normalMatrix*vec3(1.,0.,0.));',
 ' vEyeAxisY=normalize(normalMatrix*vec3(0.,1.,0.));',
 ' vEyeNormal=normalize(normalMatrix*vec3(0.,0.,1.));',
 ' vSunEye=normalize(normalMatrix*normalize(vec3(-.38,.45,.79)));',
 ' gl_Position=projectionMatrix*eye;',
 '}'
].join('\n');
export const waterFragment=[
 'precision highp float;',
 'uniform float uTime;',
 'uniform float uDawn;',
 'uniform float uWind;',
 'uniform float uHorizonFade;',
 'varying vec2 vPlane;',
 'varying float vCrest;',
 'varying vec3 vEye;',
 'varying vec3 vEyeAxisX;',
 'varying vec3 vEyeAxisY;',
 'varying vec3 vEyeNormal;',
 'varying vec3 vSunEye;',
 ...WAVE,
 'void main(){',
 ' vec2 p=vPlane;',
 ' float eps=.22;',
 ' float dx=(wave(p+vec2(eps,0.),uTime,uWind)-wave(p-vec2(eps,0.),uTime,uWind))/(2.*eps);',
 ' float dz=(wave(p+vec2(0.,eps),uTime,uWind)-wave(p-vec2(0.,eps),uTime,uWind))/(2.*eps);',
 ' vec3 n=normalize(vEyeNormal-2.5*dx*vEyeAxisX-2.5*dz*vEyeAxisY);',
 ' vec3 view=normalize(vEye);',
 ' float ndv=clamp(dot(n,view),0.0,1.0);',
 ' float fresnel=.025+.975*pow(1.0-ndv,5.0);',
 ' float ridge=smoothstep(.055,.125,vCrest);',
 ' float micro=sin(p.x*2.19+uTime*1.38+sin(p.y*.95))*sin(p.y*2.65-uTime*.78);',
 ' float ripples=.5+.5*micro;',
 ' vec3 deep=vec3(.025,.17,.21);',
 ' vec3 aquamarine=vec3(.068,.33,.35);',
 ' vec3 shallow=vec3(.16,.45,.43);',
 ' float nearIsland=1.0-smoothstep(14.0,31.0,length(p));',
 ' vec3 color=mix(deep,aquamarine,clamp(.26+uDawn*.42+ripples*.14,0.0,1.0));',
 ' color=mix(color,shallow,clamp(nearIsland*.17+ridge*.08+uDawn*.10,0.0,.43));',
 ' vec3 halfDir=normalize(view+normalize(vSunEye));',
 ' float sun=pow(max(dot(n,halfDir),0.0),88.0);',
 ' float sparkle=pow(max(0.0,sin(p.x*1.23+p.y*.77+uTime*.31)),19.0);',
 ' color+=vec3(.89,.75,.46)*sun*(.11+uDawn*.21)*(.20+.80*fresnel);',
 ' color+=vec3(.22,.31,.28)*fresnel*.29;',
 ' color+=vec3(.15,.19,.13)*ridge*.12;',
 ' color+=vec3(.21,.25,.20)*sparkle*.032;',
 ' float ellipse=length(vec2(p.x/70.0,p.y/55.0));',
 ' float oceanAlpha=1.0-smoothstep(uHorizonFade,1.0,ellipse);',
 ' gl_FragColor=vec4(color,clamp(oceanAlpha,0.0,1.0));',
 '}'
].join('\n');
