/* ZION-030 v34 / cinematic post FX for the 3D world only.
 * A bounded render target, bloom, optically subtle rain-lens refraction,
 * daylight/night grading, a vignette and restrained temporal film grain.
 * v36 refinement: no second render target or GPU-expensive temporal pass.
 * The game UI remains an unfiltered DOM overlay.
 */
(function(host){
 'use strict';
 const VERSION='34.0';
 const vert=[
   'varying vec2 vUv;',
   'void main(){vUv=uv;gl_Position=vec4(position.xy,0.0,1.0);}'
 ].join('\n');
 const frag=[
   'precision highp float;',
   'uniform sampler2D tColor;',
   'uniform vec2 uInvRes;',
   'uniform float uRain,uNight,uDay,uTime,uStrength;',
   'varying vec2 vUv;',
   'float luma(vec3 c){return dot(c,vec3(.2126,.7152,.0722));}',
   'void main(){',
   'vec2 px=uInvRes*1.3;',
   'vec2 rainCell=fract(vUv*vec2(63.0,41.0)+vec2(0.0,uTime*.006));',
   'float rainSeed=fract(sin(dot(floor(vUv*vec2(63.0,41.0)),vec2(127.1,311.7)))*43758.5453);',
   'float rainLens=(1.0-smoothstep(.03,.12,length(rainCell-vec2(.5))))*step(.94,rainSeed)*uRain;',
   'vec2 safeUv=clamp(vUv+vec2(px.x*2.1,-px.y*2.7)*rainLens,vec2(.002),vec2(.998));',
   'vec3 src=texture2D(tColor,safeUv).rgb;',
   'vec3 bloom=vec3(0.0);',
   'vec3 p1=texture2D(tColor,vUv+vec2(px.x,0.)).rgb;',
   'vec3 p2=texture2D(tColor,vUv-vec2(px.x,0.)).rgb;',
   'vec3 p3=texture2D(tColor,vUv+vec2(0.,px.y)).rgb;',
   'vec3 p4=texture2D(tColor,vUv-vec2(0.,px.y)).rgb;',
   'bloom+=p1*smoothstep(.66,1.10,luma(p1));',
   'bloom+=p2*smoothstep(.66,1.10,luma(p2));',
   'bloom+=p3*smoothstep(.66,1.10,luma(p3));',
   'bloom+=p4*smoothstep(.66,1.10,luma(p4));',
   'bloom*=.0275;',
   'vec2 edge=vUv-.5;',
   'float vignette=1.0-(.11+.025*uNight)*smoothstep(.06,.55,dot(edge,edge));',
   'vec3 split=vec3(texture2D(tColor,vUv+vec2(px.x*.30,0.)).r,',
   ' src.g,texture2D(tColor,vUv-vec2(px.x*.30,0.)).b);',
   'vec3 grade=vec3(1.0)+uNight*vec3(.012,-.004,-.014)+uDay*vec3(.008,.004,-.005);',
   'vec3 color=mix(src,split,.20)*grade*1.012+bloom*(.85+.13*uNight);',
   'float rainStreak=pow(max(0.0,sin((vUv.x*129.0+uTime*.014)*6.2831853)),36.0);',
   'color+=uRain*rainStreak*vec3(.003,.006,.009);',
   'color=mix(color,vec3(luma(color)),.018);',
   'color.r+=(uNight*.008)-(uRain*.004);',
   'color.b+=(uRain*.010)+(uNight*.005);',
   'color*=vignette;',
   'float grain=fract(sin(dot(vUv/uInvRes+uTime*31.0,',
   ' vec2(12.9898,78.233)))*43758.5453);',
   'color+=(grain-.5)*.0045;',
   'gl_FragColor=vec4(clamp(mix(src,color,uStrength),0.0,1.0),1.0);',
   '}'
 ].join('\n');
 function create({THREE,renderer,scene,camera,mobile=false,softwareGL=false,reducedMotion=false}){
   if(!THREE||!renderer||!scene||!camera)throw Error('ZION34 postFX needs active render pipeline');
   const capable=!!(THREE.WebGLRenderTarget&&THREE.ShaderMaterial&&THREE.OrthographicCamera&&THREE.Vector2);
   const allowed=capable&&!mobile&&!softwareGL&&!reducedMotion;
   const stats={version:VERSION,filmGrade:'cinematic v36',rainLens:true,
     available:capable,eligible:allowed,enabled:false,
     width:0,height:0,passes:0,renderedFrames:0,postFrames:0,quality:'high',disabledReason:
       !capable?'missing WebGL postprocessing support':softwareGL?'software WebGL':
         reducedMotion?'reduced motion':mobile?'mobile GPU budget':''};
   let target=null,quad=null,postScene=null,postCamera=null,material=null,quadGeometry=null,disposed=false;
   if(allowed){
     target=new THREE.WebGLRenderTarget(2,2,{depthBuffer:true,stencilBuffer:false,
       minFilter:THREE.LinearFilter,magFilter:THREE.LinearFilter});
     if(THREE.LinearSRGBColorSpace)target.texture.colorSpace=THREE.LinearSRGBColorSpace;
     postScene=new THREE.Scene();
     postCamera=new THREE.OrthographicCamera(-1,1,1,-1,0,1);
     quadGeometry=new THREE.PlaneGeometry(2,2);
     material=new THREE.ShaderMaterial({
       depthTest:false,depthWrite:false,transparent:false,toneMapped:false,
       uniforms:{
         tColor:{value:target.texture},
         uInvRes:{value:new THREE.Vector2(.5,.5)},
         uRain:{value:0},uNight:{value:0},uDay:{value:0},uTime:{value:0},
         uStrength:{value:1.0}
       },vertexShader:vert,fragmentShader:frag
     });
     quad=new THREE.Mesh(quadGeometry,material);quad.frustumCulled=false;
     postScene.add(quad);stats.passes=1;
   }
   function resize(){
     if(!target||disposed)return;
     const sz=renderer.getDrawingBufferSize(new THREE.Vector2());
     const scale=Math.min(1,2048/Math.max(1,sz.x),1536/Math.max(1,sz.y));
     const w=Math.max(1,Math.floor(sz.x*scale));
     const h=Math.max(1,Math.floor(sz.y*scale));
     if(w!==stats.width||h!==stats.height){
       target.setSize(w,h);material.uniforms.uInvRes.value.set(1/w,1/h);
       stats.width=w;stats.height=h;
     }
   }
   function setQuality(mode){
     stats.quality=mode;
     stats.enabled=Boolean(allowed&&mode!=='eco'&&mode!=='adaptive');
     if(!stats.enabled)stats.disabledReason=!allowed?stats.disabledReason:'eco / adaptive mode';
     else stats.disabledReason='';
     return stats.enabled;
   }
   function syncEnvironment({raining=false,dayMode=0}={}){
     if(!material)return;
     material.uniforms.uRain.value=raining?1:0;
     material.uniforms.uNight.value=dayMode===1?1:0;
     material.uniforms.uDay.value=dayMode===2?1:0;
   }
   function render(time=0){
     if(disposed)throw Error('ZION34 postFX use-after-dispose');
     stats.renderedFrames++;
     if(!stats.enabled||!target){renderer.render(scene,camera);return false;}
     resize();
     const prev=typeof renderer.getRenderTarget==='function'?renderer.getRenderTarget():null;
     try{
       renderer.setRenderTarget(target);
       renderer.render(scene,camera);
       renderer.setRenderTarget(null);
       material.uniforms.uTime.value=Number.isFinite(time)?time:0;
       renderer.render(postScene,postCamera);
       stats.postFrames++;
       return true;
     }catch(error){
       stats.enabled=false;stats.disabledReason='fallback: '+String(error?.message||error).slice(0,120);
       renderer.setRenderTarget(null);
       renderer.render(scene,camera);
       return false;
     }finally{
       if(prev)renderer.setRenderTarget(prev);
     }
   }
   function dispose(){if(disposed)return;disposed=true;
     target?.dispose();material?.dispose();quadGeometry?.dispose();}
   setQuality('high');
   return Object.freeze({get stats(){return Object.freeze({...stats});},
     render,resize,setQuality,syncEnvironment,dispose});
 }
 host.ZION030_POSTFX=Object.freeze({VERSION,create});
})(window);
