export const PLAY_COLLECTION_KEY='osgard:play-collection:v1'
export type PlayCollection={favorites:string[];recent:string[]}
export const emptyPlayCollection=():PlayCollection=>({favorites:[],recent:[]})
export function parsePlayCollection(raw:string,validIds:readonly string[]):PlayCollection{
 if(raw.length>10000)throw Error('size')
 const p=JSON.parse(raw)
 if(!p||!Array.isArray(p.favorites)||!Array.isArray(p.recent))throw Error('format')
 const clean=(v:unknown[])=>[...new Set(v.filter((x):x is string=>typeof x==='string'&&validIds.includes(x)))].slice(0,20)
 return {favorites:clean(p.favorites),recent:clean(p.recent)}
}
export function visitGame(p:PlayCollection,id:string):PlayCollection{return {...p,recent:[id,...p.recent.filter(v=>v!==id)].slice(0,20)}}
export function toggleFavorite(p:PlayCollection,id:string):PlayCollection{return {...p,favorites:p.favorites.includes(id)?p.favorites.filter(v=>v!==id):[...p.favorites,id]}}
