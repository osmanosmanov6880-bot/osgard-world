/* ZION-030 v34 / performance evidence
 * Records actual browser frame timings, render CPU time and optional
 * EXT_disjoint_timer_query_webgl2 GPU time. Never fabricates hardware FPS.
 */
(function(host){
 'use strict';
 const VERSION='34.0',SW=/swiftshader|llvmpipe|lavapipe|software|softpipe|angle.*(d3d11on12|warp)/i;
 const clamp=(x,a,b)=>Math.max(a,Math.min(b,x));
 const percentile=(values,quantile)=>{
   if(!values.length)return null;
   const v=values.filter(Number.isFinite).sort((a,b)=>a-b);
   if(!v.length)return null;
   const i=Math.min(v.length-1,Math.max(0,Math.ceil(v.length*quantile)-1));
   return Math.round(v[i]*100)/100;
 };
 function create({THREE,renderer,scene,shell,softwareGL=false,mobile=false}){
   if(!renderer||!scene||!shell)throw Error('ZION34 perf requires renderer and game shell');
   const gl=typeof renderer.getContext==='function'?renderer.getContext():null;
   let vendor='Unavailable',name='Unavailable',classification='unknown';
   try{
     const ext=gl?.getExtension('WEBGL_debug_renderer_info');
     if(ext){
       vendor=String(gl.getParameter(ext.UNMASKED_VENDOR_WEBGL)||'Unavailable');
       name=String(gl.getParameter(ext.UNMASKED_RENDERER_WEBGL)||'Unavailable');
       classification=SW.test(vendor+' '+name)?'software':'hardware-reported';
     }else if(gl){
       vendor=String(gl.getParameter(gl.VENDOR)||'Unavailable');
       name=String(gl.getParameter(gl.RENDERER)||'Unavailable');
       if(SW.test(vendor+' '+name))classification='software';
     }
   }catch(_){}
   if(softwareGL)classification='software';
   const contextName=gl?.constructor?.name||'WebGL unknown';
   const glTimer=gl?.getExtension?.('EXT_disjoint_timer_query_webgl2')||null;
   const gpuSupported=!!(glTimer&&gl?.createQuery&&gl?.beginQuery&&gl?.getQueryParameter&&gl?.endQuery);
   let running=false,activeQuery=null,pending=[],gpuMs=[],renderIntervals=[],cpuTimes=[],
     drawCalls=[],triangles=[],startedAt=0,lastRenderedAt=0,lastReport=null,duration=15000;
   const state={version:VERSION,renderer:name,vendor,classification,
     gpuTimerAvailable:gpuSupported,gpuSamples:0,frames:0,active:false,progress:0,
     durationMs:15000,mobile:Boolean(mobile),softwareGL:Boolean(softwareGL),
     reportAvailable:false,measuredOnPhysicalGpu:false};
   const panel=document.createElement('aside');
   panel.id='oc-perf-panel';panel.className='oc-perf-panel';panel.hidden=true;
   panel.setAttribute('role','status');panel.setAttribute('aria-live','polite');
   const title=document.createElement('strong');title.textContent='GPU / ПРОФИЛЬ КАДРА';
   const desc=document.createElement('p');
   desc.textContent='Тест измеряет этот браузер и этот GPU. Автоматический CI с SwiftShader не считается физическим GPU.';
   const details=document.createElement('pre');details.id='oc-perf-data';
   details.textContent='Нажми «ЗАМЕРИТЬ», затем иди или едь по городу.';
   const controls=document.createElement('div');
   const startButton=document.createElement('button');startButton.type='button';startButton.id='oc-perf-start';
   startButton.textContent='▶ ЗАМЕРИТЬ 15 С';
   const copyButton=document.createElement('button');copyButton.type='button';copyButton.id='oc-perf-copy';
   copyButton.textContent='⧉ КОПИЯ JSON';copyButton.disabled=true;
   const close=document.createElement('button');close.type='button';close.id='oc-perf-close';
   close.textContent='✕ ЗАКРЫТЬ';
   controls.append(startButton,copyButton,close);panel.append(title,desc,details,controls);
   shell.append(panel);
   const header=shell.querySelector('.oc-top-right');
   const trigger=document.createElement('button');trigger.type='button';
   trigger.id='oc-perf-trigger';trigger.className='oc-glass oc-perf-trigger';
   trigger.textContent='◷ FPS';trigger.setAttribute('aria-label','Открыть измерение производительности 3D');
   trigger.title='Измерить производительность — клавиша B';
   if(header)header.insertBefore(trigger,header.lastElementChild);
   const show=flag=>{panel.hidden=!flag;trigger.setAttribute('aria-pressed',String(flag));};
   trigger.addEventListener('click',()=>show(panel.hidden));
   close.addEventListener('click',()=>show(false));
   function pollGpu(){
     if(!gpuSupported)return;
     while(pending.length){
       const q=pending[0];
       let ready=false,disjoint=true;
       try{
         ready=gl.getQueryParameter(q,gl.QUERY_RESULT_AVAILABLE);
         disjoint=Boolean(gl.getParameter(glTimer.GPU_DISJOINT_EXT));
       }catch(_){break}
       if(!ready)break;
       pending.shift();
       if(!disjoint)try{
         const nanos=gl.getQueryParameter(q,gl.QUERY_RESULT);
         if(Number.isFinite(nanos)&&nanos>=0)gpuMs.push(nanos/1000000);
       }catch(_){}
       try{gl.deleteQuery(q)}catch(_){}
     }
   }
   function start(ms=15000){
     if(running)return false;
     duration=clamp(Number.isFinite(ms)?ms:15000,3000,60000);
     renderIntervals=[];cpuTimes=[];drawCalls=[];triangles=[];gpuMs=[];
     if(gpuSupported){pollGpu();while(pending.length){try{gl.deleteQuery(pending.shift())}catch(_){}}}
     running=true;startedAt=performance.now();lastRenderedAt=0;lastReport=null;
     state.active=true;state.frames=0;state.progress=0;state.durationMs=duration;
     state.gpuSamples=0;state.reportAvailable=false;state.measuredOnPhysicalGpu=false;
     details.textContent='Замер: 0% · двигайся по городу и меняй ракурсы';
     startButton.disabled=true;copyButton.disabled=true;
     show(true);return true;
   }
   function beginRender(){
     if(!running)return null;
     if(typeof renderer.info?.reset==='function')renderer.info.reset();
     pollGpu();
     if(gpuSupported&&pending.length<4){
       try{
         activeQuery=gl.createQuery();
         gl.beginQuery(glTimer.TIME_ELAPSED_EXT,activeQuery);
       }catch(_){if(activeQuery){try{gl.deleteQuery(activeQuery)}catch(_){}}activeQuery=null;}
     }
     return performance.now();
   }
   function endRender(t0){
     if(t0===null||!running)return;
     const now=performance.now();
     cpuTimes.push(clamp(now-t0,0,60000));
     if(lastRenderedAt)renderIntervals.push(clamp(now-lastRenderedAt,0,60000));
     lastRenderedAt=now;
     drawCalls.push(renderer.info?.render?.calls||0);
     triangles.push(renderer.info?.render?.triangles||0);
     if(activeQuery){
       try{gl.endQuery(glTimer.TIME_ELAPSED_EXT);pending.push(activeQuery)}
       catch(_){try{gl.deleteQuery(activeQuery)}catch(__){}}
       activeQuery=null;
     }
     state.frames=cpuTimes.length;
     state.progress=clamp((now-startedAt)/duration,0,1);
     if(cpuTimes.length%14===0)
       details.textContent='Замер: '+Math.floor(state.progress*100)+'% · кадры '+state.frames+
        ' · '+classification+' GPU';
     if(now-startedAt>=duration)stop();
   }
   function stop(){
     if(!running)return lastReport;
     running=false;state.active=false;
     if(activeQuery){try{gl.endQuery(glTimer.TIME_ELAPSED_EXT);pending.push(activeQuery)}catch(_){}
       activeQuery=null;}
     pollGpu();
     const elapsed=Math.max(1,performance.now()-startedAt);
     const frameP95=percentile(renderIntervals,.95);
     const cpuP95=percentile(cpuTimes,.95);
     const report={
       version:VERSION,source:'browser WebGL measured, not estimated',
       timestamp:new Date().toISOString(),hardwareClassification:classification,
       gpuVendor:vendor,gpuRenderer:name,webglContext:contextName,
       physicalGpuConfirmed:classification==='hardware-reported',
       note:classification==='hardware-reported'?
         'Hardware acceleration reported by WebGL; device identification is browser supplied.':
         'Real physical GPU performance NOT verified on this browser.',
       mobile:state.mobile,softwareGL:state.softwareGL,
       sampleDurationMs:Math.round(elapsed),renderedFrames:cpuTimes.length,
       renderFPS:Math.round(cpuTimes.length/(elapsed/1000)*10)/10,
       frameMsP50:percentile(renderIntervals,.50),frameMsP95:frameP95,
       cpuRenderMsP50:percentile(cpuTimes,.50),cpuRenderMsP95:cpuP95,
       gpuRenderMsP50:percentile(gpuMs,.50),gpuRenderMsP95:percentile(gpuMs,.95),
       gpuTimerSamples:gpuMs.length,gpuTimerAvailable:gpuSupported,
       drawCallsP95:percentile(drawCalls,.95),
       trianglesP95:percentile(triangles,.95),
       displayRefreshHz:null,
       benchmarkValid:elapsed>=2800&&cpuTimes.length>=8,
       warning:classification==='software'?
         'Software WebGL detected: these FPS values cannot represent desktop/mobile GPU results.':
         classification==='unknown'?'GPU acceleration unknown; run on a device with WEBGL_debug_renderer_info.':null
     };
     lastReport=Object.freeze(report);state.gpuSamples=gpuMs.length;
     state.reportAvailable=true;state.measuredOnPhysicalGpu=report.physicalGpuConfirmed;
     startButton.disabled=false;copyButton.disabled=false;
     details.textContent=JSON.stringify(report,null,2);
     return lastReport;
   }
   startButton.addEventListener('click',()=>{if(!running)start();});
   copyButton.addEventListener('click',async()=>{
     if(!lastReport)return;
     try{await navigator.clipboard.writeText(JSON.stringify(lastReport,null,2));
       copyButton.textContent='✓ СКОПИРОВАНО';}
     catch(_){copyButton.textContent='КОПИЯ НЕДОСТУПНА';}
   });
   window.addEventListener('keydown',e=>{
     if(e.code!=='KeyB'||e.ctrlKey||e.metaKey||e.altKey||e.repeat||shell.hidden)return;
     if(e.target?.matches?.('textarea,input,[contenteditable]'))return;
     if(!document.getElementById('oc-journal')?.hidden||!document.getElementById('oc-pause')?.hidden)return;
     e.preventDefault();show(panel.hidden);
   });
   function snapshot(){
     return Object.freeze({...state,performanceReport:lastReport});
   }
   function dispose(){
     stop();
     while(pending.length)try{gl.deleteQuery(pending.shift())}catch(_){}
     panel.remove();trigger.remove();
   }
   return Object.freeze({snapshot,start,stop,beginRender,endRender,dispose,
     toggle:()=>show(panel.hidden),get report(){return lastReport;}});
 }
 host.ZION030_HARDWARE_PERF=Object.freeze({VERSION,create});
})(window);
