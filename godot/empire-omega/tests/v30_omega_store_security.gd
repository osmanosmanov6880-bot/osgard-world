extends SceneTree
## No live Stripe/Supabase access needed: verify game UI is inert until credentials exist.
const SHOP = preload("res://scripts/omega_real_money_shop.gd")
const CONFIG = preload("res://scripts/omega_store_config.gd")
var checks: int = 0
var failures: int = 0

func verify(value: bool, label: String) -> void:
	checks += 1
	if value:
		print("OMEGA PAYMENTS GATE PASS: " + label)
	else:
		failures += 1
		push_error("OMEGA PAYMENTS GATE FAIL: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var shop := SHOP.new()
	root.add_child(shop)
	await process_frame
	verify(shop is CanvasLayer,"Shop actually instantiates in native Godot")
	verify(shop.background != null and not shop.background.visible,"Payment modal starts closed")
	verify(shop.open_button != null and shop.open_button.text.contains("МАГАЗИН"),"Discoverable real-money store button")
	verify(shop.http != null,"Native HTTPS transport exists")
	verify(shop.catalog.size()==3,"Exactly three one-time cosmetic products")
	verify(shop.owned.is_empty(),"Purchases cannot be invented without verified server")
	verify(shop.access_token.is_empty(),"No stored auth token shipped in client")
	verify(shop.pending_kind.is_empty(),"Never auto-opens checkout on game launch")
	verify(shop.merchant_name.is_empty(),"Do not claim an unverified seller")
	shop._purchase("founder_gold")
	verify(shop.pending_kind.is_empty(),"Checkout refuses requests without verified player")
	shop._equip("founder_gold")
	verify(shop.owned.is_empty(),"Client cannot self-grant a paid cosmetic via shop")
	for item in shop.catalog:
		verify(item.has("purchasable") and not bool(item["purchasable"]), "Staged GBP product is inactive by default")
	# No test card numbers or keys are embedded in the binary.
	verify(CONFIG.SUPABASE_URL.is_empty(),"No private project URL committed")
	verify(CONFIG.SUPABASE_PUBLISHABLE_KEY.is_empty(),"No private merchant or auth keys committed")
	shop.queue_free()
	await process_frame
	print("OMEGA STORE NATIVE: %d/%d" % [checks-failures,checks])
	quit(0 if failures==0 else 1)
