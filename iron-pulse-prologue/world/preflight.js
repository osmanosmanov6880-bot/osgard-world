/* IRON PULSE WORLD V14 | Local launch readiness.
   Runs only on explicit user request. No telemetry, identifiers, remote API,
   artificial gameplay data or claims of offline WebGL support. */
(() => {
  "use strict";
  const $ = id => document.getElementById(id);
  const strings = {
    ru: {
      overline:"004 / ПРОВЕРКА ПЕРЕД ЗАПУСКОМ",
      heading:"ПРОВЕРЬ СИСТЕМУ.\nЗАТЕМ ВХОДИ.",
      lead:"Проверка вашего браузера и файлов именно этой игровой сборки. Это локальная диагностика, а не тест производительности или сертификация устройства.",
      intro:"Проверка ещё не проводилась. Запусти её перед первой игрой.",
      checking:"Проверяю браузер, файлы Godot и манифест текущего выпуска…",
      ready:"Основные условия запуска выполнены. Это не гарантирует стабильный FPS на вашем устройстве.",
      limited:"Проверка обнаружила ограничения. Прочитай строки ниже; игру можно попробовать запустить вручную.",
      refresh:"ПРОВЕРИТЬ СНОВА",run:"ПРОВЕРИТЬ ИГРУ",save:"СКАЧАТЬ ОТЧЁТ",
      play:"ИГРАТЬ В ВЫБРАННУЮ ОПЕРАЦИЮ",
      webgl:"ГРАФИКА / WEBGL 2",wasm:"ИСПОЛНЕНИЕ / WEBASSEMBLY",
      files:"ИГРОВЫЕ ФАЙЛЫ / GODOT",manifest:"МАНИФЕСТ / СБОРКА",network:"СОЕДИНЕНИЕ / ПОДСКАЗКА",
      idle:"НЕ ПРОВЕРЕНО",working:"ПРОВЕРЯЕТСЯ",pass:"ДОСТУПНО",fail:"НЕ ДОСТУПНО",warn:"ВНИМАНИЕ",
      online:"Браузер сообщает о подключении. Это не гарантия доступа к серверу.",
      offline:"Браузер сообщает об отсутствии сети. Оболочка может быть доступна, но WebGL не сохраняется офлайн.",
      sha:"КОММИТ СБОРКИ",noSha:"Источник сборки не подтверждён манифестом.",
      manifestNote:"Манифест сформирован при CI-публикации. Здесь проверяется его формат и согласованность, но не независимая криптографическая подпись.",
      privacy:"Без отправки отчёта на сервер. Файл содержит только результаты этих проверок и публичный SHA исходников."
    },
    en: {
      overline:"004 / PRE-LAUNCH CHECK",
      heading:"CHECK THE SYSTEM.\nTHEN ENTER.",
      lead:"Check this browser and the game assets from this exact release. Local diagnostics are not a benchmark or hardware certification.",
      intro:"No check performed yet. Run it before your first session.",
      checking:"Checking browser support, Godot files and the release manifest…",
      ready:"Core launch requirements passed. Stable frame rates are not guaranteed on this hardware.",
      limited:"Some checks reported limitations. Review the rows below; you may still try launching the game.",
      refresh:"CHECK AGAIN",run:"CHECK MY SYSTEM",save:"DOWNLOAD REPORT",
      play:"PLAY SELECTED OPERATION",
      webgl:"GRAPHICS / WEBGL 2",wasm:"RUNTIME / WEBASSEMBLY",
      files:"GAME FILES / GODOT",manifest:"RELEASE / MANIFEST",network:"CONNECTION / ADVISORY",
      idle:"NOT CHECKED",working:"CHECKING",pass:"AVAILABLE",fail:"UNAVAILABLE",warn:"CHECK",
      online:"Browser reports online. This alone does not guarantee server reachability.",
      offline:"Browser reports offline. The portal may be cached, but the WebGL game is not cached.",
      sha:"SOURCE COMMIT",noSha:"No confirmed source commit from a release manifest.",
      manifestNote:"The CI build generated this manifest. Its format is checked here; this is not independent cryptographic signature verification.",
      privacy:"No report is sent to a server. Download contains only check results and public source SHA."
    }
  };
  const keys=["webgl","wasm","files","manifest","network"];
  const readLocale=() => document.documentElement.lang==="en" ? "en" : "ru";
  let result=null, running=false, lastSource=null;
  let language=readLocale();

  function setRow(key,state) {
    const row=$("preflight-"+key);
    if(!row) return;
    row.dataset.state=state;
    row.querySelector(".preflight-state").textContent=
      strings[language][state==="pass"?"pass":state==="fail"?"fail":state==="warn"?"warn":state==="working"?"working":"idle"];
  }

  function localize() {
    language=readLocale();
    const t=strings[language];
    for (const node of document.querySelectorAll("[data-ready-i18n]")) {
      const key=node.dataset.readyI18n;
      if(Object.prototype.hasOwnProperty.call(t,key)) node.textContent=t[key];
    }
    for (const key of keys) setRow(key,result?.checks?.[key]|| (running?"working":"idle"));
    $("preflight-status").textContent=running ? t.checking :
      !result ? t.intro : result.status==="READY" ? t.ready : t.limited;
    $("preflight-run").textContent=result ? t.refresh : t.run;
    $("preflight-commit-label").textContent=t.sha;
    $("preflight-commit").textContent=lastSource ? lastSource.slice(0,12) : t.noSha;
  }
  function sameOrigin(relative) {
    const url=new URL(relative,window.location.href);
    if(url.origin!==window.location.origin) throw new Error("cross-origin resource");
    return url;
  }
  async function request(relative,method="HEAD") {
    const controller=new AbortController();
    const timeout=setTimeout(()=>controller.abort(),8000);
    try {
      return await fetch(sameOrigin(relative),{
        method,cache:"no-store",credentials:"same-origin",redirect:"error",
        signal:controller.signal
      });
    } finally { clearTimeout(timeout); }
  }
  async function assetsAvailable() {
    // HEAD only: never fetch megabytes of WASM/PCK into the diagnostic page.
    const files=["./play/index.html","./play/index.wasm","./play/index.pck"];
    const responses=await Promise.all(files.map(path=>request(path)));
    return responses.every(response=>response.ok);
  }
  async function sourceManifest() {
    const response=await request("./assets/build-proof.json","GET");
    if(!response.ok) return null;
    const obj=await response.json();
    if(!obj || typeof obj!=="object" ||
       !/^[a-f0-9]{40}$/.test(obj.source_sha||"") ||
       obj.status!=="SOFTWARE_PREVIEW" ||
       obj.production_approved!==false ||
       obj.runtime_verified_against_export!==true ||
       Number(obj.files?.["play/index.wasm"]?.size)<=1000000) return null;
    return obj.source_sha;
  }
  async function run() {
    if(running) return result;
    running=true;result=null;lastSource=null;
    $("preflight-run").disabled=true;
    $("preflight-download").disabled=true;
    for(const key of keys) setRow(key,"working");
    localize();
    const checks={
      webgl:"fail",wasm:"fail",files:"fail",manifest:"fail",network:"warn"
    };
    try {
      checks.wasm=typeof WebAssembly==="object" && typeof WebAssembly.instantiate==="function" ? "pass":"fail";
      let gl=null;
      try {
        const canvas=document.createElement("canvas");
        gl=canvas.getContext("webgl2",{failIfMajorPerformanceCaveat:false});
        checks.webgl=gl?"pass":"fail";
        gl?.getExtension("WEBGL_lose_context")?.loseContext();
      } catch(_) {checks.webgl="fail";}
      checks.network=navigator.onLine?"pass":"warn";
      // Independent network results. An offline navigator flag is only advisory.
      const [files,manifest]=await Promise.allSettled([assetsAvailable(),sourceManifest()]);
      checks.files=files.status==="fulfilled" && files.value ? "pass":"fail";
      if(manifest.status==="fulfilled" && manifest.value) {
        checks.manifest="pass";lastSource=manifest.value;
      }
    } catch(_) {
      // Fail closed: report limitations, never infer success.
    } finally {
      const status=["webgl","wasm","files"].every(key=>checks[key]==="pass") ? "READY":"LIMITED";
      result=Object.freeze({
        schema:"IRON_PULSE_LOCAL_PREFLIGHT_V14",
        status,source_sha:lastSource,
        checked_at:new Date().toISOString(),
        checks:Object.freeze({...checks}),
        note:"Local browser diagnostics only; no performance or hardware certification."
      });
      running=false;
      $("preflight-run").disabled=false;
      $("preflight-download").disabled=false;
      localize();
    }
    return result;
  }
  function downloadReport() {
    if(!result) return;
    const payload=JSON.stringify(result,null,2)+"\n";
    const blob=new Blob([payload],{type:"application/json"});
    const url=URL.createObjectURL(blob);
    try {
      const a=document.createElement("a");
      a.href=url;
      a.download="iron-pulse-local-diagnostic.json";
      document.body.appendChild(a);
      a.click();
      a.remove();
    } finally {setTimeout(()=>URL.revokeObjectURL(url),3000);}
  }
  $("preflight-run").addEventListener("click",run);
  $("preflight-download").addEventListener("click",downloadReport);
  document.addEventListener("iron-pulse:locale",localize);
  window.addEventListener("online",()=>{if(result) $("preflight-status").textContent=strings[language].limited;});
  window.addEventListener("offline",()=>{if(result) $("preflight-status").textContent=strings[language].limited;});
  Object.defineProperty(window,"IRON_PULSE_PREFLIGHT",{
    value:Object.freeze({run,get lastResult(){return result;}}),
    configurable:false,writable:false
  });
  localize();
})();
