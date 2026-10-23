/* ZION-030 v40 / actual paid digital cosmetic shop.
 * All amounts, ownership, refunds and entitlement decisions live on the
 * server. Query params and local storage NEVER grant purchased cosmetics.
 */
(function(host){
'use strict';
const VERSION='40.0', TOKEN='osgard:core-session:v1';
const EQUIP='osgard:zion030:cosmetic-selection:v1';
const categories={car_onyx:'vehicle',car_aurora:'vehicle',
  suit_copper:'avatar',city_afterglow:'environment'};
const colors={car_onyx:0x151b22,car_aurora:0x64d2ee,
  suit_copper:0xa46a4b,city_afterglow:0x98e9ff};
const money=(cents,currency)=>{
  try{return new Intl.NumberFormat('ru-RU',
    {style:'currency',currency}).format(cents/100);}
  catch(_){return String(cents/100)+' '+currency;}
};
function mount({shell,getCar,getAvatar,getLamps}={}){
 if(!shell?.querySelector||shell.querySelector('#oc-store-dialog'))return null;
 const button=document.createElement('button');
 button.id='oc-store-button';button.className='oc-glass oc-store-entry';
 button.type='button';button.textContent='◈ МАГАЗИН';
 button.setAttribute('aria-haspopup','dialog');
 button.setAttribute('aria-controls','oc-store-dialog');
 const topbar=shell.querySelector('.oc-top-right');
 const exit=shell.querySelector('#oc-exit');
 if(topbar&&exit)topbar.insertBefore(button,exit);else shell.append(button);
 const dialog=document.createElement('section');
 dialog.id='oc-store-dialog';dialog.className='oc-store-dialog';
 dialog.setAttribute('role','dialog');dialog.setAttribute('aria-modal','true');
 dialog.setAttribute('aria-label','Магазин внешнего вида ZION');
 dialog.hidden=true;
 dialog.innerHTML=
 '<div class="oc-store-panel">'+
 '<header class="oc-store-top"><div><small>ZION // OPEN CITY</small>'+
 '<h2>ATELIER <em>STORE</em></h2><p>Внешний вид без преимущества в миссиях.</p></div>'+
 '<button class="oc-store-close" type="button" aria-label="Закрыть магазин">✕</button></header>'+
 '<p class="oc-store-banner" role="status" aria-live="polite"></p>'+
 '<div class="oc-store-items" aria-label="Каталог платных обликов"></div>'+
 '<form class="oc-store-login" hidden><h3>Войти в OSGARD</h3>'+
 '<p>Покупки закрепляются за аккаунтом, а не браузером.</p>'+
 '<label>Логин<input name="username" required autocomplete="username" minlength="3"></label>'+
 '<label>Пароль<input name="password" required type="password" minlength="12" autocomplete="current-password"></label>'+
 '<div class="oc-store-actions"><button type="submit">ВОЙТИ</button>'+
 '<a href="/workspace">Создать аккаунт</a></div></form>'+
 '<footer class="oc-store-bottom"><button type="button" class="oc-store-refresh">↻ ОБНОВИТЬ ПОКУПКИ</button>'+
 '<small>Оплата через Stripe. Доступ после подтверждения сервера. Возвраты — через поддержку. '+
 '<a href="/terms/" target="_blank" rel="noopener noreferrer">Условия</a> · '+
 '<a href="/privacy/" target="_blank" rel="noopener noreferrer">Конфиденциальность</a></small></footer>'+
 '</div>';
 shell.append(dialog);
 const $=selector=>dialog.querySelector(selector);
 const banner=$('.oc-store-banner'),grid=$('.oc-store-items'),form=$('.oc-store-login');
 const state={version:VERSION,loaded:false,enabled:false,mode:'test',
   authenticated:false,items:0,owned:[],applied:{vehicle:null,avatar:null,environment:null}};
 let catalog=[],owned=new Set(),busy=false,disposed=false;
 let selected={vehicle:null,avatar:null,environment:null};
 const originals=new Map();
 try{
   const saved=JSON.parse(localStorage.getItem(EQUIP)||'null');
   if(saved&&typeof saved==='object')
     for(const key of Object.keys(selected))
       if(typeof saved[key]==='string'&&categories[saved[key]]===key)
         selected[key]=saved[key];
 }catch(_){}
 const token=()=>{try{return sessionStorage.getItem(TOKEN)||'';}catch(_){return '';}};
 const message=(text,kind='info')=>{banner.textContent=text;banner.dataset.kind=kind;};
 async function request(route,body,authenticated=false){
   const ac=new AbortController(),timer=setTimeout(()=>ac.abort(),15000);
   try{
     const response=await fetch('/api/core/'+route,{
       method:body?'POST':'GET',credentials:'omit',cache:'no-store',
       headers:{Accept:'application/json',...(body?{'Content-Type':'application/json'}:{}),
         ...(authenticated&&token()?{Authorization:'Bearer '+token()}:{})},
       body:body?JSON.stringify(body):undefined,signal:ac.signal
     });
     if(!(response.headers.get('content-type')||'').includes('application/json'))
       throw Error('На этом сайте не подключён платёжный сервер.');
     const result=await response.json();
     if(!response.ok)throw Error(result.message||'Сервер отклонил операцию.');
     return result;
   }finally{clearTimeout(timer);}
 }
 function tint(material,color,metal=false){
   if(!material?.color?.clone||!material.color.setHex)return;
   if(!originals.has(material))
     originals.set(material,{color:material.color.clone(),
       roughness:material.roughness,metalness:material.metalness});
   const before=originals.get(material);
   if(color==null){
     material.color.copy(before.color);
     if(before.roughness!==undefined)material.roughness=before.roughness;
     if(before.metalness!==undefined)material.metalness=before.metalness;
   }else{
     material.color.setHex(color);
     if(metal){material.roughness=.20;material.metalness=.68;}
   }
   material.needsUpdate=true;
 }
 function apply(){
   // "selected" is only user preference, not purchase evidence.
   // Every cosmetic is gated by signed server inventory loaded via Bearer auth.
   const vehicle=owned.has(selected.vehicle)?selected.vehicle:null;
   const avatar=owned.has(selected.avatar)?selected.avatar:null;
   const environment=owned.has(selected.environment)?selected.environment:null;
   const car=getCar?.()?.mesh;
   if(car?.children?.[0]?.material)
     tint(car.children[0].material,vehicle?colors[vehicle]:null,true);
   const hero=getAvatar?.();
   if(hero?.children?.[0]?.material)
     tint(hero.children[0].material,avatar?colors[avatar]:null);
   for(const lamp of getLamps?.()||[]){
     const bulb=lamp?.children?.find(x=>x?.isMesh&&x?.geometry?.type==='SphereGeometry');
     if(bulb?.material)tint(bulb.material,environment?colors[environment]:null);
   }
   state.applied={vehicle,avatar,environment};
   return {...state.applied};
 }
 function equip(sku){
   if(!owned.has(sku)||!categories[sku])return false;
   const kind=categories[sku];
   selected[kind]=selected[kind]===sku?null:sku;
   try{localStorage.setItem(EQUIP,JSON.stringify(selected));}catch(_){}
   apply();render();
   message('Облик изменён. Миссии и характеристики остались прежними.','success');
   return true;
 }
 const elt=(tag,value)=>{
   const e=document.createElement(tag);
   if(value!==undefined)e.textContent=value;
   return e;
 };
 function render(){
   grid.replaceChildren();
   state.items=catalog.length;
   for(const item of catalog){
     const card=elt('article');card.className='oc-store-product';
     const header=elt('div');header.className='oc-store-product-heading';
     const symbol=elt('span',item.category==='vehicle'?'🚘':
       item.category==='avatar'?'◈':item.category==='environment'?'✧':'✦');
     symbol.className='oc-store-product-icon';
     header.append(symbol,elt('h3',item.name));
     const desc=elt('p',item.description);
     const price=elt('strong',money(item.amountMinor,item.currency));
     price.className='oc-store-price';
     const action=elt('button');action.type='button';
     const has=owned.has(item.sku),kind=categories[item.sku];
     if(has){
       action.textContent=kind?(selected[kind]===item.sku?'✓ ВЫБРАНО':'ПРИМЕНИТЬ'):
         '✓ КОЛЛЕКЦИЯ ПРИОБРЕТЕНА';
       action.disabled=!kind||busy;
       if(kind)action.addEventListener('click',()=>equip(item.sku));
     }else{
       action.textContent=!state.enabled?'СКОРО В ПРОДАЖЕ':
         state.mode==='test'?'ТЕСТОВАЯ ПОКУПКА':'КУПИТЬ';
       action.disabled=!state.enabled||busy;
       action.addEventListener('click',()=>void buy(item.sku));
     }
     card.append(header,desc,price,action);grid.append(card);
   }
   form.hidden=dialog.hidden||!state.enabled||state.authenticated;
   button.setAttribute('aria-expanded',String(!dialog.hidden));
 }
 async function refresh(){
   if(disposed)return;
   try{
     const shop=await request('game/store');
     state.loaded=true;state.enabled=shop.enabled===true;
     state.mode=shop.mode==='live'?'live':'test';
     catalog=Array.isArray(shop.products)?shop.products.filter(p=>
       p&&typeof p.sku==='string'&&Number.isInteger(p.amountMinor)&&
       p.amountMinor>0&&p.currency==='EUR'):[];
     owned.clear();state.authenticated=false;
     if(token()){
       try{
         const result=await request('game/inventory',undefined,true);
         const available=new Set(catalog.map(p=>p.sku));
         owned=new Set((result.owned||[]).filter(id=>available.has(id)));
         state.authenticated=true;
       }catch(err){
         if(/сессия|войдите|unauthorized/i.test(err.message||''))
           try{sessionStorage.removeItem(TOKEN);}catch(_){}
       }
     }
     state.owned=[...owned];
     for(const type of Object.keys(selected))
       if(!owned.has(selected[type]))selected[type]=null;
     apply();render();
     if(!state.enabled)
       message('Платежи пока выключены оператором. Сюжет полностью бесплатный.','warning');
     else if(state.mode==='test')
       message('SANDBOX · тестовая оплата. Деньги НЕ списываются.','warning');
     else if(!state.authenticated)
       message('Войдите в OSGARD, чтобы сохранить купленные предметы.');
     else if(new URLSearchParams(location.search).get('checkout')==='returned')
       message('Вы вернулись из Stripe. Ждём webhook — нажмите «Обновить покупки».');
     else message('Ваши покупки подтверждены сервером.','success');
   }catch(_){
     state.loaded=false;state.enabled=false;state.authenticated=false;
     owned.clear();state.owned=[];apply();render();
     message('Платёжный сервер недоступен. Покупки отключены.','warning');
   }
 }
 async function buy(sku){
   if(busy||!state.enabled||owned.has(sku)||!catalog.some(x=>x.sku===sku))return;
   if(!token()){
     message('Для оплаты сначала войдите в OSGARD.','warning');
     form.hidden=false;form.querySelector('[name="username"]')?.focus();return;
   }
   busy=true;render();message('Создаём защищённую страницу Stripe Checkout…');
   try{
     const checkout=await request('game/checkout',{sku},true);
     if(checkout.alreadyOwned){await refresh();return;}
     const u=new URL(checkout.url);
     if(u.protocol!=='https:'||u.hostname!=='checkout.stripe.com')
       throw Error('Сервер вернул недопустимую платёжную ссылку.');
     window.location.assign(u.href);
   }catch(err){message(err.message||'Не удалось создать заказ.','warning');}
   finally{busy=false;render();}
 }
 form.addEventListener('submit',async event=>{
   event.preventDefault();if(busy||!state.enabled)return;
   const username=String(form.elements.namedItem('username')?.value||'').trim();
   const password=String(form.elements.namedItem('password')?.value||'');
   busy=true;render();
   try{
     const login=await request('auth/login',{username,password});
     if(typeof login.token!=='string')throw Error('Сессия не получена.');
     try{sessionStorage.setItem(TOKEN,login.token);}
     catch(_){throw Error('Разрешите временное хранение сессии в браузере.');}
     form.reset();await refresh();
   }catch(err){message(err.message||'Ошибка входа.','warning');}
   finally{busy=false;render();}
 });
 function close(){
   dialog.hidden=true;shell.dataset.storeOpen='false';render();
   button.focus({preventScroll:true});
 }
 function open(){
   dialog.hidden=false;shell.dataset.storeOpen='true';render();
   $('.oc-store-close').focus({preventScroll:true});
   void refresh();
 }
 button.addEventListener('click',open);
 $('.oc-store-close').addEventListener('click',close);
 $('.oc-store-refresh').addEventListener('click',()=>void refresh());
 dialog.addEventListener('keydown',e=>{
   if(e.key==='Escape'){e.preventDefault();e.stopPropagation();close();}
 });
 dialog.addEventListener('click',e=>{if(e.target===dialog)close();});
 void refresh();
 return Object.freeze({version:VERSION,open,close,refresh,equip,apply,
   get state(){return Object.freeze({...state,owned:[...state.owned],
     applied:{...state.applied}});},
   dispose(){
     disposed=true;close();button.remove();dialog.remove();
     for(const [material,old] of originals){
       material.color?.copy?.(old.color);
       if(old.roughness!==undefined)material.roughness=old.roughness;
       if(old.metalness!==undefined)material.metalness=old.metalness;
     }
     originals.clear();
   }
 });
}
host.ZION030_STORE40=Object.freeze({VERSION,mount});
})(window);
