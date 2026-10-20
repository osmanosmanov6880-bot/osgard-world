import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const read = file => readFileSync('public/games/inherit/' + file,'utf8');
const zhSource=read('zh.js'),interfaceSource=read('interface.js'),accountSource=read('account.js');
const html=read('index.html'),sw=read('sw.js');
let passed=0;
function check(name,fn){fn();passed++;console.log('PASS',name)}
function harness(search='',saved){
  const store=new Map(saved ? [['osgard:game-language',saved]] : []);
  const state={
    console,URL,URLSearchParams,
    location:{search,href:'https://osgard.world/games/inherit/'+search},
    history:{replaceState(){}},
    document:{readyState:'loading',documentElement:{},addEventListener(){}},
  };
  state.window=state;
  state.InheritPersistence={ephemeral:false,getItem:key=>store.get(key)||null,setItem:(key,value)=>store.set(key,value)};
  vm.createContext(state);
  vm.runInContext(zhSource,state,{filename:'zh.js'});
  vm.runInContext(interfaceSource.replace('getLanguage:()=>locale,updateStorage}', 'getLanguage:()=>locale,updateStorage,testTextNode:textNode}'),state,{filename:'interface.js'});
  return {ui:state.InheritUI,zh:state.InheritChinese,state,store};
}
check('Source locale files parse and are cached in the offline shell',()=>{
  new vm.Script(zhSource);new vm.Script(interfaceSource);
  assert.match(html,/<script defer src="\.\/zh\.js"><\/script><script defer src="\.\/interface\.js"><\/script>/);
  assert.match(sw,/\/games\/inherit\/zh\.js/);
});
check('Complete Chinese coverage for every base Russian and account dictionary key',()=>{
  const core=interfaceSource.split('const dictionary={')[1].split('\n};')[0];
  const account=accountSource.split('const translations={')[1].split('\n};')[0];
  const coreKeys=[...core.matchAll(/^\s*"([^"]+)":/gm)].map(x=>x[1]);
  const accountKeys=[...account.matchAll(/'([^']+)':'/g)].map(x=>x[1]);
  const h=harness('?lang=zh');
  assert.ok(coreKeys.length>=200 && accountKeys.length>=75);
  for(const key of [...coreKeys,...accountKeys])
    assert.ok(Object.hasOwn(h.zh.dictionary,key),'Missing Chinese translation: '+key);
  assert.ok(Object.keys(h.zh.dictionary).length>=290);
});
check('RU is the default; explicit ZH and saved language are supported',()=>{
  assert.equal(harness().ui.getLanguage(),'ru');
  assert.equal(harness('?lang=zh').ui.getLanguage(),'zh');
  assert.equal(harness('', 'zh').ui.getLanguage(),'zh');
  assert.equal(harness('?lang=en','zh').ui.getLanguage(),'en');
  assert.equal(harness('?lang=ru','zh').ui.getLanguage(),'ru');
});
check('Core labels and reactive account labels switch reversibly',()=>{
  const h=harness('?lang=ru'),word='Pass this world on →';
  const node={nodeValue:word,parentElement:{closest:()=>null}};
  h.ui.testTextNode(node);
  assert.equal(node.nodeValue,'Завершить поколение →');
  h.ui.setLanguage('zh');
  h.ui.testTextNode(node);
  assert.equal(node.nodeValue,'传承这个世界 →');
  assert.equal(h.ui.t('Account worlds'),'账号世界');
  assert.equal(h.ui.t('Sign in to Core'),'登录 Core');
  assert.equal(h.state.document.documentElement.lang,'zh-CN');
  assert.equal(h.store.get('osgard:game-language'),'zh');
  h.ui.setLanguage('en');
  h.ui.testTextNode(node);
  assert.equal(node.nodeValue,word);
  h.ui.setLanguage('ru');
  h.ui.testTextNode(node);
  assert.equal(node.nodeValue,'Завершить поколение →');
});
check('Chinese dynamic text supports generations, trace summaries and names',()=>{
  const h=harness('?lang=zh');
  assert.equal(h.ui.t('Generation 173 carries 4 recorded traces.'),'第 173 世代 · 已记录 4 道痕迹');
  assert.equal(h.ui.t('Leave 2 more kinds of trace'),'还需留下 2 种不同的痕迹');
  assert.equal(h.ui.t('Generation 2'),'第 2 世代');
  assert.equal(h.ui.t('This phrase is intentionally not translated'),'This phrase is intentionally not translated');
});
console.log('INHERIT RU EN ZH smoke:',passed,'tests passed');
