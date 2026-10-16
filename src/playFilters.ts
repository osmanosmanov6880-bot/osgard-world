export type PlayFilters={query:string;genre:string;mode:'all'|'solo'|'service';view:'all'|'favorites'|'recent'}
export function readPlayFilters(search:string,genres:readonly string[]):PlayFilters{
 const p=new URLSearchParams(search),mode=p.get('mode'),view=p.get('view'),genre=p.get('genre')
 return {query:(p.get('q')||'').slice(0,80),genre:genre&&genres.includes(genre)?genre:'all',mode:mode==='solo'||mode==='service'?mode:'all',view:view==='favorites'||view==='recent'?view:'all'}
}
export function playCatalogHref(filters:PlayFilters){
 const p=new URLSearchParams();if(filters.query.trim())p.set('q',filters.query.trim().slice(0,80));if(filters.genre!=='all')p.set('genre',filters.genre);if(filters.mode!=='all')p.set('mode',filters.mode);if(filters.view!=='all')p.set('view',filters.view)
 const query=p.toString();return '/play'+(query?'?'+query:'')+'#catalog'
}
export function playWorldHref(id:string,filters:PlayFilters){return '/play/world/'+encodeURIComponent(id)+'?back='+encodeURIComponent(playCatalogHref(filters))}
export function playReturnHref(search:string,genres:readonly string[]){
 try{const value=new URLSearchParams(search).get('back');if(!value)return '/play#catalog';const u=new URL(value,'https://osgard.local');if(u.origin!=='https://osgard.local'||!['/play','/play/','/games','/games/','/entertainment','/entertainment/'].includes(u.pathname))return '/play#catalog';return playCatalogHref(readPlayFilters(u.search,genres))}catch{return '/play#catalog'}
}
