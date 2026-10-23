extends CanvasLayer
## Real-money cosmetic shop. Prices/ownership are SERVER authoritative.
## Passwordless Supabase OTP + Stripe hosted Checkout. No card data or secret in game.
const CFG = preload("res://scripts/omega_store_config.gd")
const DEFAULT_CATALOG = [
	{"sku":"crimson_paint","title":"Crimson GT Finish","amount_pence":299,"currency":"gbp","purchasable":false},
	{"sku":"aurora_paint","title":"Aurora GT Finish","amount_pence":499,"currency":"gbp","purchasable":false},
	{"sku":"founder_gold","title":"Founders Gold Finish","amount_pence":999,"currency":"gbp","purchasable":false}
]
const PAINTS = {
	"crimson_paint":Color("b52e38"),
	"aurora_paint":Color("39d5cc"),
	"founder_gold":Color("d4a53a")
}
var vehicle
var background: ColorRect
var open_button: Button
var status_label: Label
var merchant_label: Label
var email_field: LineEdit
var otp_field: LineEdit
var login_button: Button
var verify_button: Button
var refresh_button: Button
var product_column: VBoxContainer
var http: HTTPRequest
var pending_kind: String = ""
var busy: bool = false
var open: bool = false
var previous_mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var access_token: String = ""
var signed_in_email: String = ""
var catalog: Array = DEFAULT_CATALOG.duplicate(true)
var owned: Dictionary = {}
var merchant_name: String = ""
var terms_url: String = ""
var refund_url: String = ""
var last_response_code: int = 0

func _ready() -> void:
	layer = 45
	http = HTTPRequest.new()
	http.name = "VerifiedStoreHTTP"
	http.timeout = 18.0
	add_child(http)
	http.request_completed.connect(_on_request_done)
	_construct_gui()
	_display_catalog()
	if CFG.configured():
		_catalog()
	else:
		_status("Реальные платежи ещё НЕ АКТИВИРОВАНЫ. Требуется Live Stripe и сервер магазина.")

func bind_car(drivable) -> void:
	vehicle = drivable

func is_open() -> bool:
	return open

func _btn(text: String, root: Node, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0,43)
	button.pressed.connect(callback)
	root.add_child(button)
	return button

func _construct_gui() -> void:
	open_button = Button.new()
	open_button.text = "МАГАЗИН · £"
	open_button.custom_minimum_size = Vector2(176,42)
	open_button.anchor_left = 1.0
	open_button.anchor_right = 1.0
	open_button.offset_left = -198.0
	open_button.offset_right = -22.0
	open_button.offset_top = 18.0
	open_button.offset_bottom = 60.0
	open_button.pressed.connect(toggle)
	add_child(open_button)

	background = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025,0.04,0.07,.90)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.visible = false
	add_child(background)
	var middle := CenterContainer.new()
	middle.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.add_child(middle)
	var sheet := PanelContainer.new()
	sheet.custom_minimum_size = Vector2(625,680)
	middle.add_child(sheet)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",11)
	sheet.add_child(column)
	var heading := Label.new()
	heading.text = "OSGARD  ·  ПРЕМИУМ-ГАРАЖ"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",24)
	column.add_child(heading)
	var disclosure := Label.new()
	disclosure.text = "Косметические предметы за GBP. Оплата только на защищённой странице Stripe."
	disclosure.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(disclosure)
	merchant_label = Label.new()
	merchant_label.text = "Продавец: не подтверждён. Реальные платежи отключены."
	merchant_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(merchant_label)
	var legal_row := HBoxContainer.new()
	column.add_child(legal_row)
	_btn("Условия покупки",legal_row,_open_terms)
	_btn("Правила возврата",legal_row,_open_refunds)
	email_field = LineEdit.new()
	email_field.placeholder_text = "Email игрока — для покупки и восстановления доступа"
	email_field.custom_minimum_size = Vector2(0,42)
	column.add_child(email_field)
	login_button = _btn("1. Получить код входа по почте",column,_send_otp)
	otp_field = LineEdit.new()
	otp_field.placeholder_text = "2. Введите код из письма"
	otp_field.custom_minimum_size = Vector2(0,42)
	otp_field.max_length = 8
	column.add_child(otp_field)
	verify_button = _btn("Подтвердить email",column,_verify_otp)
	refresh_button = _btn("Обновить подтверждённые покупки",column,_fetch_entitlements)
	var separator := HSeparator.new()
	column.add_child(separator)
	var list_heading := Label.new()
	list_heading.text = "ПОКРАСКА АВТОМОБИЛЯ · ПОКУПАЕТСЯ НАВСЕГДА"
	column.add_child(list_heading)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(590,182)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	product_column = VBoxContainer.new()
	product_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(product_column)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = "Проверка подключения магазина..."
	column.add_child(status_label)
	_btn("ЗАКРЫТЬ / ВЕРНУТЬСЯ В ИГРУ",column,toggle)

