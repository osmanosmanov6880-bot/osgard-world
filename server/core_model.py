"""Validated domain data for the OSGARD pilot. No remote actions or paid APIs."""
from datetime import datetime, timezone
from urllib.parse import urlsplit
import copy
import re
import uuid

LESSONS = ('intelligence-and-imitation','how-language-models-work','power-of-knowledge','signal-and-noise','verify-an-ai-answer','privacy-before-prompting','human-in-the-loop','investigate-the-future')
CATEGORIES = ('compute','payment_fees','mentors','support','other')

def now(): return datetime.now(timezone.utc).isoformat(timespec='seconds')
def uid(): return uuid.uuid4().hex

class Fault(Exception):
    def __init__(self, code, message, status=400):
        super().__init__(message)
        self.code, self.message, self.status = code, message, status

def require(condition, message, code='validation', status=400):
    if not condition: raise Fault(code, message, status)

def text(value, maximum=4000, minimum=0):
    require(isinstance(value,str) and minimum <= len(value.strip()) <= maximum, 'Проверьте длину текстового поля.')
    return value.strip()

def amount(value):
    require(type(value) is int and 0 <= value <= 10**11, 'Сумма должна быть целым числом минимальных денежных единиц.')
    return value

def date(value, optional=True):
    require(isinstance(value,str), 'Неверная дата.')
    if not value and optional: return ''
    try: result=datetime.fromisoformat(value.replace('Z','+00:00'))
    except ValueError: raise Fault('validation','Неверная дата.')
    require(result.tzinfo is not None, 'Для даты нужен часовой пояс.')
    return result.astimezone(timezone.utc).isoformat()

def url(value):
    value=text(value,2000)
    if not value:return ''
    p=urlsplit(value)
    require(p.scheme in ('https','http') and bool(p.hostname) and not p.username and not p.password and not any(c.isspace() for c in value), 'Нужна полная HTTP(S)-ссылка без пароля.')
    return value

def list_of(value, maximum):
    require(isinstance(value,list) and len(value)<=maximum,'Слишком много элементов или неверный список.')
    require(all(isinstance(v,dict) for v in value),'Неверный элемент списка.')
    return value

def initial(title, goal):
    return dict(schemaVersion=1,title=text(title,160,2),goal=text(goal,4000,10),audience='',deadline='',currency='RUB',budgetMinor=0,accepted=False,allowedActions=['local_checks'],acceptance=[],tasks=[dict(id=uid(),title=t,done=False) for t in ['Уточнить цель и ограничения','Пройти необходимую практику','Создать полезный артефакт','Проверить критерии результата','Подготовить предложение','Измерить результат']],sources=[],decisions=[],lessonCompletions=[],practice=dict(problem='',before='',newTask='',after='',evidence=''),artifact=dict(url='',checksum='',notes='',assetId=''),offer=dict(title='',customer='',scope='',amountMinor=0),costs=[],orders=[],releases=[],measurements=[],consents=dict(learning=False,studio=False,business=False))

EDITABLE={'title','goal','audience','deadline','currency','budgetMinor','accepted','allowedActions','acceptance','tasks','sources','decisions','lessonCompletions','practice','artifact','offer','consents'}

