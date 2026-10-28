/** Single, public, factual source for OSA CINEMA Studio catalogue and dossiers.
 * These records are production metadata. They do not authorize film publication.
 */
export type StudioLocale = 'ru' | 'en'
export type StudioCategory = 'interactive' | 'film' | 'previz'
export type GateState = 'verified' | 'pending' | 'blocked'
export type ProductionGate = { code: string; ru: string; en: string; state: GateState }
export type StudioWork = {
  id: string
  title: string
  english: string
  category: StudioCategory
  year: string
  runtime: string
  artwork: 'understand.webp' | 'decide.webp' | 'verify.webp'
  status: string
  statusEn: string
  description: string
  descriptionEn: string
  action: 'explore' | 'details'
  href?: string
  loglineRu: string
  loglineEn: string
  formatRu: string
  formatEn: string
  releaseRu: string
  releaseEn: string
  releaseState: 'interactive_public' | 'owner_local' | 'not_filmed'
  gates: ProductionGate[]
  evidence: readonly { labelRu: string; labelEn: string; url: string }[]
}
const repo = 'https://github.com/osmanosmanov6880-bot/osgard-world'
export const studioWorks: readonly StudioWork[] = [
  {
    id:'the-next-human',title:'THE NEXT HUMAN',english:'THE NEXT HUMAN',category:'interactive',
    year:'2026',runtime:'8 SCENES',artwork:'understand.webp',
    status:'Интерактивная история доступна',statusEn:'Interactive story available',
    description:'Восемь интерактивных сцен о природе интеллекта, проверке фактов и человеческом выборе.',
    descriptionEn:'Eight interactive chapters about intelligence, evidence and human agency.',
    action:'explore',href:'/osa-cinema',
    loglineRu:'Знание не заканчивается ответом. Пройдите восемь глав, принимайте решения и проверяйте собственные выводы.',
    loglineEn:'Knowledge does not end with an answer. Explore eight chapters, make choices and test your reasoning.',
    formatRu:'Интерактивная история · 8 глав · 3 акта',
    formatEn:'Interactive narrative · 8 chapters · 3 acts',
    releaseRu:'Доступна оригинальная браузерная интерактивная история; это не выпуск полнометражного фильма.',
    releaseEn:'The original browser-based interactive experience is available; it is not a feature-film premiere.',
    releaseState:'interactive_public',
    gates:[
      {code:'STORY',ru:'Восемь интерактивных сцен',en:'Eight interactive chapters',state:'verified'},
      {code:'RU/EN',ru:'Русская и английская редакции',en:'Russian and English editions',state:'verified'},
      {code:'MEDIA',ru:'Отдельные фильмы и видеомастера',en:'Separate film and video masters',state:'blocked'}
    ],
    evidence:[{labelRu:'Открыть существующий интерактивный кинозал',labelEn:'Open the existing interactive cinema',url:'/osa-cinema'}]
  },
  {
    id:'zero-window',title:'НУЛЕВОЕ ОКНО',english:'ZERO WINDOW',category:'film',
    year:'2026',runtime:'18 MIN / PLANNED',artwork:'decide.webp',
    status:'В разработке · 0 из 13 сцен снято',statusEn:'In development · 0 of 13 scenes filmed',
    description:'Оригинальная драматическая короткометражная постановка. 13 сцен и 78 запланированных кадров. Сам фильм не снят.',
    descriptionEn:'An original dramatic short in development: 13 scenes and 78 proposed shots. Principal photography has not begun.',
    action:'details',
    loglineRu:'В производственном плане — 13 сцен и 78 будущих кадров. Сценарий и раскадровка существуют; настоящая актёрская съёмка ещё впереди.',
    loglineEn:'The production plan holds 13 scenes and 78 future shots. Script and shotlist exist; filmed actor scenes are yet to be made.',
    formatRu:'Игровой короткометражный фильм · цель 18 минут',
    formatEn:'Live-action short film · target 18 minutes',
    releaseRu:'Не снят. Ни одна игровая сцена не объявлена отснятой; публичная премьера запрещена до подтверждённых прав, производства и QA.',
    releaseEn:'Not filmed. No live-action scene is claimed as complete; public premiere is blocked until verified rights, production and QA.',
    releaseState:'not_filmed',
    gates:[
      {code:'V51.1',ru:'Разработка сценария',en:'Screenplay development',state:'verified'},
      {code:'V52',ru:'13 сцен · 78 запланированных кадров',en:'13 scenes · 78 proposed shots',state:'verified'},
      {code:'V54',ru:'Актёрская читка и съёмочная проба',en:'Table read and filmed scene',state:'pending'},
      {code:'V55',ru:'Утверждённые бюджет, права и безопасность',en:'Approved budget, rights and safety',state:'pending'},
      {code:'V56',ru:'Съёмка всех 13 сцен',en:'Principal photography of all 13 scenes',state:'blocked'},
      {code:'V57–58',ru:'Финальный монтаж, звук и дистрибуция',en:'Picture lock, sound and distribution',state:'blocked'}
    ],
    evidence:[
      {labelRu:'V52 — публичный производственный журнал',labelEn:'V52 — public production worklog',url:repo+'/pull/634'},
      {labelRu:'V53 — границы концепт-производства',labelEn:'V53 — concept production boundaries',url:repo+'/blob/master/docs/OSA_CINEMA_V53_MASTER_PRODUCTION_LEDGER_RU.md'}
    ]
  },
  {
    id:'threshold',title:'ПОРОГ РЕШЕНИЯ',english:'THRESHOLD',category:'previz',
    year:'2026',runtime:'02:40 / CONCEPT',artwork:'verify.webp',
    status:'Локальный концепт-превиз · не опубликован',statusEn:'Owner-local concept previz · not released',
    description:'Двуязычная концептуальная превизуализация V53 (RU/EN). Видеофайлы не размещены на публичной платформе.',
    descriptionEn:'A bilingual RU/EN V53 concept preview. The video masters are not on the public platform.',
    action:'details',
    loglineRu:'160-секундная двуязычная разработка визуального языка «Нулевого окна». Внутренняя демонстрация — не готовый игровой фильм.',
    loglineEn:'A 160-second bilingual exploration of the visual language for Zero Window. Owner-local concept screening is not a finished film.',
    formatRu:'Концептуальная превизуализация · RU/EN · 160 секунд',
    formatEn:'Concept previz · RU/EN · 160 seconds',
    releaseRu:'Видео существует только в отдельно доставленных владельцу локальных пакетах; воспроизведение в публичном браузере не подтверждено.',
    releaseEn:'Video exists only in separately delivered owner-local packages; public browser playback is not verified.',
    releaseState:'owner_local',
    gates:[
      {code:'V53',ru:'Четыре локальных MP4 720p/1080p проверены декодированием',en:'Four local 720p/1080p masters decoded',state:'verified'},
      {code:'LOCALE',ru:'RU/EN WebVTT и графические титры подготовлены',en:'RU/EN WebVTT and title graphics prepared',state:'verified'},
      {code:'RIGHTS',ru:'Независимая проверка прав',en:'Independent rights verification',state:'pending'},
      {code:'HTTPS',ru:'Публичный хостинг и проигрывание в браузере',en:'Public hosting and actual browser playback',state:'blocked'}
    ],
    evidence:[
      {labelRu:'V53 — производственный журнал',labelEn:'V53 — production journal',url:repo+'/pull/618'},
      {labelRu:'V53 — контрольный акт JSON',labelEn:'V53 — JSON evidence record',url:repo+'/blob/master/docs/OSA_CINEMA_V53_CONCEPT_EVIDENCE_20261028.json'}
    ]
  }
]
export const studioCategories = ['all','interactive','film','previz','saved'] as const
export type StudioFilter = (typeof studioCategories)[number]
export const studioIds: readonly string[] = studioWorks.map(work => work.id)
export function getStudioWork(id: string): StudioWork | undefined {
  return studioWorks.find(work => work.id === id)
}
export function isPublicVideoAvailable(work: StudioWork): boolean {
  // This registry has no video URLs, signed receipts or distribution authorizations.
  // A real film must use the separate server-side approved publication pipeline.
  void work
  return false
}
