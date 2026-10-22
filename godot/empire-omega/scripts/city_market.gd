extends RefCounted
## Deterministic two-way market with price spread and per-turn anti-arbitrage cap.
## Trades affect public municipal inventory and treasury, never the player wallet.

const GOODS = ["grain", "materials", "goods"]
const BASE_PRICE = {"grain":8, "materials":13, "goods":18}
const TARGET_STOCK = {"grain":150, "materials":100, "goods":90}
const TRADE_UNIT = 10
const MAX_ORDERS_PER_TURN = 4
const MIN_BUY_PRICE = 5

static func price(state: Dictionary, product: String, buying: bool) -> int:
	if not BASE_PRICE.has(product):
		return -1
	var inventory: Dictionary = state.get("inventories",{})
	var stock: int = clampi(int(inventory.get(product,0)),0,100000)
	var target: int = int(TARGET_STOCK[product])
	# A shortage raises the price, a surplus gently lowers it.
	var scarcity: float = clampf(1.0 + float(target-stock) / float(target) * 0.50,0.65,1.55)
	var price_float: float = float(BASE_PRICE[product]) * scarcity
	# A strict spread means repeated buy/sell can never mint money.
	return maxi(MIN_BUY_PRICE,ceili(price_float * (1.18 if buying else 0.73)))

static func quote(state: Dictionary, product: String, buying: bool, quantity: int = TRADE_UNIT) -> Dictionary:
	if not GOODS.has(product) or quantity <= 0 or quantity > 100:
		return {}
	var orders: int = int(state.get("market_orders",0))
	var stock: int = int(state.get("inventories",{}).get(product,0))
	var unit_price: int = price(state,product,buying)
	var total: int = unit_price * quantity
	return {"product":product,"buy":buying,"quantity":quantity,"unit":unit_price,"total":total,
		"allowed":orders < MAX_ORDERS_PER_TURN and ((int(state.get("treasury",0)) >= total and stock + quantity <= 100000) if buying else stock >= quantity)}
