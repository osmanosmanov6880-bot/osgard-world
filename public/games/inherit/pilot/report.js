/* INHERIT pilot console: manually selected voluntary exports are processed
   in tab memory only; this module performs no external submission. */
import {aggregate,formatMarkdown} from '../pilot-metrics.js';
const d=document,form=d.querySelector('#pilot-form'),files=d.querySelector('#files'),
 date=d.querySelector('#as-of'),status=d.querySelector('#status'),results=d.querySelector('#results');
const metrics=d.querySelector('#summary-metrics'),retention=d.querySelector('#retention-body'),
 funnel=d.querySelector('#funnel-body'),prices=d.querySelector('#price-body');
const outBasis=d.querySelector('#basis'),survey=d.querySelector('#survey-summary'),
 limitations=d.querySelector('#limitations');
let current=null;
date.value=new Date().toISOString().slice(0,10);
const labels={
 first_trace:'Первый настоящий след',any_trace:'Оставил хотя бы один след',
 generation_advanced_observed:'Наблюдаемый переход поколения',
 legacy_journal_opened:'Открыл журнал наследия',
 founder_preview_opened:'Изучил предварительный Founder Pass',
 cosmetic_selected:'Выбрал оформление острова',
 survey_submitted:'Ответил на добровольный опрос'};
const el=(tag,cls,content)=>{
 const node=d.createElement(tag);
 if(cls)node.className=cls;
 if(content!==undefined)node.textContent=String(content);
 return node;
};
function td(value,cls){return el('td',cls,String(value))}
function dataRow(target,cells){
 const row=el('tr');
 cells.forEach((value,i)=>row.appendChild(td(value,i?'num':'')));
 target.appendChild(row);
}
const percent=value=>value==null?'н/д':value.toFixed(1).replace(/\.0$/,'')+'%';
function stat(value,label){const card=el('div','metric');card.append(el('strong','',value),el('small','',label));metrics.appendChild(card)}
function render(report){
 current=report;results.hidden=false;
 const participants=report.sample.participants;
 outBasis.textContent='Данные на '+report.asOf+' UTC. Учтено '+participants+' добровольных участников. Повторных экспортов: '+
  report.sample.duplicateExports+'; отклонено: '+report.sample.rejectedExports+
  '. Это не статистика всех игроков сайта.';
 metrics.replaceChildren();
 stat(participants,'Участников с валидными отчётами');
 stat(report.funnel.first_trace.participants,'Участников, оставивших первый след');
 stat(report.funnel.generation_advanced_observed.participants,'Участников с наблюдаемой сменой поколения');
 stat(report.survey.count,'Добровольных ответов на опрос');
 stat(report.retention.d1.eligible,'Достигли срока D1');
 stat(report.retention.d7.eligible,'Достигли срока D7');
 retention.replaceChildren();funnel.replaceChildren();prices.replaceChildren();
 for(const [key,label] of [['d1','D1 · следующий день'],['d7','D7 · седьмой день']]){
  const r=report.retention[key];
  dataRow(retention,[label,r.eligible,r.returned,percent(r.ratePercent)]);
 }
 for(const [key,data] of Object.entries(report.funnel))
  dataRow(funnel,[labels[key]||key,data.participants,percent(data.ratePercent)]);
 for(const [cost,count] of Object.entries(report.survey.priceIntentionCounts)){
  const choice=cost==='0'?'Не выбрал бы платный набор':'До $'+(Number(cost)/100).toFixed(2);
  dataRow(prices,[choice,count]);
 }
 const n=x=>x==null?'н/д':x+'/5';
 survey.textContent='Ответов: '+report.survey.count+
  '. Понятность: '+n(report.survey.clarity)+
  '; желание вернуться: '+n(report.survey.returnIntent)+
  '; значимость передачи мира: '+n(report.survey.meaning)+
  '. Выбранные цены — гипотеза, не покупки.';
 limitations.textContent=report.limitations.join(' ') +
  ' Даже если процент высок, сравнивать его с обычным D1/D7 всех посетителей нельзя.';
}
form.addEventListener('submit',async event=>{
 event.preventDefault();
 current=null;results.hidden=true;
 if(!date.validity.valid||!date.value){status.textContent='Укажите корректную дату UTC.';return}
 const chosen=[...(files.files||[])];
 if(!chosen.length){status.textContent='Выберите добровольно полученные файлы JSON.';return}
 if(chosen.length>5000){status.textContent='Допускается не более 5000 отчётов за один проход.';return}
 status.textContent='Файлы обрабатываются в этом браузере. На сервер ничего не отправляется.';
 const collected=[];let invalid=0;
 for(const file of chosen){
  if(!file.name.toLowerCase().endsWith('.json')||file.size>250000||file.size===0){invalid++;continue}
  try{collected.push(JSON.parse(await file.text()))}catch{invalid++}
 }
 try{
  const report=aggregate(collected,date.value);
  report.sample.rejectedExports+=invalid;
  render(report);
  status.textContent='Сводка готова. Исходные файлы остались только в памяти этой вкладки.';
 }catch{
  status.textContent='Не удалось построить сводку. Проверьте дату и содержимое файлов.';
 }
});
function saveText(contents,mime,filename){
 if(current===null)return;
 const blob=new Blob([contents],{type:mime});
 const url=URL.createObjectURL(blob);
 const anchor=el('a');anchor.href=url;anchor.download=filename;
 anchor.hidden=true;d.body.appendChild(anchor);anchor.click();anchor.remove();
 setTimeout(()=>URL.revokeObjectURL(url),1500);
}
d.querySelector('#clear-data').addEventListener('click',()=>{
 current=null;files.value='';results.hidden=true;
 outBasis.textContent='';metrics.replaceChildren();retention.replaceChildren();
 funnel.replaceChildren();prices.replaceChildren();survey.textContent='';
 limitations.textContent='';
 status.textContent='Выбранные файлы и результаты убраны из этой вкладки. Ничего не отправлялось.';
});
d.querySelector('#save-json').addEventListener('click',()=>{
 if(current)saveText(JSON.stringify(current,null,2)+'\n','application/json','inherit-pilot-summary-'+current.asOf+'.json')
});
d.querySelector('#save-md').addEventListener('click',()=>{
 if(current)saveText(formatMarkdown(current),'text/markdown','inherit-pilot-summary-'+current.asOf+'.md')
});


// Scope the optional offline worker to INHERIT only; research files are not cached.
if('serviceWorker' in navigator){
 window.addEventListener('load',()=>{
   navigator.serviceWorker.register('/games/inherit/sw.js',{scope:'/games/inherit/'}).catch(()=>{});
 },{once:true});
}