func toggle() -> void:
	open = not open
	background.visible = open
	open_button.visible = not open
	if open:
		previous_mouse_mode = Input.get_mouse_mode()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(previous_mouse_mode)

func _status(message: String) -> void:
	if status_label != null:
		status_label.text = message

func _display_catalog() -> void:
	if product_column == null:
		return
	for node in product_column.get_children():
		node.queue_free()
	for record in catalog:
		if not (record is Dictionary):
			continue
		var sku: String = str(record.get("sku",""))
		if not PAINTS.has(sku):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",10)
		product_column.add_child(row)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "%s   £%.2f" % [str(record.get("title",sku)), float(record.get("amount_pence",0))/100.0]
		row.add_child(label)
		var purchase := Button.new()
		if owned.has(sku):
			purchase.text = "ПРИМЕНИТЬ"
			purchase.pressed.connect(_equip.bind(sku))
		else:
			purchase.text = "КУПИТЬ ЗА £"
			purchase.disabled = not bool(record.get("purchasable",false)) or access_token.is_empty()
			purchase.pressed.connect(_purchase.bind(sku))
		row.add_child(purchase)

func _headers(authenticated: bool) -> PackedStringArray:
	var headers := PackedStringArray([
		"content-type: application/json",
		"apikey: " + CFG.public_key()
	])
	if authenticated:
		headers.append("authorization: Bearer " + access_token)
	return headers

func _request(kind: String, url: String, method: int, payload: Dictionary, authenticated: bool=false) -> void:
	if busy:
		_status("Подождите завершения предыдущего запроса")
		return
	if not CFG.configured():
		_status("Оплата пока не подключена. Stripe Live и сервер должны быть активированы владельцем.")
		return
	if authenticated and access_token.is_empty():
		_status("Сначала подтвердите email")
		return
	busy = true
	pending_kind = kind
	var text: String = JSON.stringify(payload) if method != HTTPClient.METHOD_GET else ""
	var err: int = http.request(url,_headers(authenticated),method,text)
	if err != OK:
		busy = false
		pending_kind = ""
		_status("Сеть временно недоступна (%d)" % err)

func _open_terms() -> void:
	if terms_url.begins_with("https://"):
		OS.shell_open(terms_url)
	else:
		_status("Условия покупки пока не опубликованы. Оплата недоступна.")

func _open_refunds() -> void:
	if refund_url.begins_with("https://"):
		OS.shell_open(refund_url)
	else:
		_status("Правила возврата пока не опубликованы. Оплата недоступна.")

func _catalog() -> void:
	_request("catalog",CFG.shop_url("catalog"),HTTPClient.METHOD_GET,{})

func _send_otp() -> void:
	var email := email_field.text.strip_edges().to_lower()
	if email.length()<5 or email.length()>254 or email.find("@")<1 or email.find(" ")>=0:
		_status("Введите действительный email")
		return
	signed_in_email = email
	_request("send_otp",CFG.auth_url("otp"),HTTPClient.METHOD_POST,{"email":email,"create_user":true})
	_status("Запрашиваем одноразовый код. Его нельзя никому передавать.")

