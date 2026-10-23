/* ZION-030 v33 / optional cinema HUD. No change to gameplay or mission rules. */
(function(){
  'use strict';
  const shell=document.getElementById('oc-shell');
  const header=shell?.querySelector('.oc-top-right');
  if(!shell||!header||document.getElementById('oc-focus-switch'))return;
  const button=document.createElement('button');
  button.id='oc-focus-switch';button.type='button';
  button.className='oc-glass oc-focus-switch';
  button.setAttribute('aria-label','Переключить кинематографичный интерфейс');
  button.setAttribute('aria-keyshortcuts','H');
  button.title='Киноинтерфейс: убирает второстепенные панели, клавиша H';
  header.insertBefore(button,header.lastElementChild);
  const storageKey='osgard:zion030:cinematic-hud:v1';
  let focused=false;
  function apply(value){
    focused=Boolean(value);
    shell.classList.toggle('oc-focus',focused);
    button.setAttribute('aria-pressed',String(focused));
    button.textContent=focused?'◈ HUD':'◉ КИНО';
    button.title=focused?'Показать весь HUD (H)':'Кинематографичный интерфейс (H)';
  }
  let saved=false;
  try{saved=localStorage.getItem(storageKey)==='1';}catch(_){}
  apply(saved);
  function toggle(){
    apply(!focused);
    try{localStorage.setItem(storageKey,focused?'1':'0');}catch(_){}
  }
  button.addEventListener('click',toggle);
  window.addEventListener('keydown',event=>{
    if(event.code!=='KeyH'||event.ctrlKey||event.altKey||event.metaKey||
      shell.hidden||event.repeat)return;
    if(event.target?.matches?.('input,textarea,[contenteditable]'))return;
    if(!document.getElementById('oc-journal')?.hidden||
       !document.getElementById('oc-pause')?.hidden)return;
    event.preventDefault();toggle();
  });
  window.__ZION030_FOCUS_HUD__=Object.freeze({
    state:()=>focused,
    set:value=>apply(value),
    toggle
  });
})();
