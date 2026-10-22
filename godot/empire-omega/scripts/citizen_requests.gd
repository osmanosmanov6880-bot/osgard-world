extends RefCounted
## Deterministic citizen petitions tied to actual city conditions; no AI/network calls.
const TOPICS = {
	"power":{"ru":"Дома остались без света. Нам нужна надёжная подстанция.","en":"Our homes are losing power. We need a reliable substation.","zh":"我们的家经常停电，需要可靠的变电站。"},
	"water":{"ru":"Напор воды падает. Можем ли мы получить помощь?","en":"Water pressure is falling. Can you help our neighborhood?","zh":"供水压力下降了，可以帮助我们吗？"},
	"jobs":{"ru":"В нашем квартале трудно найти работу. Что будет с семьями?","en":"It is hard to find jobs in this district. What happens to our families?","zh":"我们地区很难找到工作，家庭怎么办？"},
	"food":{"ru":"Цены на еду растут, а запасы магазинов пустеют.","en":"Food prices are rising and stores are running out.","zh":"食品价格上涨，商店的货架越来越空。"},
	"services":{"ru":"Нашему району нужны доступные городские службы.","en":"Our district needs more accessible city services.","zh":"我们社区需要更多公共服务。"},
	"community":{"ru":"Мы хотим, чтобы власти чаще нас слышали.","en":"We would like city officials to listen more often.","zh":"我们希望城市管理者更多地倾听居民的声音。"}
}
const LABELS = {
	"ru":{"title":"ОБРАЩЕНИЕ ЖИТЕЛЯ","listen":"Выслушать (бесплатно)","support":"Выделить 75 ₽ из бюджета","done":"Житель услышан","already":"Вы уже говорили с этим жителем в этом такте"},
	"en":{"title":"CITIZEN PETITION","listen":"Listen (free)","support":"Allocate 75 city ₽","done":"The resident was heard","already":"You already talked to this resident this turn"},
	"zh":{"title":"居民诉求","listen":"倾听（免费）","support":"拨款75城市卢布","done":"已经倾听居民诉求","already":"本回合已经与这位居民交流过"}
}

static func topic(state: Dictionary, citizen_id: int) -> String:
	if int(state["energy"]) < 55: return "power"
	if int(state["water"]) < 55: return "water"
	if int(state["food"]) < 55: return "food"
	if int(state.get("unemployment",0)) > 40: return "jobs"
	return "services" if posmod(citizen_id,3) == 0 else "community"

static func text(state: Dictionary, citizen_id: int, lang: String) -> String:
	var item: Dictionary = TOPICS[topic(state,citizen_id)]
	return str(item.get(lang,item["ru"]))
