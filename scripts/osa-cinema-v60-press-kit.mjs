/** Derived international press pack; NEVER a media availability or rights receipt. */
export const PRESS_KIT_SCHEMA='OSA_CINEMA_WORLD_PRESS_V1'
const ROOT='https://osgard.world'
const expected=['the-next-human','zero-window','threshold']
const allowedArt=new Set(['understand.webp','decide.webp','verify.webp'])
export function makePressKit(works,evidence,releaseDecisions){
  if(!Array.isArray(works)||works.length!==3||works.some((w,i)=>w.id!==expected[i]||!allowedArt.has(w.artwork)||
    !['interactive_public','not_filmed','owner_local'].includes(w.releaseState)||!w.title||!w.english||!w.description||!w.descriptionEn))
    throw Error('Public press must follow the approved editorial catalogue')
  if(!evidence||evidence.schemaVersion!==1||evidence.version!=='V53'||
     evidence.publicReleaseAuthorized!==false||evidence.premiereUrl!==null||
     evidence.actorSceneProduction?.scenesPlanned!==13||evidence.actorSceneProduction?.scenesFilmed!==0||
     evidence.actorSceneProduction?.shotsProposed!==78||evidence.actorSceneProduction?.shotsFilmed!==0||
     evidence.actorSceneProduction?.shortTargetSeconds!==1080||
     evidence.media?.conceptCutSeconds!==160||evidence.media?.subtitleTrackCount!==2||
     evidence.qa?.publicHttps!=='NOT_VERIFIED'||evidence.qa?.rights!=='OWNER_SELF_ATTESTED_UNVERIFIED_INDEPENDENTLY')
    throw Error('V53 original evidence is missing, changed or no longer proves a safe NO-GO')
  if(!Array.isArray(releaseDecisions)||releaseDecisions.length!==2||
     releaseDecisions.some(d=>!expected.includes(d.projectId)||d.releaseAuthorized!==false||
       d.publicVideoUrl!==null||d.readyForRelease!==false))
    throw Error('Release decision data cannot authorize a film')
  const projects=works.map(w=>({
    id:w.id,
    titles:{ru:w.title,en:w.english},
    descriptions:{ru:w.description,en:w.descriptionEn},
    loglines:{ru:w.loglineRu,en:w.loglineEn},
    formats:{ru:w.formatRu,en:w.formatEn},
    releaseStatus:{ru:w.releaseRu,en:w.releaseEn},
    category:w.category,releaseState:w.releaseState,
    dossierUrl:ROOT+'/osa-cinema/studio/films/'+w.id,
    originalArtworkUrl:ROOT+'/osa-cinema/reference/'+w.artwork,
    publicVideoAvailable:false,publicMoviePremiere:false,playbackUrl:null,
    interactiveUrl:w.id==='the-next-human'?ROOT+'/osa-cinema':null,
    evidenceLinks:w.evidence.filter(e=>typeof e.url==='string'&&
      (e.url.startsWith('/')||e.url.startsWith('https://github.com/osmanosmanov6880-bot/osgard-world')))
      .map(e=>({title:{ru:e.labelRu,en:e.labelEn},url:e.url.startsWith('/')?ROOT+e.url:e.url}))
  }))
  return {
    schema:PRESS_KIT_SCHEMA,version:1,publisher:'OSA CINEMA',asOfEvidenceDate:evidence.asOf,
    languages:['ru','en'],
    newsroomUrl:ROOT+'/osa-cinema/studio/press',
    editorialCatalogueUrl:ROOT+'/osa-cinema/studio/catalog.v1.json',
    archiveSourceUrl:'https://github.com/osmanosmanov6880-bot/osgard-world/blob/master/docs/OSA_CINEMA_V53_CONCEPT_EVIDENCE_20261028.json',
    publicPremiereAuthorized:false,
    rightsIndependentlyVerified:false,
    allMoviePlaybackVerified:false,
    factualProduction:{
      filmId:'zero-window',liveActionScenesPlanned:13,liveActionScenesFilmed:0,
      proposedShots:78,actualShotsFilmed:0,shortFilmTargetMinutes:18,
      finishedShortFilm:false
    },
    localConcept:{
      projectId:'threshold',durationSeconds:160,
      bilingual:true,ownerLocalMasters:4,
      completedDecodes:4,subtitleTrackCount:2,
      publicHttpsPlaybackVerified:false
    },
    releaseReview:releaseDecisions.map(d=>({projectId:d.projectId,verified:d.verified,pending:d.pending,blocked:d.blocked,releaseAuthorized:false})),
    projects
  }
}
export function renderPressText(press,locale){
  if(!press||press.schema!==PRESS_KIT_SCHEMA||!['ru','en'].includes(locale))throw Error('Invalid press kit text request')
  const ru=locale==='ru'
  return [
    'OSA CINEMA / '+(ru?'ПРЕСС-ПАКЕТ':'PRESS KIT'),
    (ru?'По материалам от: ':'Evidence as of: ')+press.asOfEvidenceDate,
    '',
    ru?'ПУБЛИЧНЫЙ СТАТУС: ФИЛЬМЫ НЕ ВЫПУЩЕНЫ':'PUBLIC RELEASE: NO FILM PREMIERE',
    ru?'Права: независимая проверка не подтверждена':'Rights: independent clearance not verified',
    ru?'Видеопоказ на публичном HTTPS: не подтверждён':'Public HTTPS video playback: not verified',
    '',
    ...press.projects.flatMap(p=>[
      p.titles[locale]+' ['+p.category.toUpperCase()+']',
      p.descriptions[locale],
      (ru?'Статус: ':'Status: ')+p.releaseStatus[locale],
      (ru?'Досье: ':'Dossier: ')+p.dossierUrl,
      ''
    ]),
    ru?'Источники и актуальные ограничения: ':'Source record and limitations: ',
    press.archiveSourceUrl,
    ''
  ].join('\n')
}
