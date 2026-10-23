# NEBULA → MAGA UK Stripe: безопасный ввод реальных платежей

Статус на 23 октября 2026 года: **код Checkout готовится в PR, LIVE НЕ ВКЛЮЧЁН**.
Связь ChatGPT ↔ Stripe для MAGA выдаёт ошибку `link_id must identify an eligible linked account`.
Никаких живых списаний или переводов на MAGA из этой разработки не выполнено.

## 1. Подключение и проверка получателя денег

1. В ChatGPT → Settings → Plugins → Stripe переподключить *именно* MAGA
   с разрешениями владельца или официально назначенного члена команды.
2. В [Stripe Dashboard](https://dashboard.stripe.com/) выбрать MAGA,
   убедиться, что аккаунт британский, доступен live-режим, разрешены
   **Charges** и **Payouts**, а банковские реквизиты получения средств
   принадлежат уполномоченному бизнесу.
3. Сверить публичный идентификатор `acct_...` из MAGA со значением
   `OSGARD_NEBULA_STRIPE_ACCOUNT_ID`. Сам ID не является секретом.
4. Если аккаунт принадлежит другому человеку/компании, администратор должен
   явно предоставить разрешение принимать платежи на этот бизнес.
   Нельзя использовать чужой аккаунт для обхода ограничений Stripe или
   указывать фиктивного бенефициара/страну регистрации.

Без этих пунктов live-касса остаётся выключенной.

## 2. Безопасные серверные ключи

Создать отдельный **live restricted API key** для NEBULA (минимальные права
Checkout Sessions creation/retrieval, PaymentIntents/Charges read и Account read).
Нужен отдельный **webhook signing secret** (`whsec_...`) для этого endpoint.

**Ни один ключ не вставлять в HTML, Godot, GitHub, чат, логи или скриншоты.**

На VPS подготовить папку, доступную только root и группе контейнера Core API
(группа процесса `10001`); файлы должны быть доступны для чтения UID 10001:
`/etc/osgard/nebula-secrets/stripe-api-key` и
`/etc/osgard/nebula-secrets/stripe-webhook-secret`.

Пример отдельного private Compose override приведён в
`docs/nebula-maga-compose.example.yml`. Не хранить боевые ключи в этом файле.
Смонтировать закрытую папку `/etc/osgard/nebula-secrets` только в контейнер
`core-api`, read-only, без публикации порта контейнера.

Переменные окружения Core API:

| Имя | Значение |
| --- | --- |
| `OSGARD_NEBULA_PAYMENTS_ENABLED` | `1` **только после всех проверок** |
| `OSGARD_NEBULA_STRIPE_ACCOUNT_ID` | Реальный `acct_...` MAGA |
| `OSGARD_NEBULA_STRIPE_LIVEMODE` | `1` |
| `OSGARD_NEBULA_PUBLIC_ORIGIN` | `https://osgard.world` |
| `OSGARD_NEBULA_STRIPE_KEY_FILE` | `/run/nebula/stripe-api-key` |
| `OSGARD_NEBULA_STRIPE_WEBHOOK_SECRET_FILE` | `/run/nebula/stripe-webhook-secret` |

Активация выключена по умолчанию (`0`), а при несовпадении account/mode
или недоступных приёме/выводе средств `VerifiedNebulaStripeProvider` отказывает.
Это предотвращает случайное списание средств в неправильном Stripe-аккаунте.

## 3. Webhook Stripe MAGA

В Workbench → Webhooks создать snapshot endpoint:

`https://osgard.world/api/core/nebula/webhook`

API version: **`2026-08-26.dahlia`** (или согласованная с кодом версия).

Подписаться на:
- `checkout.session.completed`
- `checkout.session.async_payment_succeeded`
- `checkout.session.async_payment_failed`
- `checkout.session.expired`
- `charge.refunded`
- `charge.dispute.created`

Webhook проверяет HMAC подпись, timestamp, live mode, MAGA account ID,
серверную сумму в GBP, SKU, order ID и PaymentIntent/Charge.
**Return URL не даёт предметы.**
Идемпотентная база SQLite выдаёт каждый товар только один раз и отзывает
права при возвратах или спорах. Платные ракеты расходуются через сервер.

## 4. Что продаётся

Серверный, неизменяемый клиентом каталог GBP:
- Vortex Interceptor — £7.99.
- Aegis Guardian — £13.99.
- Plasma Lance — £4.99.
- 6 Homing Missiles — £2.49.
- Escort Drone — £5.99.
- Ace Wingman — £10.99.
- Obsidian Skin — £3.99.
- Aurora Chrome — £4.99.
- Founder Hangar — £8.99.

Стоимость перед Checkout повторно определяется сервером; браузер не может
передать собственную цену или валюту. Товары одноразовые, кроме ракет.
Нужно подготовить публичные **условия продажи, описание лицензии, поддержку
покупателей, возвраты и политику конфиденциальности**. Продажи в Великобритании
и ЕС могут иметь обязательства по НДС/потребительскому законодательству.
Stripe Tax нельзя включать без подтверждённых налоговых регистраций.

## 5. Проверка и выпуск

1. Без ключей: `GET /api/core/nebula/catalog` возвращает
   `enabled: false`; сайт показывает каталог, но кнопки оплаты неактивны.
2. GitHub CI запускает mock Stripe webhook/HTTP-тесты: неверная подпись
   отклоняется; неподтверждённая оплата не выдаёт предметы; повтор события не
   удваивает товар; возврат/спор отзывает право; повторное списание ракет
   с тем же request key безопасно.
3. На отдельном тестовом аккаунте Stripe повторить успешный и отменённый
   Checkout, асинхронный платёж и возврат, затем настроить MAGA live.
4. После настройки секретов: проверить
   `https://osgard.world/api/core/health`
   и `https://osgard.world/api/core/nebula/catalog` на включённый
   режим `live`. Магазин: `/games/remix/arena-v2/nebula-3d/hangar.html`.
5. Выполнить контролируемую авторизованную оплату с реальной картой только
   с ведома плательщика, проверить событие, inventory и получение предмета
   в Godot; затем возврат и отзыв покупки.
6. Отдельно проверить банковские выплаты в **MAGA Stripe Dashboard**.
   Наличие успешного Checkout не равнозначно зачислению денег на банк.

Всё время сохранять резервную копию SQLite перед изменением production Core API.
Тестовый Sandbox и факт подключения аккаунта в ChatGPT сами по себе не
переносят Stripe ключи и webhook в VPS.
