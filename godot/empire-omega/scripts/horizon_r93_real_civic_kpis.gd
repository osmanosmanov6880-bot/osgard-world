extends VBoxContainer
## EMPIRE Omega R93. Approved luxury information hierarchy, but all values
## strictly sourced from actual authoritative game state / economic forecast.
## No invented "security" or "ecology" ratings.
const GOLD := Color("d9bb83")
const TEXT := Color("eeeae3")
const MUTED := Color("c3c2bd")
var metric_values: Dictionary = {}

static func local(ru: String,en: String,zh: String,lang: String) -> String:
	if lang == "en": return en
	if lang == "zh": return zh
	return ru

func _line(label_text: String,id: String,value: int) -> void:
	var amount: int = clampi(value,0,100)
	metric_values[id] = amount
	var row := HBoxContainer.new()
	row.name = "R93_"+id
	row.add_theme_constant_override("separation",10)
	row.custom_minimum_size.y = 32
	add_child(row)
	var label_node := Label.new()
	label_node.text = label_text
	label_node.add_theme_color_override("font_color",MUTED)
	label_node.add_theme_font_size_override("font_size",15)
	label_node.custom_minimum_size.x = 108
	row.add_child(label_node)
	var bar := ProgressBar.new()
	bar.name = "R93Bar_"+id
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size.y = 13
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.tooltip_text = "%s · %d%%" % [label_text,amount]
	bar.min_value = 0
	bar.max_value = 100
	bar.value = amount
	bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color("252c35")
	track.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD if amount >= 55 else Color("ac7866")
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background",track)
	bar.add_theme_stylebox_override("fill",fill)
	row.add_child(bar)
	var number := Label.new()
	number.text = "%d%%" % amount
	number.custom_minimum_size.x = 52
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.add_theme_font_size_override("font_size",15)
	number.add_theme_color_override("font_color",TEXT)
	row.add_child(number)

func configure(state: Dictionary,forecast: Dictionary,lang: String) -> void:
	name = "R93ActualCityKPIs"
	add_theme_constant_override("separation",9)
	metric_values.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var metrics: Array = [
		["energy",local("Энергия","Energy","能源",lang),int(forecast.get("energy",state.get("energy",0)))],
		["water",local("Вода","Water","水源",lang),int(forecast.get("water",state.get("water",0)))],
		["food",local("Питание","Food","食品",lang),int(forecast.get("food",state.get("food",0)))],
		["roads",local("Дороги","Roads","道路",lang),int(state.get("road_quality",0))],
		["stability",local("Стабильность","Stability","稳定",lang),int(state.get("stability",0))]]
	for entry in metrics:
		_line(str(entry[1]),str(entry[0]),int(entry[2]))
