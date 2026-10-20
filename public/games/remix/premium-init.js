/* Non-invasive premium enhancement: server match code remains authoritative. */
(()=>{
"use strict";
document.body.classList.add("remix-premium");
const hero=document.querySelector(".hero");
if(hero){
 const orb=document.createElement("div");orb.className="rx-orb";orb.setAttribute("aria-hidden","true");
 orb.innerHTML='<div class="rx-orb-core"></div><div class="rx-orb-ring"></div><div class="rx-orb-ring"></div><div class="rx-orb-glint"></div>';
 hero.prepend(orb);
}
const consolePanel=document.getElementById("live-growth-console");
if(consolePanel){
 const note=document.createElement("div");note.className="rx-service-note";
 note.innerHTML='<span data-i18n-ru="Официальный онлайн-матч — отдельный режим. Для подтверждения результата нужен действующий сервер REMIX. Локальная тренировка выше не отправляет очки на сервер." data-i18n-en="Official online matches are a separate mode. REMIX service availability is required for verified results. The practice arena above never submits scores to the server." data-i18n-zh="正式在线比赛为独立模式。只有 REMIX 服务器可以确认比赛成绩。上方本地训练场不会向服务器提交分数。"></span>';
 consolePanel.insertAdjacentElement("beforebegin",note);
 const arena=consolePanel.querySelector("#arena");
 if(arena){
  const paint=()=>{
   const c=arena.getContext("2d");if(!c)return;
   // Overlay is decorative only; never reads or changes match state.
   c.save();const w=arena.width,h=arena.height;
   const grad=c.createLinearGradient(0,0,w,h);grad.addColorStop(0,"#132e5619");grad.addColorStop(1,"#b2526a08");c.fillStyle=grad;c.fillRect(0,0,w,h);
   c.fillStyle="#f1c682a0";c.font="7px monospace";c.fillText("REMIX / SERVER COORDINATE PROJECTION",9,11);c.restore();
  };
  const original=window.requestAnimationFrame; if(typeof original==="function")original(paint);
 }
}
function update(){
 const locale=window.RemixUI?.getLanguage?.()||"ru";
 document.querySelectorAll(".rx-service-note [data-i18n-ru]").forEach(n=>n.textContent=n.getAttribute("data-i18n-"+(locale==="zh"?"zh":locale==="en"?"en":"ru")));
}
update();
window.addEventListener("remix:language",update);
})();