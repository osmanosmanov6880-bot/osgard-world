export const EXPERIMENT_KEY='osa:experiments:v1'
export type Experiment={id:string;at:string;task:string;baselineMinutes:number;assistedMinutes:number;baselineErrors:number;assistedErrors:number;notes:string}
export function parseExperiments(raw:string):Experiment[]{
  if(raw.length>1000000)throw Error('size')
  const values=JSON.parse(raw)
  if(!Array.isArray(values)||values.length>100)throw Error('format')
  const ids=new Set<string>()
  return values.map(p=>{
    if(!p||typeof p.id!=='string'||!/^[a-zA-Z0-9-]{1,64}$/.test(p.id)||ids.has(p.id)||typeof p.at!=='string'||!Number.isFinite(Date.parse(p.at))||typeof p.task!=='string'||!p.task.trim()||p.task.length>1000||typeof p.notes!=='string'||p.notes.length>5000)throw Error('record')
    for(const key of ['baselineMinutes','assistedMinutes'])if(typeof p[key]!=='number'||!Number.isFinite(p[key])||p[key]<=0||p[key]>100000)throw Error('time')
    for(const key of ['baselineErrors','assistedErrors'])if(!Number.isInteger(p[key])||p[key]<0||p[key]>100000)throw Error('errors')
    ids.add(p.id)
    return {id:p.id,at:p.at,task:p.task,baselineMinutes:p.baselineMinutes,assistedMinutes:p.assistedMinutes,baselineErrors:p.baselineErrors,assistedErrors:p.assistedErrors,notes:p.notes}
  })
}
export function experimentDelta(p:Experiment){return {minutesSaved:p.baselineMinutes-p.assistedMinutes,timeRatio:p.baselineMinutes/p.assistedMinutes,errorDelta:p.assistedErrors-p.baselineErrors}}
