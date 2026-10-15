import { useState } from 'react'
import { OSA_LESSON_SLUGS, osaLessonGuides, type OSALessonLocale } from './osaLessonGuides'
import { gradeOSAQuiz } from './osaAssessment'
import { trackOSAEvent } from './osaAnalytics'

export default function OSAAssessmentPage() {
  const [locale, setLocale] = useState<OSALessonLocale>('ru')
  const [answers, setAnswers] = useState<Record<string, number>>({})
  const [submitted, setSubmitted] = useState(false)
  const result = gradeOSAQuiz(answers, locale)
  return <main style={{maxWidth:860,margin:'0 auto',padding:'clamp(24px,5vw,72px)',minHeight:'100vh',color:'#e8edf7'}}>
    <nav style={{display:'flex',justifyContent:'space-between'}}><a href="/learning" style={{color:'#a9c4e9'}}>← OSA Learning</a><button type="button" onClick={() => {setLocale(locale==='ru'?'en':'ru');setSubmitted(false)}}>{locale.toUpperCase()} / {locale==='ru'?'EN':'RU'}</button></nav>
    <p style={{letterSpacing:3,color:'#a9c4e9',marginTop:50}}>OSA / KNOWLEDGE CHECK</p>
    <h1 style={{fontSize:'clamp(32px,5vw,58px)'}}>{locale==='ru'?'Проверка знаний':'Knowledge assessment'}</h1>
    <p>{locale==='ru'?'8 вопросов по материалам курса. Проходной результат — 6 правильных ответов.':'8 questions from the course. Passing score: 6 correct answers.'}</p>
    <form onSubmit={event=>{event.preventDefault();setSubmitted(true);trackOSAEvent('learning_assessment_submitted',{score:result.correct,passed:result.passed})}}>
      {OSA_LESSON_SLUGS.map((slug,index)=>{
        const check=osaLessonGuides[locale][index].check
        return <fieldset key={slug} style={{border:'1px solid #39465b',borderRadius:16,padding:20,margin:'18px 0'}}>
          <legend style={{padding:'0 8px',fontWeight:700}}>{index+1} / 8</legend>
          <p>{check.question}</p>
          {check.options.map((option,optionIndex)=><label key={optionIndex} style={{display:'flex',gap:12,padding:'9px 0',alignItems:'flex-start'}}>
            <input type="radio" name={slug} checked={answers[slug]===optionIndex} onChange={()=>{setAnswers(prev=>({...prev,[slug]:optionIndex}));setSubmitted(false)}} />
            <span>{option}</span>
          </label>)}
          {submitted && <p role="status" style={{color:result.answers[index].correct?'#8bd6ad':'#f2bd9d'}}>{result.answers[index].correct?'✓':'✗'} {check.explanation}</p>}
        </fieldset>
      })}
      <button type="submit" disabled={Object.keys(answers).length!==8} style={{padding:'14px 24px',borderRadius:12,fontWeight:700}}>{locale==='ru'?'Проверить ответы':'Grade answers'}</button>
    </form>
    {submitted && <section aria-live="polite" style={{marginTop:24,padding:24,border:'1px solid #39465b',borderRadius:16}}>
      <h2>{result.correct} / {result.total} — {result.percent}%</h2>
      <p>{result.passed?(locale==='ru'?'Тест пройден':'Assessment passed'):(locale==='ru'?'Повторите материалы и попробуйте ещё раз':'Review the material and try again')}</p>
      <p style={{color:'#a9c4e9'}}>{locale==='ru'?'Это учебная самопроверка, не официальный сертификат.':'This is a practice assessment, not an accredited certificate.'}</p>
      <a href="/learning" style={{color:'#a9c4e9'}}>{locale==='ru'?'К карте знаний →':'Back to learning map →'}</a>
    </section>}
  </main>
}