def patch(data, changes):
    require(isinstance(changes,dict) and changes and set(changes)<=EDITABLE,'Недопустимые поля изменения.')
    d=copy.deepcopy(data);d.update(changes)
    d['title']=text(d['title'],160,2);d['goal']=text(d['goal'],4000,10);d['audience']=text(d['audience'],1000)
    d['deadline']=date(d['deadline']);d['budgetMinor']=amount(d['budgetMinor'])
    require(d['currency'] in ('RUB','USD','EUR'),'Неподдерживаемая валюта.')
    require(not data['costs'] and not data['orders'] or d['currency']==data['currency'],'После учёта расходов или заказов валюта зафиксирована.')
    require(type(d['accepted']) is bool,'Неверный статус контракта.')
    require(isinstance(d['allowedActions'],list) and len(d['allowedActions'])<=3 and set(d['allowedActions'])<={'local_checks','prepare_offer','build_preview'},'Внешние действия пока не подключены.')
    for key in ('acceptance','tasks'):
        d[key]=[dict(id=text(v.get('id'),64,1),title=text(v.get('title'),500,2),done=v.get('done')) for v in list_of(d[key],30)]
        require(all(type(v['done']) is bool for v in d[key]),'Неверный статус задачи.')
        require(len({v['id'] for v in d[key]})==len(d[key]),'Повторный идентификатор.')
    d['sources']=[dict(id=text(v.get('id'),64,1),title=text(v.get('title'),200,2),url=url(v.get('url','')),notes=text(v.get('notes',''),2000),checkedAt=date(v.get('checkedAt','')),expiresAt=date(v.get('expiresAt',''))) for v in list_of(d['sources'],50)]
    require(len({v['id'] for v in d['sources']})==len(d['sources']),'Повторный идентификатор источника.')
    d['decisions']=[dict(id=text(v.get('id'),64,1),text=text(v.get('text'),2000,2),at=date(v.get('at'),False)) for v in list_of(d['decisions'],50)]
    require(len({v['id'] for v in d['decisions']})==len(d['decisions']),'Повторный идентификатор решения.')
    require(isinstance(d['lessonCompletions'],list) and all(v in LESSONS for v in d['lessonCompletions']),'Неизвестный урок.')
    d['lessonCompletions']=list(dict.fromkeys(d['lessonCompletions']))
    require(isinstance(d['practice'],dict) and isinstance(d['artifact'],dict) and isinstance(d['offer'],dict),'Неверный объект проекта.')
    d['practice']={k:text(d['practice'].get(k,''),4000) for k in ('problem','before','newTask','after','evidence')}
    d['artifact']={k:(url(d['artifact'].get(k,'')) if k=='url' else text(d['artifact'].get(k,''),2000)) for k in ('url','checksum','notes')}
    d['artifact']['assetId']=data['artifact'].get('assetId','') if all(d['artifact'][k]==data['artifact'][k] for k in ('url','checksum')) else ''
    require(not d['artifact']['checksum'] or re.fullmatch('[a-fA-F0-9]{64}',d['artifact']['checksum']),'SHA-256 должен содержать 64 шестнадцатеричных символа.')
    d['offer']={k:text(d['offer'].get(k,''),4000) for k in ('title','customer','scope')};d['offer']['amountMinor']=amount(changes.get('offer',data['offer']).get('amountMinor',0))
    require(isinstance(d['consents'],dict) and all(type(d['consents'].get(k)) is bool for k in ('learning','studio','business')),'Проверьте разрешения контекста.')
    d['consents']={k:d['consents'][k] for k in ('learning','studio','business')}
    # A signed-off contract is invalidated by changes to its scope or limits.
    terms=('goal','audience','deadline','currency','budgetMinor','allowedActions','acceptance')
    if any(d[k]!=data[k] for k in terms): d['accepted']=False
    return d

def simulation(d):
    expired=[s['title'] for s in d['sources'] if s['expiresAt'] and datetime.fromisoformat(s['expiresAt'])<datetime.now(timezone.utc)]
    spent=sum(c['amountMinor'] for c in d['costs'])
    return [dict(id='contract',label='Контракт принят после последнего изменения условий',passed=d['accepted']),dict(id='studio',label='Разрешено использовать контекст в Studio',passed=d['consents']['studio']),dict(id='permission',label='Разрешены локальные проверки',passed='local_checks' in d['allowedActions']),dict(id='criteria',label='Все критерии отмечены и имеют описание',passed=bool(d['acceptance']) and all(a['done'] for a in d['acceptance'])),dict(id='artifact',label='Указана ссылка или создан HTML-прототип',passed=bool(d['artifact']['url'] or d['artifact'].get('assetId'))),dict(id='sources',label='Нет просроченных источников',passed=not expired),dict(id='budget',label='Учтённые расходы не превышают бюджет',passed=spent<=d['budgetMinor'])]

def economics(d):
    booked=sum(o['amountMinor'] for o in d['orders'] if o['status']=='draft')
    costs=sum(c['amountMinor'] for c in d['costs'])
    # There is deliberately no "mark paid" API. No payment provider is connected.
    return dict(draftOfferMinor=booked,confirmedRevenueMinor=0,refundsMinor=0,costMinor=costs,contributionMinor=-costs,budgetRemainingMinor=d['budgetMinor']-costs)

