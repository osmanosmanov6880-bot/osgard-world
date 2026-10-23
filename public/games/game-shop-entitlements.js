export async function osgardOwnedItems(token) {
 if (!token) throw Error('Нужен вход в OSGARD');
 const r=await fetch('/api/core/game-shop/owned',{headers:{Authorization:'Bearer '+token},cache:'no-store'});
 if (!r.ok) throw Error('Владение предметами не подтверждено сервером');
 return new Set((await r.json()).owned);
}
