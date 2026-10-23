import type { PlayGame } from './redesignCatalog'

export type PlayCatalogCard = Pick<PlayGame, 'id' | 'title' | 'genre' | 'mode' | 'format' | 'description' | 'status' | 'accent'>

export const PLAY_GAME_IDS: string[] = [
  'null-shift','time','empire-orbit','swarm','inherit','remix','vector-zero','afterimage-run',
  'empire-omega','nebula-3d','r136-precision',
  'zion-020','zion-021','zion-022','zion-023','zion-024','zion-025','zion-026','zion-027','zion-028','zion-029','zion-030',
]

export const PLAY_GENRES: string[] = [
  'Тактика','Стратегия','Кооператив','Симуляция','Арена','Платформер','Раннер',
  'Симулятор','Космический симулятор','Головоломка','История',
]

// Only hero summaries load with the landing page. Full game instructions stay
// in the deferred catalogue and game detail routes.
export const FEATURED_PLAY_WORLDS: PlayCatalogCard[] = [
  { id:'vector-zero', title:'VECTOR//ZERO', genre:'Платформер', mode:'solo', format:'Физическая головоломка',
    description:'Проведите ядро через магнитное поле и найдите путь к выходу.',
    status:'Игровой прототип', accent:'#5CE1E6' },
  { id:'time', title:'Империя времени', genre:'Стратегия', mode:'solo', format:'Стратегический прототип',
    description:'Управляйте ресурсами, районами и фракциями города.',
    status:'Прототип', accent:'#B7F15A' },
  { id:'null-shift', title:'NULL//SHIFT', genre:'Тактика', mode:'solo', format:'Тактическая игра',
    description:'Отключите охрану, заберите ядро и доберитесь до эвакуации.',
    status:'Опубликованная сборка', accent:'#8DB5CE' },
  { id:'zion-030', title:'Теневой протокол', genre:'Головоломка', mode:'solo', format:'3D-головоломка',
    description:'Выберите модуль и закройте горячие точки городской миссии.',
    status:'Игровой прототип', accent:'#82dfa2' },
]
