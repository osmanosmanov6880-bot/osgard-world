/* INHERIT R17 — physically inspired offshore lighting and layered swell.
 * Procedural ocean: two directional swells, wind choppiness, short waves,
 * smooth directional specular and broad horizon fresnel. No image imports.
 */
export function swell(x,z,time,wind=1){
 const t=time*.42;
 return (
  Math.sin(x*.31+z*.08+t*.9)*.096+
  Math.sin(z*.47-x*.11-t*.72)*.072+
  Math.sin((x+z)*.75+t*1.55)*(.023+.014*wind)
 )*(.68+.32*wind);
}
export const waterVertex=[
 'precision highp float;',
 'uniform float uTime;',
 'uniform float uWind;',
 'varying vec2 vPlane;',
 'varying float vCrest;',
 'varying vec3 vEye;',
 'float wave(vec2 p,float t,float w){',
 ' float h=sin(p.x*.31+p.y*.08+t*.38)*.096;',
 ' h+=sin(p.y*.47-p.x*.11-t*.3)*.072;',
 ' h+=sin((p.x+p.y)*.75+t*.65)*(.023+.014*w);',
 ' return h*(.68+.32*w);',
 '}',
 'void main(){',
 ' vec3 p=position;',
 ' float height=wave(p.xy,uTime,uWind);',
 ' p.z+=height;',
 ' vCrest=height;vPlane=p.xy;',
 ' vec4 eye=modelViewMatrix*vec4(p,1.);',
 ' vEye=-eye.xyz;',
 ' gl_Position=projectionMatrix*eye;',
 '}'
].join('\n');
export const waterFragment=[
 'precision highp float;',
 'uniform float uTime;',
 'uniform float uDawn;',
 'uniform float uWind;',
 'varying vec2 vPlane;',
 'varying float vCrest;',
 'varying vec3 vEye;',
 'float wave(vec2 p,float t,float w){',
 ' float h=sin(p.x*.31+p.y*.08+t*.38)*.096;',
 ' h+=sin(p.y*.47-p.x*.11-t*.3)*.072;',
 ' h+=sin((p.x+p.y)*.75+t*.65)*(.023+.014*w);',
 ' return h*(.68+.32*w);',
 '}',
 'float hash12(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453123);}',
 'void main(){',
 ' vec2 p=vPlane;',
 ' float eps=.22;',
 ' float dx=(wave(p+vec2(eps,0.),uTime,uWind)-wave(p-vec2(eps,0.),uTime,uWind))/(2.*eps);',
 ' float dz=(wave(p+vec2(0.,eps),uTime,uWind)-wave(p-vec2(0.,eps),uTime,uWind))/(2.*eps);',
 ' vec3 n=normalize(vec3(-dx*3.3,-dz*3.3,1.));',
 ' vec3 view=normalize(vEye);',
 ' float ndv=max(dot(n,vec3(.15,.33,.93)),0.);',
 ' float fresnel=pow(1.-ndv,3.2);',
 ' float ridge=smoothstep(.072,.13,vCrest);',
 ' float micro=sin(p.x*2.19+uTime*1.38+sin(p.y*.95))*',
 '             sin(p.y*2.65-uTime*.78);',
 ' float ripples=.5+.5*micro;',
 ' vec3 deep=vec3(.026,.20,.24);',
 ' vec3 aquamarine=vec3(.075,.39,.41);',
 ' vec3 shallow=vec3(.17,.51,.49);',
 ' vec3 color=mix(deep,aquamarine,clamp(uDawn*.69+ripples*.24,0.,1.));',
 ' color=mix(color,shallow,clamp(ridge*.13+uDawn*.19,0.,.46));',
 ' float sun=pow(max(dot(reflect(-normalize(vec3(-.36,.82,.43)),n),normalize(vec3(.0,.63,.77))),0.),46.);',
 ' float sparkle=pow(max(0.,sin(p.x*1.23+p.y*.77+uTime*.31)),19.);',
 ' color+=vec3(.81,.75,.51)*sun*.19;',
 ' color+=vec3(.27,.34,.22)*sparkle*.1;',
 ' color+=vec3(.31,.38,.37)*fresnel*.21;',
 ' color+=vec3(.13,.17,.12)*ridge*.12;',
 ' gl_FragColor=vec4(color,1.);',
 '}'
].join('\n');