func _verify_otp() -> void:
	var code := otp_field.text.strip_edges()
	if signed_in_email.is_empty() or code.length()<6 or code.length()>8 or not code.is_valid_int():
		_status("Введите код из письма (6–8 цифр)")
		return
	_request("verify_otp",CFG.auth_url("verify"),HTTPClient.METHOD_POST,
		{"email":signed_in_email,"token":code,"type":"email"})

func _fetch_entitlements() -> void:
	_request("entitlements",CFG.shop_url("entitlements"),HTTPClient.METHOD_GET,{},true)

func _purchase(sku: String) -> void:
	if not PAINTS.has(sku) or access_token.is_empty():
		_status("Для оплаты сначала войдите в аккаунт")
		return
	_request("checkout",CFG.shop_url("checkout"),HTTPClient.METHOD_POST,{"sku":sku},true)
	_status("Проверяем цену и доступность Stripe Checkout...")

func _equip(sku: String) -> void:
	if not owned.has(sku) or not PAINTS.has(sku):
		_status("Этот предмет не подтверждён сервером")
		return
	if vehicle == null or vehicle.horizon_visual == null:
		_status("Автомобиль ещё не загружен")
		return
	var paint: Color = PAINTS[sku]
	vehicle.horizon_visual.call("set_paint",paint)
	var hero: Node = vehicle.get_node_or_null("R6HeroBody")
	if hero != null:
		hero.call("set_paint",paint)
	_status("Покраска применена. Покупка сохранена на сервере.")

func _on_request_done(result: int, status_code: int, _response_headers: PackedStringArray, body: PackedByteArray) -> void:
	var kind: String = pending_kind
	pending_kind = ""
	busy = false
	last_response_code = status_code
	if result != HTTPRequest.RESULT_SUCCESS:
		_status("Ошибка сети. Платёж НЕ выполнен.")
		return
	var decoded: Variant = JSON.parse_string(body.get_string_from_utf8())
	var info: Dictionary = decoded if decoded is Dictionary else {}
	if status_code < 200 or status_code >= 300:
		_status("Сервер: " + str(info.get("error",info.get("msg","Запрос не выполнен"))) + " (" + str(status_code) + ")")
		return
	match kind:
		"catalog":
			terms_url = str(info.get("terms_url",""))
			refund_url = str(info.get("refund_url",""))
			var items: Variant = info.get("items",[])
			if items is Array:
				catalog = items
			merchant_name = str(info.get("merchant_name",""))
			merchant_label.text = "Продавец: " + (merchant_name if not merchant_name.is_empty() else "ожидает верификации")
			_display_catalog()
			_status("Каталог загружен. Для покупки подтвердите email.")
		"send_otp":
			_status("Код входа отправлен. Проверьте email и папку Спам.")
		"verify_otp":
			access_token = str(info.get("access_token",""))
			otp_field.text = ""
			if access_token.is_empty():
				_status("Не получен токен входа, покупки недоступны")
			else:
				_status("Вы вошли. Загружаем купленные предметы...")
				_fetch_entitlements()
		"entitlements":
			owned.clear()
			var items: Variant = info.get("items",[])
			if items is Array:
				for item in items:
					if item is String and PAINTS.has(item):
						owned[item] = true
			_display_catalog()
			_status("Покупки подтверждены сервером: %d. После оплаты нажмите «Обновить»." % owned.size())
		"checkout":
			var link: String = str(info.get("url",""))
			if not link.begins_with("https://checkout.stripe.com/") and not link.begins_with("https://buy.stripe.com/"):
				_status("Checkout URL не подтверждён. Оплата не открыта.")
				return
			var opened: int = OS.shell_open(link)
			_status("Stripe Checkout " + ("открыт в браузере. После оплаты обновите покупки." if opened==OK else "не открылся; попробуйте повторно"))
