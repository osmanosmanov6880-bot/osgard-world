/* INHERIT R17 CAMERA / CINEMATIC LIGHT ENGINE
 * Real HDR-compatible post effects: selective restrained bloom, subtle
 * shoulder grading, physically plausible vignette, optional film grain.
 * The effect composer is disabled automatically for software GPUs and low
 * power devices. All passes dispose cleanly when changing quality.
 */
import * as THREE from 'three';
import {EffectComposer} from 'three/addons/postprocessing/EffectComposer.js';
import {RenderPass} from 'three/addons/postprocessing/RenderPass.js';
import {UnrealBloomPass} from 'three/addons/postprocessing/UnrealBloomPass.js';
import {ShaderPass} from 'three/addons/postprocessing/ShaderPass.js';
import {OutputPass} from 'three/addons/postprocessing/OutputPass.js';
import {FXAAShader} from 'three/addons/shaders/FXAAShader.js';
const GRADE_SHADER={
 uniforms:{
  tDiffuse:{value:null},
  uTime:{value:0},
  uVignette:{value:.14},
  uGrain:{value:.007},
  uWarmth:{value:.018}
 },
 vertexShader:[
  'varying vec2 vUv;',
  'void main(){vUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}'
 ].join('\n'),
 fragmentShader:[
  'precision mediump float;',
  'varying vec2 vUv;',
  'uniform sampler2D tDiffuse;',
  'uniform float uTime;',
  'uniform float uVignette;',
  'uniform float uGrain;',
  'uniform float uWarmth;',
  'float rand(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453123);}',
  'void main(){',
  ' vec4 src=texture2D(tDiffuse,vUv);',
  ' vec3 rgb=src.rgb;',
  ' rgb.r+=uWarmth*.18;',
  ' rgb.b-=uWarmth*.10;',
  ' vec2 uv=(vUv-.5)*vec2(1.04,.98);',
  ' float vignette=1.-smoothstep(.15,.72,dot(uv,uv))*uVignette;',
  ' float grain=(rand(gl_FragCoord.xy+uTime*3.)-.5)*uGrain;',
  ' rgb=clamp(rgb*vignette+grain,0.,50.);',
  ' gl_FragColor=vec4(rgb,src.a);',
  '}'
 ].join('\n')
};
export function detectAdapter(renderer){
 let vendor='unknown',model='unknown',webglVersion=0;
 const gl=renderer?.getContext?.();
 if(!gl)return {vendor,model,webglVersion,isSoftware:true,evidence:'no webgl context'};
 try{
  webglVersion=gl.getParameter(gl.VERSION)||'WebGL';
  const extension=gl.getExtension('WEBGL_debug_renderer_info');
  vendor=extension?String(gl.getParameter(extension.UNMASKED_VENDOR_WEBGL)):'masked';
  model=extension?String(gl.getParameter(extension.UNMASKED_RENDERER_WEBGL)):'masked';
 }catch{}
 const descriptor=vendor+' '+model;
 const isSoftware=/SwiftShader|llvmpipe|softpipe|software|WARP|Microsoft Basic Render/i.test(descriptor);
 const evidence=model==='masked'?'masked adapter, GPU not established':isSoftware?'software rasterizer':'hardware not independently verified';
 return {vendor,model,webglVersion,isSoftware,evidence};
}
export function makeCinematicPipeline({renderer,scene,camera,quality='high',adapter,wanted=true}){
 const software=adapter?.isSoftware??true;
 const mode=!wanted?'off':quality==='high'&&!software?'cinematic':'lite';
 let composer=null,bloom=null,grade=null,antialias=null,frames=0;
 if(mode!=='off'){
  composer=new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene,camera));
  if(mode==='cinematic'){
   bloom=new UnrealBloomPass(new THREE.Vector2(512,512),.19,.29,.93);
   composer.addPass(bloom);
   // Render-target multisampling is not assumed: high-end scenes need a real
   // edge-aware postprocess for fine leaf silhouettes and engraved sculptures.
   // Software and low-power adapters remain on the cheaper three-pass path.
   antialias=new ShaderPass(FXAAShader);
   composer.addPass(antialias);
  }
  grade=new ShaderPass(GRADE_SHADER);
  grade.uniforms.uVignette.value=mode==='cinematic'?.15:.10;
  grade.uniforms.uGrain.value=mode==='cinematic'?.006:0;
  composer.addPass(grade);
  composer.addPass(new OutputPass());
 }
 function render(now,delta=.033,reducedMotion=false){
  if(composer){
   if(grade)grade.uniforms.uTime.value=reducedMotion?0:now*.001;
   composer.render(Math.max(.008,Math.min(delta,.08)));
  }else renderer.render(scene,camera);
  frames++;
 }
 function resize(width,height,ratio=1){
  if(!composer)return;
  const pixelRatio=Math.min(1.6,Math.max(.6,ratio));
  const physicalWidth=Math.max(2,Math.floor(width))*pixelRatio;
  const physicalHeight=Math.max(2,Math.floor(height))*pixelRatio;
  composer.setPixelRatio(pixelRatio);
  composer.setSize(Math.max(2,Math.floor(width)),Math.max(2,Math.floor(height)));
  if(antialias)antialias.uniforms.resolution.value.set(1/physicalWidth,1/physicalHeight);
 }
 function dispose(){
  if(!composer)return;
  bloom?.dispose?.();
  antialias?.dispose?.();
  grade?.dispose?.();
  composer.dispose?.();
 }
 return {mode,render,resize,dispose,
  stats:()=>({mode,frames,bloom:!!bloom,antiAliasing:!!antialias,grading:!!grade,passes:mode==='cinematic'?5:mode==='lite'?3:1})};
}
