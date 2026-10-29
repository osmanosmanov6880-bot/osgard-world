import { useEffect,useMemo,useRef,useState,type FormEvent } from 'react'
import { Archive,Check,Download,FileArchive,FileCheck2,FileUp,HardDrive,LockKeyhole,RefreshCw,ShieldAlert,ShieldCheck,Trash2,UploadCloud } from 'lucide-react'
import { coreRequest,CoreError,uploadCoreCinemaAsset,downloadCoreCinemaAsset,cinemaVaultMime } from './coreClient'
import type { StudioLocale } from './osaCinemaStudioRegistry'
import './osaCinemaAssetVault.css'

type Role='owner'|'editor'|'viewer'
type Item={id:string;spaceId:string;evidenceId:string|null;name:string;mime:string;bytes:number;actualSha256:string;checksumComputedFromBytes:true;malwareScanned:false;rightsIndependentlyVerified:false;filmReleaseAuthorized:false;uploader:string;createdAt:string}
type List={spaceId:string;spaceVersion:number;role:Role;assets:Item[];usedBytes:number;limits:{maxAssetBytes:number;maxSpaceBytes:number;maxAssets:number};scope:string;releaseAuthorized:false;publicVideoUrl:null;publicStreamingEnabled:false;encryptionAtRest:false;serverAntivirus:false}
type Evidence={id:string;title:string;sceneId:string}
type Props={spaceId:string;role:Role;version:number;locale:StudioLocale;onChanged:()=>Promise<void>}
const sizeText=(n:number)=>(n/1024).toLocaleString('en-US',{maximumFractionDigits:1})+' KiB'
export default function OSACinemaAssetVault({spaceId,role,version,locale,onChanged}:Props){
 const ru=locale==='ru'
 const tr=(a:string,b:string)=>ru?a:b
 const [list,setList]=useState<List|null>(null)
 const [evidence,setEvidence]=useState<Evidence[]>([])
 const [asset,setAsset]=useState<File|null>(null)
 const [linked,setLinked]=useState('')
 const [loading,setLoading]=useState(true)
 const [busy,setBusy]=useState(false)
 const [error,setError]=useState('')
 const [notice,setNotice]=useState('')
 const [confirmDelete,setConfirmDelete]=useState('')
 const pending=useRef<{signature:string;key:string}|null>(null)
 const inputRef=useRef<HTMLInputElement|null>(null)
 const editable=role==='owner'||role==='editor'
 const remaining=useMemo(()=>list?Math.max(0,list.limits.maxSpaceBytes-list.usedBytes):0,[list])
 const endpoint='cinema/spaces/'+spaceId+'/vault'
 async function refresh(){
  setLoading(true)
  try{
   const [assets,entries]=await Promise.all([
    coreRequest<List>(endpoint),
    coreRequest<{evidence:Evidence[]}>('cinema/spaces/'+spaceId+'/evidence')
   ])
   setList(assets);setEvidence(entries.evidence);setError('')
  }catch(e){setError(e instanceof Error?e.message:tr('Реестр файлов недоступен.','File vault is unavailable.'))}
  finally{setLoading(false)}
 }
 useEffect(()=>{setList(null);setAsset(null);setLinked('');setConfirmDelete('');void refresh()},[spaceId,version])
 async function upload(e:FormEvent){
  e.preventDefault()
  if(!editable||busy||!asset||!list)return
  const validType=cinemaVaultMime(asset.name)
  if(!validType||asset.size<=0||asset.size>list.limits.maxAssetBytes||asset.size>remaining){
   setError(tr('Неподдерживаемый тип файла или превышен лимит.','Unsupported file type or quota exceeded.'));return
  }
  const signature=[spaceId,list.spaceVersion,asset.name,asset.size,asset.lastModified,linked].join('|')
  const key=pending.current?.signature===signature?pending.current.key:crypto.randomUUID().replaceAll('-','')
  pending.current={signature,key};setBusy(true);setError('');setNotice('')
  try{
   const result=await uploadCoreCinemaAsset(spaceId,list.spaceVersion,asset,key,linked)
   pending.current=null
   setNotice(tr('Реальные байты сохранены в SQLite. SHA-256 вычислена сервером: ','Actual bytes stored in SQLite. Server-computed SHA-256: ')+result.actualSha256)
   setAsset(null);setLinked('');if(inputRef.current)inputRef.current.value=''
   await onChanged();await refresh()
  }catch(e){
   if(e instanceof CoreError&&e.code==='version_conflict'){pending.current=null;await onChanged();await refresh()}
   setError(e instanceof Error?e.message:tr('Загрузка не выполнена.','Upload failed.'))
  }finally{setBusy(false)}
 }
 async function download(item:Item){
  if(busy)return
  setBusy(true);setError('');setNotice('')
  try{
   await downloadCoreCinemaAsset(spaceId,item.id,item.name,item.actualSha256)
   setNotice(tr('Байты проверены в браузере по SHA-256 и сохранены локально.','Downloaded bytes verified against SHA-256 in your browser.'))
  }catch(e){setError(e instanceof Error?e.message:tr('Не удалось скачать файл.','File download failed.'))}
  finally{setBusy(false)}
 }
 async function remove(item:Item){
  if(confirmDelete!==item.id){setConfirmDelete(item.id);return}
  if(busy||!list)return
  setBusy(true);setError('');setNotice('')
  try{
   await coreRequest(endpoint,{kind:'asset.delete',expectedVersion:list.spaceVersion,assetId:item.id},crypto.randomUUID().replaceAll('-',''))
   setConfirmDelete('')
   setNotice(tr('Файл удалён из активной SQLite. Старые резервные копии могут содержать его байты.','Asset deleted from active SQLite; older backups may still hold its bytes.'))
   await onChanged();await refresh()
  }catch(e){setError(e instanceof Error?e.message:tr('Удаление не выполнено.','Delete failed.'))}
  finally{setBusy(false)}
 }
 return <section className="osa-vault" aria-labelledby="osa-vault-heading" data-private-vault="binary-sqlite">
  <header className="osa-vault-hero"><div><p className="osa-studio-eyebrow">OSA CINEMA / V63 / BYTE VAULT</p><h3 id="osa-vault-heading">{tr('ЧАСТНЫЙ АРХИВ.','PRIVATE ASSET VAULT.')}</h3><p>{tr('Настоящие байты файлов хранятся в SQLite вне публичной папки сайта. Каждый скачанный файл проверяется по SHA-256. Ни один файл не становится публичной премьерой.','Real file bytes are held inside private Core SQLite, outside the public website. Every download is checked against SHA-256. No file is a public premiere.')}</p></div><button type="button" disabled={busy||loading} onClick={()=>void refresh()}><RefreshCw size={16}/>{tr('Обновить','Refresh')}</button></header>
  <div className="osa-vault-warning"><ShieldAlert size={22}/><div><strong>{tr('Пилот, не хранилище юридических оригиналов','Pilot, not a legal evidence vault')}</strong><p>{tr('Нет шифрования файлов на уровне приложения, антивирусного сканирования, независимой проверки прав или CDN. Не загружайте персональные документы и секреты. MP4 разрешён только как небольшой закрытый рабочий прокси-файл.','No application-level encryption, antivirus scan, independent rights review or CDN. Do not upload personal documents or secrets. MP4 is permitted only as a small, private working proxy.')}</p></div><span>NO PUBLIC MEDIA</span></div>
  {loading&&<p className="osa-vault-empty" role="status"><RefreshCw size={18}/>{tr('Читаем закрытое хранилище Core…','Loading actual private Core assets…')}</p>}
  {list&&!loading&&<>
    <div className="osa-vault-metrics"><div><strong>{list.assets.length} / {list.limits.maxAssets}</strong><span>{tr('Файлы в архиве','Private assets')}</span></div><div><strong>{sizeText(list.usedBytes)}</strong><span>{tr('Занято','Stored bytes')}</span></div><div><strong>{sizeText(remaining)}</strong><span>{tr('Осталось места','Remaining quota')}</span></div><div><strong>NO-GO</strong><span>{tr('Публичная премьера','Public release')}</span></div></div>
    <div className="osa-vault-list">{list.assets.length===0&&<div className="osa-vault-empty"><Archive size={27}/><strong>{tr('Нет загруженных файлов.','No files uploaded.')}</strong><p>{tr('Тестовые, вымышленные медиафайлы не создаются.','No fake media assets are generated.')}</p></div>}
    {list.assets.map(item=><article className="osa-vault-asset" key={item.id}>
      <div className="osa-vault-file-icon"><FileArchive size={25}/></div>
      <div className="osa-vault-file-info"><small>{item.mime.toUpperCase()} · {sizeText(item.bytes)} · {item.createdAt}</small><h4>{item.name}</h4><p>{tr('Загрузил: ','Uploaded by: ')}{item.uploader}{item.evidenceId?' · '+tr('Связано с записью','Linked to evidence')+' '+item.evidenceId.slice(0,8):''}</p><details><summary><FileCheck2 size={15}/>{tr('Реальная SHA-256','Computed file SHA-256')}</summary><code>{item.actualSha256}</code><p>{tr('Хеш вычислен из байтов в Core. Подлинность источника, лицензия и отсутствие вирусов не проверялись.','Computed from actual bytes in Core. Source authenticity, licenses and malware status remain unverified.')}</p></details></div>
      <div className="osa-vault-buttons"><button disabled={busy} type="button" onClick={()=>void download(item)}><Download size={15}/>{tr('Скачать и проверить','Verify & download')}</button>{editable&&<button disabled={busy} className="osa-vault-remove" type="button" onClick={()=>void remove(item)}><Trash2 size={14}/>{confirmDelete===item.id?tr('Подтвердить удаление','Confirm deletion'):tr('Удалить','Delete')}</button>}</div>
     </article>)}</div>
    {editable&&<form className="osa-vault-form" onSubmit={e=>void upload(e)}><div className="osa-vault-form-title"><UploadCloud size={28}/><div><p className="osa-studio-eyebrow">REAL BINARY UPLOAD / HTTPS + SQLITE</p><h4>{tr('Добавить производственный файл','Upload a working production file')}</h4></div></div><p>{tr('PDF, TXT, PNG, JPEG, WebP или MP4 размером до 8 МиБ. Лимит пространства — 32 МиБ и 16 файлов. Исходники фильмов и личные документы сюда не загружать.','PDF, TXT, PNG, JPEG, WebP or MP4 up to 8 MiB. Limits: 32 MiB and 16 assets per workspace. Do not upload film masters or personal documents.')}</p>
      <label>{tr('Выберите локальный файл','Choose a local file')}<input ref={inputRef} type="file" accept=".pdf,.txt,.png,.jpg,.jpeg,.webp,.mp4" disabled={busy} onChange={e=>{setAsset(e.target.files?.[0]||null);pending.current=null}}/></label>
      {asset&&<p className="osa-vault-selection"><HardDrive size={16}/>{asset.name} — {sizeText(asset.size)}</p>}
      <label>{tr('Связать с записью V62 (необязательно)','Link to an existing V62 record (optional)')}<select value={linked} disabled={busy} onChange={e=>{setLinked(e.target.value);pending.current=null}}><option value="">{tr('Без связи','No link')}</option>{evidence.map(entry=><option key={entry.id} value={entry.id}>{entry.sceneId} · {entry.title}</option>)}</select></label>
      <button type="submit" disabled={!asset||busy||list.assets.length>=list.limits.maxAssets||remaining===0}><FileUp size={17}/>{busy?tr('Сохраняем…','Saving…'):tr('Сохранить байты в Core','Store actual bytes in Core')}</button>
    </form>}
  </>}
  {error&&<p role="alert" className="osa-vault-error"><ShieldAlert size={17}/>{error}</p>}
  {notice&&<p role="status" className="osa-vault-notice"><Check size={17}/>{notice}</p>}
  <footer className="osa-vault-footer"><LockKeyhole size={20}/><p>{tr('Только авторизованные участники кинопространства. Файлы выдаются как вложения, без общедоступных URL. Отзыв доступа отключает последующие скачивания. Это не юридически сертифицированный архив.','Only authenticated workspace members can retrieve attachments. No public asset URLs. Revoking membership blocks subsequent downloads. This is not a certified legal archive.')}</p><ShieldCheck size={20}/></footer>
 </section>
}
