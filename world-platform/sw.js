/* W76 optional secure-context local caching. Game is cached ONLY after explicit
   user action + SHA-256 verification of each actual Godot binary. No APIs. */
const VERSION="lf-world-v76-73ef81b5";
const SHELL=VERSION+"-shell";
const GAME=VERSION+"-game";
const SHELL_FILES=[
  "./","./index.html","./styles.css","./core.mjs","./app.mjs",
  "./icon.svg","./manifest.webmanifest","./release-manifest.json"
];
const SHA_PATTERN=/^[a-f0-9]{64}$/;
self.addEventListener("install",(event)=>{
  event.waitUntil((async()=>{
    const cache=await caches.open(SHELL);
    await cache.addAll(SHELL_FILES);
    await self.skipWaiting();
  })());
});
self.addEventListener("activate",(event)=>{
  event.waitUntil((async()=>{
    for(const key of await caches.keys()){
      if(key.startsWith("lf-world-v")&&key!==SHELL&&key!==GAME)
        await caches.delete(key);
    }
    await self.clients.claim();
  })());
});
self.addEventListener("fetch",(event)=>{
  const request=event.request;
  if(request.method!=="GET")return;
  const url=new URL(request.url);
  if(url.origin!==self.location.origin||!url.pathname.startsWith(new URL(self.registration.scope).pathname))return;
  event.respondWith((async()=>{
    const matched=await caches.match(request,{ignoreSearch:true});
    if(matched)return matched;
    return fetch(request);
  })());
});
self.addEventListener("message",(event)=>{
  if(event.data?.type!=="CACHE_GAME")return;
  const port=event.ports?.[0];
  if(!port)return;
  event.waitUntil((async()=>{
    const files=event.data.files;
    if(!Array.isArray(files)||files.length<8||files.length>24)
      throw new Error("Invalid verified original game file list");
    const game=await caches.open(GAME);
    try{
      for(let i=0;i<files.length;i++){
        const file=files[i];
        if(!file||!/^game\/index\.[a-zA-Z0-9.-]+$/.test(file.path)||
          !SHA_PATTERN.test(file.sha256)||!Number.isInteger(file.bytes)||
          file.bytes<1||file.bytes>95_000_000)
          throw new Error("Unsafe game file or hash");
        const target=new URL("./"+file.path,self.registration.scope);
        if(target.origin!==self.location.origin)throw new Error("External cache request refused");
        const response=await fetch(target.toString(),{cache:"no-store"});
        if(!response.ok)throw new Error("Game HTTP "+response.status);
        const bytes=await response.arrayBuffer();
        if(bytes.byteLength!==file.bytes)throw new Error("Game length mismatch");
        const digest=Array.from(new Uint8Array(
          await crypto.subtle.digest("SHA-256",bytes)),
          b=>b.toString(16).padStart(2,"0")).join("");
        if(digest!==file.sha256)throw new Error("Game integrity mismatch: "+file.path);
        const headers=new Headers(response.headers);
        headers.set("Content-Length",String(bytes.byteLength));
        await game.put(target,new Response(bytes,{status:200,headers}));
        port.postMessage({type:"PROGRESS",done:i+1,total:files.length});
      }
      port.postMessage({type:"DONE",total:files.length});
    }catch(error){
      await caches.delete(GAME);
      port.postMessage({type:"ERROR",message:String(error.message||error)});
    }finally{port.close();}
  })());
});
