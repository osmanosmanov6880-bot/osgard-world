(() => {
  "use strict";
  const root = document.getElementById("table-session-demo");
  if (!root) return;
  const language = document.documentElement.lang || "en";
  const all = {
    ru: {
      scenarios:{family:"Семейный стол",celebration:"Праздничный стол",explore:"Знакомство с кухней"},
      bundles:{compact:"Компактный набор",balanced:"Сбалансированный стол",classic:"Классический выбор",generous:"Праздничный набор",discovery:"Знакомство с традициями"},
      dishes:{khinkal:"Хинкал аварский",chudu:"Чуду с зеленью",tea:"Чай горный"},
      within:"В пределах демо-бюджета",above:"Выше выбранного демо-бюджета",portions:"порц.",copySuccess:"Демо-план скопирован. Он никуда не отправлен.",copyFallback:"Буфер обмена недоступен. План раскрыт ниже для ручного копирования.",summary:"Демо-план стола ELBRUS",guests:"Гостей",occasion:"Повод",budget:"Бюджет на гостя",set:"Набор",total:"Оценка суммы",perGuest:"На гостя",limit:"В демо максимум 8 гостей.",reset:"Демо-параметры сброшены.",local:"Локальная демонстрация; заказ не отправлен."
    },
    en: {
      scenarios:{family:"Family table",celebration:"Celebration",explore:"Explore the cuisine"},
      bundles:{compact:"Compact set",balanced:"Balanced table",classic:"Classic choice",generous:"Celebration spread",discovery:"Taste of tradition"},
      dishes:{khinkal:"Avar khinkal",chudu:"Chudu with greens",tea:"Mountain tea"},
      within:"Within the demo budget",above:"Above the selected demo budget",portions:"portions",copySuccess:"Demo plan copied. Nothing was sent anywhere.",copyFallback:"Clipboard access is unavailable. The plan is shown below for manual copying.",summary:"ELBRUS demo table plan",guests:"Guests",occasion:"Occasion",budget:"Budget per guest",set:"Set",total:"Estimated total",perGuest:"Per guest",limit:"The demo is limited to 8 guests.",reset:"Demo settings reset.",local:"Local demo only; no order was sent."
    },
    ar: {
      scenarios:{family:"مائدة عائلية",celebration:"احتفال",explore:"اكتشاف المطبخ"},
      bundles:{compact:"مجموعة بسيطة",balanced:"مائدة متوازنة",classic:"اختيار كلاسيكي",generous:"مائدة احتفالية",discovery:"تذوق التقاليد"},
      dishes:{khinkal:"خينكال أفاري",chudu:"تشودو بالأعشاب",tea:"شاي الجبال"},
      within:"ضمن الميزانية التجريبية",above:"أعلى من الميزانية المختارة",portions:"حصص",copySuccess:"تم نسخ الخطة التجريبية. لم يتم إرسال أي شيء.",copyFallback:"الحافظة غير متاحة. تظهر الخطة أدناه للنسخ اليدوي.",summary:"خطة طاولة ELBRUS التجريبية",guests:"الضيوف",occasion:"المناسبة",budget:"الميزانية لكل ضيف",set:"المجموعة",total:"الإجمالي التقديري",perGuest:"لكل ضيف",limit:"الحد الأقصى في المعاينة 8 ضيوف.",reset:"تمت إعادة ضبط إعدادات المعاينة.",local:"معاينة محلية؛ لم يتم إرسال طلب."
    }
  };
  const text = all[language];
  if (!text) return;
  const $ = s => root.querySelector(s);
  const guestOutput=$("#table-guest-count"),title=$("#table-set-title"),items=$("#table-set-items"),status=$("#table-budget-status"),totalNode=$("#table-total"),perGuestNode=$("#table-per-guest"),budgetNode=$("#table-budget-total"),copyStatus=$("#table-copy-status"),fallback=$("#table-plan-fallback");
  if (![guestOutput,title,items,status,totalNode,perGuestNode,budgetNode,copyStatus,fallback].every(Boolean)) return;
  const number=new Intl.NumberFormat(language,{maximumFractionDigits:0}),money=new Intl.NumberFormat(language,{style:"currency",currency:"RUB",currencyDisplay:"narrowSymbol",maximumFractionDigits:0});
  const prices={khinkal:590,chudu:390,tea:160},state={guests:4,budget:800,occasion:"family"};
  const budgetButtons=[...root.querySelectorAll("[data-table-budget]")],occasionButtons=[...root.querySelectorAll("[data-table-occasion]")];
  function bundle(){
    const g=state.guests,half=Math.floor(g/2),halfUp=Math.ceil(g/2),q={khinkal:0,chudu:0,tea:0};let key="balanced";
    if(state.budget===500){q.chudu=g;q.tea=half;key="compact";}
    else if(state.budget===800){
      if(state.occasion==="family"){q.khinkal=half;q.chudu=halfUp;q.tea=half;key="balanced";}
      else if(state.occasion==="celebration"){q.khinkal=half;q.chudu=g;q.tea=half;key="generous";}
      else{q.khinkal=g;q.tea=half;key="classic";}
    }else if(state.occasion==="family"){q.khinkal=half;q.chudu=halfUp;q.tea=g;key="balanced";}
    else if(state.occasion==="celebration"){q.khinkal=g;q.chudu=g;q.tea=g;key="generous";}
    else{q.khinkal=g;q.chudu=half;q.tea=g;key="discovery";}
    const lines=Object.keys(q).filter(id=>q[id]>0).map(id=>({id,qty:q[id],sum:q[id]*prices[id],name:text.dishes[id]}));
    const sum=lines.reduce((a,l)=>a+l.sum,0);
    return {lines,sum,cap:g*state.budget,each:Math.ceil(sum/g),key};
  }
  function summary(b){
    return [text.summary,text.guests+": "+state.guests,text.occasion+": "+text.scenarios[state.occasion],text.budget+": "+money.format(state.budget),text.set+": "+text.bundles[b.key],...b.lines.map(l=>l.name+" × "+l.qty+" = "+money.format(l.sum)),text.total+": "+money.format(b.sum),text.perGuest+": "+money.format(b.each),"",text.local].join("\n");
  }
  function render(){
    const b=bundle();guestOutput.textContent=String(state.guests);
    root.querySelectorAll("[data-guest-step]").forEach(btn=>{const d=Number(btn.dataset.guestStep);btn.disabled=(d<0&&state.guests<=1)||(d>0&&state.guests>=8);});
    budgetButtons.forEach(btn=>btn.setAttribute("aria-pressed",String(Number(btn.dataset.tableBudget)===state.budget)));
    occasionButtons.forEach(btn=>btn.setAttribute("aria-pressed",String(btn.dataset.tableOccasion===state.occasion)));
    title.textContent=text.bundles[b.key];items.replaceChildren();
    b.lines.forEach(line=>{
      const li=document.createElement("li"),name=document.createElement("span"),qty=document.createElement("span"),sum=document.createElement("strong");
      name.className="table-session-item-name";name.textContent=line.name;qty.className="table-session-item-qty";qty.textContent="× "+number.format(line.qty)+" "+text.portions;sum.className="table-session-item-price";sum.textContent=money.format(line.sum);li.append(name,qty,sum);items.append(li);
    });
    totalNode.textContent=money.format(b.sum);perGuestNode.textContent=money.format(b.each);budgetNode.textContent=money.format(b.cap);
    const fits=b.sum<=b.cap;status.textContent=fits?text.within:text.above;status.classList.toggle("is-over",!fits);
    copyStatus.textContent="";fallback.hidden=true;fallback.value="";
  }
  root.querySelectorAll("[data-guest-step]").forEach(btn=>btn.addEventListener("click",()=>{state.guests=Math.max(1,Math.min(8,state.guests+Number(btn.dataset.guestStep)));render();}));
  const join=$("[data-guest-join]");if(join)join.addEventListener("click",()=>{if(state.guests>=8){copyStatus.textContent=text.limit;return;}state.guests+=1;render();});
  budgetButtons.forEach(btn=>btn.addEventListener("click",()=>{state.budget=Number(btn.dataset.tableBudget);render();}));
  occasionButtons.forEach(btn=>btn.addEventListener("click",()=>{state.occasion=btn.dataset.tableOccasion;render();}));
  const reset=$("[data-table-reset]");if(reset)reset.addEventListener("click",()=>{state.guests=4;state.budget=800;state.occasion="family";render();copyStatus.textContent=text.reset;});
  const copy=$("[data-table-copy]");if(copy)copy.addEventListener("click",async()=>{
    const out=summary(bundle());
    try{if(!navigator.clipboard||typeof navigator.clipboard.writeText!=="function")throw new Error("clipboard unavailable");await navigator.clipboard.writeText(out);copyStatus.textContent=text.copySuccess;fallback.hidden=true;}
    catch{fallback.value=out;fallback.hidden=false;fallback.focus();fallback.select();copyStatus.textContent=text.copyFallback;}
  });
  render();
})();