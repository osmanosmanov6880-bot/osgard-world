extends Node
## R15 authenticated receipt sync. Payment rights come ONLY from OSGARD Core.
## The login token is held in tab sessionStorage by hangar.html, never in saves.
signal inventory_synced(items: Dictionary)
signal purchased_missile_authorized
signal sync_failed(detail: String)
var bearer_token: String = ""
var inventory: Dictionary = {}
var inventory_http: HTTPRequest
var consume_http: HTTPRequest
var sync_in_flight: bool = false
var consume_in_flight: bool = false
var web_enabled: bool = false

func _ready() -> void:
    web_enabled = OS.has_feature("web")
    inventory_http = HTTPRequest.new()
    inventory_http.name = "R15_ReceiptSyncRequest"
    inventory_http.timeout = 12.0
    add_child(inventory_http)
    inventory_http.request_completed.connect(_on_inventory_reply)
    consume_http = HTTPRequest.new()
    consume_http.name = "R15_ConsumeMissileRequest"
    consume_http.timeout = 12.0
    add_child(consume_http)
    consume_http.request_completed.connect(_on_consume_reply)
    if web_enabled:
        refresh_authorization()

func refresh_authorization() -> void:
    if not web_enabled:
        return
    var credential: Variant = JavaScriptBridge.eval(
        "window.sessionStorage.getItem('nebula_core_session_v1')", true)
    if typeof(credential) != TYPE_STRING:
        bearer_token = ""
        return
    bearer_token = str(credential)
    if bearer_token.length() >= 40:
        request_inventory()

func request_inventory() -> void:
    if bearer_token.length() < 40 or sync_in_flight:
        return
    var headers := PackedStringArray(["Authorization: Bearer " + bearer_token,
                                      "Accept: application/json"])
    var status: Error = inventory_http.request(
        "https://osgard.world/api/core/nebula/inventory", headers, HTTPClient.METHOD_GET)
    if status == OK:
        sync_in_flight = true
    else:
        sync_failed.emit("Сервер инвентаря временно недоступен")

func _on_inventory_reply(result: int, response_code: int,
                         _headers: PackedStringArray, raw: PackedByteArray) -> void:
    sync_in_flight = false
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        if response_code == 401:
            bearer_token = ""
            inventory.clear()
            inventory_synced.emit({})
        sync_failed.emit("Инвентарь не подтверждён сервером")
        return
    var body: Variant = JSON.parse_string(raw.get_string_from_utf8())
    if typeof(body) != TYPE_DICTIONARY or typeof(body.get("items")) != TYPE_DICTIONARY:
        sync_failed.emit("Некорректный ответ инвентаря")
        return
    inventory = body["items"]
    inventory_synced.emit(inventory.duplicate())

func buy_rocket_consumption() -> void:
    if bearer_token.length() < 40 or consume_in_flight:
        return
    var count: int = int(inventory.get("missiles_6", 0))
    if count <= 0:
        sync_failed.emit("Оплаченные ракеты закончились")
        return
    var request_key: String = "nebula_flight_" + str(Time.get_ticks_usec()) + "_" + str(randi_range(100000, 999999))
    var headers := PackedStringArray([
        "Authorization: Bearer " + bearer_token,
        "Accept: application/json",
        "Idempotency-Key: " + request_key,
    ])
    var status: Error = consume_http.request(
        "https://osgard.world/api/core/nebula/consume-missile",
        headers, HTTPClient.METHOD_POST)
    if status == OK:
        consume_in_flight = true
    else:
        sync_failed.emit("Не удалось подтвердить списание ракеты")

func _on_consume_reply(result: int, code: int,
                       _headers: PackedStringArray, raw: PackedByteArray) -> void:
    consume_in_flight = false
    if result != HTTPRequest.RESULT_SUCCESS or code != 200:
        sync_failed.emit("Сервер не подтвердил расход ракеты")
        return
    var body: Variant = JSON.parse_string(raw.get_string_from_utf8())
    if typeof(body) != TYPE_DICTIONARY or not bool(body.get("consumed",false)):
        sync_failed.emit("Недостаточно оплаченных ракет")
        return
    inventory["missiles_6"] = maxi(0, int(inventory.get("missiles_6",0)) - 1)
    purchased_missile_authorized.emit()
