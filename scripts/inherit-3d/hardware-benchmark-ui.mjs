/* INHERIT R18 — explicit browser/device performance test.
 * A manual ten-second rendering benchmark; never uploads a byte, changes
 * the player's world, saves adapter details or invents a "GPU fps" number.
 */
import {makeHardwareBenchmark,makeGpuQueryTimer,computeHardwareReport,fixedStats} from './hardware-benchmark.mjs';
const LABELS={
 ru:{start:'Тест FPS · 10 с',cancel:'Остановить тест',copy:'Копировать отчёт',
  running:'Измеряется фактическое время кадров на этом устройстве…',
  done:'Проверка завершена',cancelled:'Проверка прервана',
  notAvailable:'Включите 3D и анимации для измерения',copied:'Отчёт скопирован',
  elapsed:'Замер',p95:'95% кадров',cpu:'CPU',gpu:'GPU',draws:'вызовов',caution:'Нет отправки на сервер. Видеокарта не подтверждена внешней проверкой.'},
 en:{start:'Test FPS · 10s',cancel:'Stop test',copy:'Copy report',
  running:'Measuring actual frame times on this device…',
  done:'Benchmark completed',cancelled:'Benchmark interrupted',
  notAvailable:'Enable 3D and animation to measure',copied:'Report copied',
  elapsed:'Measurement',p95:'95% frames',cpu:'CPU',gpu:'GPU',draws:'draw calls',
  caution:'No upload. Physical GPU identity is not independently verified.'},
 zh:{start:'FPS 测试 · 10 秒',cancel:'停止测试',copy:'复制报告',
  running:'正在测量此设备真实帧时间…',done:'测量完成',cancelled:'测量已中断',
  notAvailable:'请先开启3D与动画',copied:'报告已复制',
  elapsed:'测量',p95:'95%帧',cpu:'CPU',gpu:'GPU',draws:'绘制调用',
  caution:'不会上传；物理显卡身份未经独立核验。'}
};
const ADVICE={
 ru:{'keep-tested-tier':'Выбранное качество подходит','try-balanced':'Попробуйте режим «Баланс» и повторите тест','try-efficient':'Попробуйте режим «Экономия» и повторите тест','reduce-resolution':'Уменьшите разрешение или включите 2D','try-next-tier-and-retest':'Можно проверить более высокое качество повторным тестом','repeat-valid-test':'Для оценки нужен полный тест 10 секунд'},
 en:{'keep-tested-tier':'Keep the tested quality','try-balanced':'Try Balanced and retest','try-efficient':'Try Efficient and retest','reduce-resolution':'Lower resolution or use 2D','try-next-tier-and-retest':'Try the next quality tier and retest','repeat-valid-test':'Run a complete 10-second test'},
 zh:{'keep-tested-tier':'保持当前画质','try-balanced':'尝试均衡画质并重新测试','try-efficient':'尝试节能画质并重新测试','reduce-resolution':'降低分辨率或切换2D','try-next-tier-and-retest':'可以测试更高画质','repeat-valid-test':'请完成完整10秒测试'}
};
const adviceFor=(language,key)=>ADVICE[language]?.[key]||ADVICE.ru[key]||key;
const fmt=(x,d=1)=>Number.isFinite(x)?Number(x).toFixed(d):'—';
export function mountHardwareBenchmark({
 controls,renderer,camera,quality,postFX,viewport,adapter,
 active,reducedMotion,busy,requestFrame,notify,localize=()=>document.documentElement.lang?.slice(0,2)
}){
 const d=controls.ownerDocument,t=()=>LABELS[localize()]||LABELS.ru;
 const button=d.createElement('button'),copy=d.createElement('button'),result=d.createElement('output');
 button.type=copy.type='button';button.className='aaa3d-benchmark';
 copy.className='aaa3d-benchmark-copy';copy.hidden=true;result.className='aaa3d-benchmark-result';
 result.setAttribute('aria-live','polite');result.setAttribute('role','status');result.hidden=true;
 controls.append(button,copy,result);
 const test=makeHardwareBenchmark({durationMs:10000,warmupMs:700});
 const timer=makeGpuQueryTimer(renderer.getContext());
 let report=null,restored=false,stopTimer=null;
 const update=()=>{
  const c=t();
  button.textContent=test.running()?c.cancel:c.start;
  button.setAttribute('aria-pressed',String(test.running()));
  button.disabled=!!reducedMotion()||(!test.running()&&(!active()||busy()));
  copy.textContent=c.copy;copy.hidden=!report;
 };
 const asText=r=>{
  const c=t();
  return [c.done,
   'FPS '+fmt(r.averageFps),
   c.p95+' '+fmt(r.frameP95Ms,2)+'ms',
   c.cpu+' '+fmt(r.cpuSubmitP95Ms,2)+'ms',
   c.gpu+' '+fmt(r.gpuP95Ms,2)+'ms',
   c.draws+' '+(r.render?.drawCalls??'—'),
   'tris '+(r.render?.triangles??'—'),
   r.qualityTested.toUpperCase(),r.rendererClassification,
   adviceFor(localize(),r.recommendation),c.caution].join(' · ');
 };
 const restore=()=>{
  if(!restored){
   camera.position.set(0,Math.sin(.67)*63,Math.cos(.67)*63);
   camera.lookAt(0,0,0);camera.updateMatrixWorld();restored=true;
  }
 };
 const finish=(reason='cancelled',already=null)=>{
  if(stopTimer!==null){clearTimeout(stopTimer);stopTimer=null;}
  if(!test.running()&&!already)return report;
  report=already||test.stop(performance.now(),reason);
  restore();
  result.hidden=false;result.textContent=asText(report);
  notify(reason==='complete'?t().done:t().cancelled);
  update();requestFrame();
  return report;
 };
 const begin=(options={})=>{
  if(test.running()||!active()||reducedMotion()||busy())return false;
  const duration=Number.isFinite(options.durationMs)?Math.max(1000,Math.min(15000,options.durationMs)):10000;
  // API diagnostics may be short; reports with fewer than 45 intervals remain
  // inconclusive. The visible button always runs a real ten-second sample.
  const optionsBench={quality:quality(),postFX:postFX(),
   pixelRatio:renderer.getPixelRatio(),viewport:viewport(),adapter,
   gpuTimerAvailable:timer.supported()};
  test.start(performance.now(),optionsBench);
  // Software WebGL can stall frames for seconds. An independently scheduled
  // monotonic deadline ensures a test always terminates, even if no rAF
  // callback completes. Sparse actual samples remain INCONCLUSIVE, never
  // fabricated as a valid GPU score. The timer never alters saved gameplay.
  if(stopTimer!==null)clearTimeout(stopTimer);
  stopTimer=setTimeout(()=>{
   if(test.running())finish(duration<10000?'diagnostic':'complete');
  },duration+110);
  report=null;restored=false;
  result.hidden=false;result.textContent=t().running;
  update();requestFrame();return {durationMs:duration,started:true};
 };
 // Requested durations shorter than the default are used exclusively by
 // diagnostic automation and cannot be presented as the ten-second public QA.
 let customDuration=10000;
 const start=(opts={})=>{
  const ans=begin(opts);
  if(ans)customDuration=ans.durationMs;
  return !!ans;
 };
 function startFrame(now){
  if(!test.running())return;
  for(const value of timer.poll())test.addGpuTime(value);
  timer.begin();
 }
 function endFrame(now,submitMs){
  if(!test.running())return;
  timer.end();
  for(const value of timer.poll())test.addGpuTime(value);
  const data=test.record(now,submitMs,fixedStats(renderer));
  if(data){finish('complete',data);return;}
  const state=test.state();
  // A diagnostic shorter than the default closes at its requested interval.
  // The report becomes inconclusive if too few actual frames were observed.
  if(customDuration<10000&&test.progress(now)>=customDuration/10000)
   finish('diagnostic');
 }
 function moveCamera(now){
  if(!test.running())return false;
  const progress=Math.min(1,test.progress(now)*(10000/customDuration)),a=progress*2*Math.PI;
  camera.position.set(Math.sin(a)*17,38,47+Math.cos(a)*8);
  camera.lookAt(0,0,0);
  return true;
 }
 button.addEventListener('click',()=>test.running()?finish('cancelled'):start());
 copy.addEventListener('click',()=>{
  if(!report)return;
  // No raw GPU model/driver information is included in the copied report.
  navigator.clipboard?.writeText(JSON.stringify(report,null,2))
   .then(()=>notify(t().copied)).catch(()=>{});
 });
 d.addEventListener('visibilitychange',()=>{if(d.hidden&&test.running())finish('tab-hidden')});
 update();
 return Object.freeze({
  running:test.running,start,startFrame,endFrame,moveCamera,
  finish,report:()=>report,update,
  dispose:()=>{finish('cancelled');if(stopTimer!==null)clearTimeout(stopTimer);timer.dispose();button.remove();copy.remove();result.remove();}
 });
}
