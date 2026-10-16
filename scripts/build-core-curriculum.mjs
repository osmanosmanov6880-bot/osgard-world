import {readFileSync,writeFileSync} from 'node:fs'
import {createHash} from 'node:crypto'
import vm from 'node:vm'
import ts from 'typescript'
function load(path,dependencies={}){const module={exports:{}};vm.runInNewContext(ts.transpileModule(readFileSync(path,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.CommonJS}}).outputText,{module,exports:module.exports,require:name=>{if(name in dependencies)return dependencies[name];throw Error('Unexpected curriculum dependency '+name)}});return module.exports}
const registry=load('src/osaLessonRegistry.ts'),guides=load('src/osaLessonGuides.ts',{'./osaLessonRegistry':registry})
const lessons=registry.OSA_LESSON_SLUGS.map((slug,i)=>{const content={slug,ru:guides.osaLessonGuides.ru[i],en:guides.osaLessonGuides.en[i]};return {...content,hash:createHash('sha256').update(JSON.stringify(content)).digest('hex')}})
const json=JSON.stringify({schemaVersion:1,program:'osa-practical-ai-v1',lessons},null,2)+'\n'
if(process.argv.includes('--check')){if(readFileSync('server/curriculum.json','utf8')!==json)throw Error('Server curriculum is stale. Run npm run core:curriculum.');console.log('Curriculum parity passed: 8 lessons, both languages, quizzes and exercises')}
else{writeFileSync('server/curriculum.json',json);console.log('Built server curriculum from the existing canonical lesson guides')}
