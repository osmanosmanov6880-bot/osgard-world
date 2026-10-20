#!/usr/bin/env node
/* Local operator tool. Consented pilot JSON files are never uploaded automatically. */
import {readFileSync,readdirSync,statSync,mkdirSync,writeFileSync} from 'node:fs';
import {resolve,join,extname} from 'node:path';
import {aggregate,formatMarkdown} from './inherit-pilot-metrics.mjs';
function usage(){
 console.log('INHERIT pilot: node scripts/inherit-pilot-report.mjs --input <directory-or-json> [--as-of YYYY-MM-DD] [--out <directory>]');
 console.log('Reads ONLY voluntary player exports. Output has aggregate counts, no participant identifiers.');
}
const argv=process.argv.slice(2),arg=name=>{const idx=argv.indexOf(name);return idx<0?null:argv[idx+1]||null};
if(argv.includes('--help')||argv.includes('-h')){usage();process.exit(0)}
const input=arg('--input'),output=arg('--out');
if(!input){usage();process.exitCode=2}else{
 try{
  const today=new Date().toISOString().slice(0,10),asOf=arg('--as-of')||today;
  const source=resolve(input),info=statSync(source);
  const files=info.isDirectory()?readdirSync(source).filter(n=>extname(n).toLowerCase()==='.json').sort().map(n=>join(source,n)):[source];
  if(!files.length)throw Error('No JSON files found. No results were generated.');
  if(files.length>5000)throw Error('Too many files; process a smaller voluntary cohort.');
  const data=files.map(path=>{
   if(!statSync(path).isFile()||statSync(path).size>250000)throw Error('Invalid or oversized voluntary export: '+path);
   return JSON.parse(readFileSync(path,'utf8'));
  });
  const report=aggregate(data,asOf);
  if(output){
   const dest=resolve(output);mkdirSync(dest,{recursive:true});
   writeFileSync(join(dest,'inherit-pilot-scorecard.json'),JSON.stringify(report,null,2)+'\n');
   writeFileSync(join(dest,'inherit-pilot-scorecard.md'),formatMarkdown(report));
   console.log('Aggregate scorecards written to '+dest);
  }else console.log(formatMarkdown(report));
  console.log('Validated voluntary participant exports: '+report.sample.participants+' / '+files.length);
 }catch(e){console.error('INHERIT pilot report:',e.message);process.exitCode=1}
}
