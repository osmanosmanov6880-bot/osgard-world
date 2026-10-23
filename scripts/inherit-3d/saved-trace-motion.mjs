/* INHERIT R20 — cinematic micro-motion for the ACTUAL stored objects.
 * Cosmetic-only. Never modifies the canonical game snapshot or spends budget.
 * A bounded subset animates; rigid ruins/stone paths remain rigid. Supports
 * paused animation for reduced motion, invisible tabs and efficiency mode.
 */
const TYPES=new Set(['tree','light','flower','chime']);
export function makeSavedTraceMotion({maxAnimated=48}={}){
 const animated=[],activeLights=[];
 let frames=0,lastSeason='tide';
 const max=Math.max(0,Math.min(96,Math.floor(maxAnimated)));
 function bind(objects=[]){
  animated.length=0;activeLights.length=0;
  for(const g of objects){
   const tool=g?.userData?.nativeTrace?.tool;
   if(!TYPES.has(tool)||animated.length>=max)continue;
   // The parent rotation is reset when a true save or generation is restored.
   const baseZ=g.rotation?.z||0;
   const phase=(animated.length+1)*2.399963+Number(g.userData.nativeTrace.x||0)*.17;
   let lamp=null,defaultLight=0;
   if(tool==='light'&&typeof g.traverse==='function'){
    g.traverse(child=>{
     if(!lamp&&child?.isPointLight){lamp=child;defaultLight=child.intensity;}
    });
    if(lamp&&activeLights.length<3)activeLights.push({lamp,base:defaultLight,phase});
    else lamp=null;
   }
   animated.push({group:g,tool,baseZ,phase});
  }
  return animated.length;
 }
 function update(time=0,season='tide',reducedMotion=false){
  lastSeason=season;
  const seconds=Number.isFinite(time)?time*.001:0;
  const gust=season==='wind'?1.45:season==='mist'?.24:season==='sun'?.41:.74;
  for(const a of animated){
   if(!a.group?.parent)continue;
   const amplitude=a.tool==='chime'?.032:a.tool==='flower'?.022:a.tool==='tree'?.010:0;
   a.group.rotation.z=a.baseZ+
     (reducedMotion?0:amplitude*gust*Math.sin(seconds*.76+a.phase)+
       amplitude*gust*.18*Math.sin(seconds*2.12+a.phase*.7));
  }
  for(const light of activeLights){
   if(!light.lamp?.parent)continue;
   // Flicker only genuine saved torches. Deterministic and restrained.
   const drift=.95+.04*Math.sin(seconds*3.1+light.phase)+
    .022*Math.sin(seconds*7.7+light.phase*2);
   light.lamp.intensity=light.base*(reducedMotion?1:drift);
  }
  frames++;
 }
 function restore(){
  for(const a of animated)if(a.group?.rotation)a.group.rotation.z=a.baseZ;
  for(const l of activeLights)if(l.lamp)l.lamp.intensity=l.base;
 }
 return Object.freeze({
  bind,update,restore,
  stats:()=>Object.freeze({animated: animated.length,lights:activeLights.length,
   frames,season:lastSeason,gameplayWrites:0})
 });
}