def metrics(d):
    records=d.get('measurements',[]);before=sum(r['beforeSeconds'] for r in records)
    after=sum(r['afterSeconds']+r['correctionSeconds']+r['manualSeconds'] for r in records)
    success=sum(1 for r in records if r['success'])
    return dict(sampleSize=len(records),baselineSeconds=before,assistedTotalSeconds=after,speedRatio=round(before/after,3) if after else None,successRate=round(success/len(records),4) if records else None,targets=dict(speedRatio=3,successRate=.85),status='user_reported_observations')

def action(data, kind, payload):
    d=copy.deepcopy(data);result={}
    if kind=='record_measurement':
        require(len(d.get('measurements',[]))<500,'Лимит наблюдений проекта.')
        entry={k:amount(payload.get(k)) for k in ('beforeSeconds','afterSeconds','correctionSeconds','manualSeconds')}
        require(entry['beforeSeconds']>0 and entry['afterSeconds']>0,'Основное время должно быть положительным.')
        require(type(payload.get('success')) is bool,'Укажите результат проверки.')
        entry.update(id=uid(),task=text(payload.get('task'),1000,2),evidence=text(payload.get('evidence',''),2000),success=payload['success'],at=now())
        d.setdefault('measurements',[]).append(entry);result=metrics(d)
    elif kind=='simulate': result={'checks':simulation(d),'externalVerification':False,'at':now()}
    elif kind=='complete_task':
        require(any(t['id']==payload.get('taskId') for t in d['tasks']),'Задача не найдена.')
        for t in d['tasks']:
            if t['id']==payload['taskId']:t['done']=True
        result={'taskId':payload['taskId'],'status':'completed'}
    elif kind=='record_cost':
        require(d['accepted'],'Сначала примите контракт результата.')
        value=amount(payload.get('amountMinor'));require(value>0,'Сумма должна быть положительной.')
        require(payload.get('category') in CATEGORIES,'Неизвестная категория расходов.')
        require(sum(c['amountMinor'] for c in d['costs'])+value<=d['budgetMinor'],'Расход превысит бюджет. Измените контракт и примите его заново.','budget_exceeded',409)
        entry=dict(id=uid(),amountMinor=value,category=payload['category'],note=text(payload.get('note',''),1000,2),at=now())
        require(len(d['costs'])<500,'Достигнут лимит записей расходов.')
        d['costs'].append(entry);result=entry
    elif kind=='create_order':
        require(d['consents']['business'] and 'prepare_offer' in d['allowedActions'],'Разрешите подготовку предложения и передачу контекста Business.')
        require(d['offer']['title'] and d['offer']['scope'] and d['offer']['customer'] and d['offer']['amountMinor']>0,'Заполните предложение, покупателя, состав и стоимость.')
        require(d['accepted'],'Сначала примите контракт.')
        require(len(d['orders'])<100,'Достигнут лимит черновиков заказов.')
        entry=dict(id=uid(),status='draft',amountMinor=d['offer']['amountMinor'],currency=d['currency'],title=d['offer']['title'],customer=d['offer']['customer'],scope=d['offer']['scope'],at=now())
        d['orders'].append(entry);result=entry
    elif kind=='cancel_order':
        target=next((o for o in d['orders'] if o['id']==payload.get('orderId')),None)
        require(target is not None and target['status']=='draft','Черновик не найден или уже отменён.')
        target['status']='cancelled';result=target
    elif kind=='release':
        checks=simulation(d);require(all(c['passed'] for c in checks),'Предварительная проверка не пройдена.','checks_failed',409)
        require(len(d['releases'])<100,'Достигнут лимит внутренних выпусков.')
        entry=dict(id=uid(),at=now(),url=d['artifact']['url'],checksum=d['artifact']['checksum'],status='internal_review',assetId=d['artifact'].get('assetId',''),checks=checks)
        d['releases'].append(entry);result=entry
    else: raise Fault('unsupported_action','Это действие не подключено.',422)
    return d,result
