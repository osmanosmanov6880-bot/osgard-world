(() => {
 'use strict';
 const key='osgard:portal-navigation:v2';
 const normalize=p=>p.replace(/\/+$/,'')||'/';
 const profile=p=>{p=normalize(p);if(p==='/play/partners')return 'world';if(p==='/intelligence'||p==='/academy'||p==='/osa-cinema'||p.startsWith('/learning')||p.startsWith('/lectures')||p.startsWith('/osa-library'))return 'intelligence';if(p==='/play'||p.startsWith('/play/')||p==='/entertainment'||p.startsWith('/games'))return 'play';return 'world'};
 const name={world:'OSGARD WORLD',intelligence:'OSA INTELLIGENCE',play:'OSGARD PLAY'};
 const current=profile(location.pathname);document.documentElement.dataset.product=current;
 const reduced=()=>matchMedia('(prefers-reduced-motion: reduce)').matches||document.documentElement.dataset.motion==='off';
 try{document.documentElement.dataset.motion=localStorage.getItem('osgard:motion')==='off'?'off':'on'}catch{}
 document.addEventListener('click',e=>{
  if(e.defaultPrevented||e.button!==0||e.metaKey||e.ctrlKey||e.shiftKey||e.altKey)return;
  const a=e.target instanceof Element?e.target.closest('a[href]'):null;
  if(!a||a.hasAttribute('download')||(a.target&&a.target!=='_self')||a.relList.contains('external')||reduced())return;
  let to;try{to=new URL(a.href,location.href)}catch{return}
  if(to.origin!==location.origin||!['http:','https:'].includes(to.protocol)||normalize(to.pathname)===normalize(location.pathname))return;
  const target=profile(to.pathname);if(current===target&&!a.hasAttribute('data-game-launch'))return;
  try{sessionStorage.setItem(key,JSON.stringify({path:normalize(to.pathname),theme:target,game:a.hasAttribute('data-game-launch'),at:Date.now()}))}catch{}
  // Navigation is never prevented or delayed for the effect.
 },true);
 let pending;try{pending=JSON.parse(sessionStorage.getItem(key)||'null');sessionStorage.removeItem(key)}catch{return}
 if(!pending||pending.path!==normalize(location.pathname)||!Number.isFinite(pending.at)||Date.now()-pending.at>5000||!name[pending.theme]||reduced())return;
 let mounted=false,observer;
 const mount=()=>{if(mounted||!document.body||reduced())return;const root=document.getElementById('root');if(root&&!root.childElementCount)return;mounted=true;
 const overlay=document.createElement('div');overlay.className='osa5-transition-overlay osgard-portal-transition portal-'+pending.theme+(pending.game?' portal-game':'');overlay.setAttribute('aria-hidden','true');
 const image=document.createElement('img');image.src='/brand/portal-'+pending.theme+'.svg';image.alt='';
 const label=document.createElement('span');label.textContent=name[pending.theme];overlay.append(image,label);document.body.append(overlay);
 requestAnimationFrame(()=>requestAnimationFrame(()=>overlay.classList.add('portal-reveal')));setTimeout(()=>overlay.remove(),520);observer?.disconnect();
 };
 const root=document.getElementById('root');if(root){observer=new MutationObserver(mount);observer.observe(root,{childList:true,subtree:true})}
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',mount,{once:true});else mount();setTimeout(()=>{mount();observer?.disconnect()},2000);
})();
