/* RU/EN interface layer. Keeps original game state and mechanics independent of presentation. */
(()=>{
"use strict";
const persistence=window.RemixPersistence;
const dictionary={
 "Your verified Core account ID": "Ваш подтверждённый ID аккаунта Core",
 "Copy my Core ID": "Скопировать мой ID Core",
 "Invite one specific Core account to this match. Joining does not extend its running timer. Each account controls its own assigned player; this console is separate from Unity.": "Пригласите конкретный аккаунт Core в этот матч. Присоединение не продлевает его таймер. Каждый аккаунт управляет назначенным ему игроком; консоль работает отдельно от Unity.",
 "Participant invitations require a compatible account service.": "Для приглашений участников нужен совместимый сервис аккаунтов.",
 "Recipient Core account ID": "ID аккаунта Core получателя",
 "Invite this account": "Пригласить этот аккаунт",
 "Account invitation link": "Ссылка приглашения аккаунта",
 "Copy account invitation": "Скопировать приглашение аккаунта",
 "Check invitation": "Проверить приглашение",
 "Join this match": "Присоединиться к матчу",
 "Open joined match": "Открыть доступный матч",
 "Revoke pending invitation": "Отозвать непринятое приглашение",
 "Check saved invitation action": "Проверить сохранённое действие",
 "Open account matches": "Открыть матчи аккаунта",
 "Each account controls its assigned player. A second account needs an addressed invitation. Guest matches remain anonymous. Active simulation recovery and replay verification are not available.": "Каждый аккаунт управляет назначенным ему игроком. Второму аккаунту нужно адресное приглашение. Гостевые матчи остаются анонимными. Восстановление потерянной симуляции и проверка повторов недоступны.",
 "An invitation action is still unconfirmed. Check its saved operation before another action.": "Действие с приглашением пока не подтверждено. Проверьте сохранённую операцию перед новым действием.",
 "This account cannot use that invitation. Only its addressed recipient can join.": "Этот аккаунт не может использовать приглашение. Присоединиться может только указанный получатель.",
 "The invitation or saved action is not confirmed. No request will be repeated.": "Приглашение или сохранённое действие не подтверждено. Запрос не будет повторён.",
 "The invitation action is not confirmed. Its saved operation is retained; check it again without repeating the request.": "Действие с приглашением не подтверждено. Сохранённая операция остаётся доступна для проверки без повторной отправки запроса.",
 "The invitation is open at the last server check. Joining does not extend the match timer.": "При последней проверке сервис разрешал присоединение. Вход участника не продлевает таймер матча.",
 "The invitation is pending for its addressed recipient. Joining does not extend the match timer.": "Приглашение ожидает указанного получателя. Вход участника не продлевает таймер матча.",
 "This invitation cannot admit a participant now. Check the current match state.": "Сейчас присоединиться по этому приглашению нельзя. Проверьте состояние матча.",
 "The service confirmed this invitation was accepted.": "Сервис подтвердил принятие приглашения.",
 "This invitation was revoked. No participant was added.": "Приглашение отозвано. Участник не добавлен.",
 "This invitation is closed. A new match requires a separate action.": "Приглашение закрыто. Новый матч нужно создать отдельным действием.",
 "The second account slot is already occupied. This invitation did not add a participant.": "Место второго аккаунта уже занято. Это приглашение не добавило участника.",
 "The service rejected this invitation action. A new action is never automatic.": "Сервис отклонил действие с приглашением. Новое действие не выполняется автоматически.",
 "The service assigned your account to this match. Checking its current state…": "Сервис добавил ваш аккаунт в матч. Проверяем его текущее состояние…",
 "The invitation was revoked.": "Приглашение отозвано.",
 "The addressed invitation is saved. Copy its link for the intended account.": "Адресное приглашение сохранено. Скопируйте ссылку для указанного аккаунта.",
 "The service confirmed the action. Its recovery journal remains saved until this browser can store the active match.": "Сервис подтвердил действие. Журнал восстановления сохранён, пока браузер не сможет записать активный матч.",
 "Enter the other account’s verified Core ID. This form does not search for accounts.": "Введите подтверждённый ID другого аккаунта Core. Эта форма не выполняет поиск аккаунтов.",
 "A secure invitation operation key is unavailable.": "Не удалось создать безопасный ключ операции приглашения.",
 "Your verified Core ID was copied.": "Ваш подтверждённый ID Core скопирован.",
 "The addressed invitation link was copied. Only its recipient can join.": "Ссылка адресного приглашения скопирована. Присоединиться может только его получатель.",
 "Copy your Core account ID": "Скопируйте ID вашего аккаунта Core",
 "Copy the addressed invitation link": "Скопируйте ссылку адресного приглашения",
 "Invitations are addressed to a verified Core account ID. Opening a link never submits a join request.": "Приглашения адресуются подтверждённому ID аккаунта Core. Открытие ссылки не отправляет запрос присоединения.",
 "Participant invitations are disabled by this service. Existing account matches remain available.": "Сервис отключил приглашения участников. Существующие матчи аккаунта остаются доступны.",
 "This link does not contain a valid account invitation ID.": "В ссылке нет допустимого ID приглашения аккаунта.",
 "Opening an account-owned run. Its owner player is assigned by the service.": "Создаём матч аккаунта. Игрока владельца назначает сервис.",
 "SESSION ACCESS": "ДОСТУП К СЕССИИ",
 "Session access": "Доступ к сессии",
 "Guest / invite mode": "Гость / приглашение",
 "Account-owned matches": "Матчи аккаунта",
 "Choose account mode to verify your Core session.": "Выберите режим аккаунта, чтобы проверить сессию Core.",
 "Sign in and return to REMIX": "Войти и вернуться в REMIX",
 "Manage account access": "Управление аккаунтом",
 "Verify account again": "Проверить аккаунт снова",
 "Refresh account matches": "Обновить матчи аккаунта",
 "One account controls its assigned player. Other accounts cannot join this owned match. Guest matches remain anonymous. Active simulation recovery and replay verification are not available.": "Один аккаунт управляет назначенным ему игроком. Другие аккаунты не могут присоединиться к этому матчу. Гостевые матчи остаются анонимными. Восстановление потерянной симуляции и проверка повторов недоступны.",
 "Next page of account matches": "Следующая страница матчей",
 "Check pending creation": "Проверить создание матча",
 "Create a new public challenge": "Создать новое публичное испытание",
 "Saved account recovery is full. Check pending creations or restore existing matches before submitting more.": "Достигнут предел записей восстановления аккаунта. Проверьте незавершённое создание или восстановите существующие матчи перед новыми командами.",
 "Another creation is pending for this account. Check its recovery before starting another run.": "Для этого аккаунта уже ожидается создание матча. Проверьте его восстановление перед новым запуском.",
 "Account recovery storage is unavailable. Existing recovery records are retained; new commands and creations are paused.": "Хранилище восстановления аккаунта недоступно. Существующие записи сохранены; новые команды и создание матчей приостановлены.",
 "Account creation unavailable": "Создание матчей аккаунта недоступно",
 "Verify account to continue": "Сначала проверьте аккаунт",
 "Recover pending creation": "Восстановите создание матча",
 "Create another account run": "Создать следующий матч аккаунта",
 "Create account-owned run": "Создать матч аккаунта",
 "Sign in to your Core account, then verify it here. Protected matches remain account-owned.": "Войдите в Core и проверьте аккаунт здесь. Защищённые матчи остаются привязаны к аккаунту.",
 "Account verification is unavailable. Protected input is paused; your match remains account-owned.": "Проверка аккаунта недоступна. Управление приостановлено; матч остаётся привязан к аккаунту.",
 "This account cannot access that protected match. Choose a match from its own history.": "Этот аккаунт не имеет доступа к выбранному матчу. Выберите матч из его собственной истории.",
 "The account match service did not confirm this request. Your saved recovery record is retained.": "Сервис матчей аккаунта не подтвердил запрос. Запись для восстановления сохранена.",
 "Your account session changed. Verify the account again before using this protected match.": "Сессия аккаунта изменилась. Проверьте аккаунт снова перед продолжением защищённого матча.",
 "No account-owned matches were returned.": "Сервис не вернул матчей этого аккаунта.",
 "Restoring the account-owned match. Its player and submitted sequence come from the service.": "Восстанавливаем матч аккаунта. Игрок и номера отправленных команд проверяются по данным сервиса.",
 "The service recovered this account-owned creation. No create request was repeated.": "Сервис восстановил созданный матч аккаунта. Запрос создания не повторялся.",
 "The service rejected this creation. A new attempt requires a separate action.": "Сервис отклонил создание. Новая попытка требует отдельного действия.",
 "Creation remains unconfirmed. Check this same attempt again; no POST will be repeated.": "Создание пока не подтверждено. Проверьте эту же попытку ещё раз; запрос создания не повторится.",
 "No account-owned creation is confirmed for this attempt. Its request will not be repeated.": "Создание матча аккаунта для этой попытки не подтверждено. Запрос не будет повторён.",
 "Checking account access and service capabilities…": "Проверяем аккаунт и возможности сервиса…",
 "A different account is verified. Previous protected matches remain with their original account.": "Проверен другой аккаунт. Прежние защищённые матчи остаются у исходного владельца.",
 "Choose an account-owned match or create a separate run.": "Выберите матч аккаунта или создайте отдельный матч.",
 "Account match creation is disabled. You can view and recover existing account-owned matches.": "Создание матчей аккаунта отключено. Можно просматривать и восстанавливать уже существующие матчи.",
 "Guest mode is separate from account-owned matches.": "Гостевой режим работает отдельно от матчей аккаунта.",
 "Opening an account-owned run. Its single participant is assigned by the service.": "Создаём матч аккаунта. Его единственного участника назначает сервис.",
 "Account-owned match created. Checking its server state…": "Матч аккаунта создан. Проверяем его состояние на сервере…",
 "Account match creation needs saved recovery metadata. Enable browser storage before trying again.": "Для создания матча аккаунта нужно сохранить данные восстановления. Разрешите хранилище браузера перед новой попыткой.",
 "The public challenge was not confirmed. No account-owned match request was submitted.": "Публичное испытание не подтверждено. Запрос создания матча аккаунта не отправлялся.",
 "The owned record remains saved, but its active simulation is unavailable. This release cannot recover a lost simulation.": "Запись матча аккаунта сохранена, но активная симуляция недоступна. Этот выпуск не восстанавливает потерянную симуляцию.",
 "You are offline. Account-owned records remain saved; no create or input request will be repeated.": "Нет подключения к сети. Записи матчей аккаунта сохранены; запросы создания и команд не будут повторяться.",
 "Failed to fetch":"Нет связи с игровым сервисом. Проверьте подключение.",
 "OSGARD ENTERTAINMENT / 03": "OSGARD PLAY / 03",
 "One daily seed. One challenge link. Create a match, send inputs and compare the results returned by the match service.": "Ежедневное испытание и ссылка для друга. Создайте матч, отправляйте команды и сравнивайте результаты, полученные от сервиса.",
 "DAILY CHALLENGE / SERVER-RECORDED RESULTS": "ИСПЫТАНИЕ ДНЯ / ПОДТВЕРЖДЕНИЕ СЕРВЕРОМ",
 "Open challenge console ↗": "Открыть консоль испытаний ↗",
 "Unity build status ↗": "Статус Unity-сборки ↗",
 "The loop": "Как устроено испытание",
 "01 / CREATE": "01 / СОЗДАЙТЕ",
 "Shape a challenge": "Создайте испытание",
 "Create a daily challenge and open its match in the console.": "Создайте испытание дня и откройте его матч в консоли.",
 "02 / PLAY": "02 / ПРОЙДИТЕ",
 "Enter the match": "Начните матч",
 "The service reports the countdown, match state and position after accepted inputs.": "Сервис сообщает обратный отсчёт, состояние матча и позицию после принятых команд.",
 "03 / REMIX": "03 / ПОДЕЛИТЕСЬ",
 "Save the result": "Сохраните результат",
 "Request a result recorded by the match service, then share the challenge link with a friend.": "Получите результат от игрового сервиса и отправьте другу ссылку на испытание.",
 "The console shows position and results from the match service. The separate Unity build is currently unavailable.": "Консоль показывает позицию и результаты из ответов сервиса матчей. Отдельная Unity-сборка сейчас недоступна.",
 "04 / GROWTH + REVENUE": "04 / ПАРТНЁРАМ",
 "Invite a rival.": "Пригласите соперника.",
 "Open a sponsor slot.": "Создайте совместное испытание.",
 "The daily seed gives players a reason to return; the challenge link gives them a concrete reason to invite someone; a result screen can introduce a clearly labelled sponsor only after the run ends. Sponsorship is by inquiry until a real campaign is contracted.": "Испытание дня даёт новый повод зайти, а ссылка — пригласить друга. Партнёрское размещение обсуждается отдельно и может появиться только после прохождения. Действующая рекламная кампания не заявляется.",
 "Sponsor a challenge series ↗": "Обсудить серию испытаний ↗",
 "LIVE MATCH CONSOLE": "КОНСОЛЬ ИСПЫТАНИЙ",
 "Ready to enter": "Готовы начать?",
 "The daily challenge uses a shared UTC seed. Create a run, then send the invite link to a friend.": "Условия испытания одинаковы в течение дня по UTC. Создайте матч, затем отправьте другу ссылку.",
 "API URL": "Адрес игрового сервиса",
 "Create daily challenge": "Создать испытание дня",
 "Local input preview": "Поле управления консоли, не изображение Unity",
 "Server input preview, separate from the Unity game": "Позиция из ответа игрового сервиса, отдельно от игры Unity",
 "Position appears after the service accepts an input.": "Позиция появится, когда сервис подтвердит команду.",
 "Waiting for the service": "Ожидаем игровой сервис",
 "Opening challenge…": "Открываем испытание…",
 "Result received": "Результат получен",
 "Start a new match": "Начать новый матч",
 "Start this challenge": "Начать это испытание",
 "Reconnect to this match": "Восстановить связь с матчем",
 "Waiting for players": "Ожидаем игроков",
 "Countdown": "Обратный отсчёт",
 "Match running": "Матч идёт",
 "Run finished": "Прохождение завершено",
 "DAILY CHALLENGE": "ИСПЫТАНИЕ ДНЯ",
 "SERVER RESULT": "РЕЗУЛЬТАТ СЕРВЕРА",
 "SEED": "КОД УСЛОВИЙ",
 "CHALLENGE": "ИСПЫТАНИЕ",
 "MATCH": "МАТЧ",
 "CAN YOU BEAT THIS?": "СМОЖЕТЕ ПРОЙТИ ЛУЧШЕ?",
 "Server result · no input frames were recorded.": "Результат сервера · ни одна команда не была принята.",
 "Open a new daily challenge": "Открыть новое испытание дня",
 "This shared challenge is no longer available. Open a new daily challenge to continue.": "Испытание по приглашению больше недоступно. Чтобы продолжить, откройте новое испытание дня.",
 "This invitation does not contain a valid challenge ID. Open a new daily challenge to continue.": "В приглашении указан неверный номер испытания. Чтобы продолжить, откройте новое испытание дня.",
 "The old challenge is no longer available. Create a new daily challenge.": "Прошлое испытание больше недоступно. Создайте новое испытание дня.",
 "This is the match service response. An immutable replay archive has not been verified.": "Это ответ сервиса матчей. Неизменяемый архив повторов пока не проверен.",
 "Use a secure, compatible match-service address without a query or password.": "Укажите HTTPS-адрес совместимого игрового сервиса без пароля и параметров запроса.",
 "Match created. Checking the server state…": "Матч создан. Проверяем его состояние…",
 "The creation response was lost. A match may exist on the service. Starting a new match is a separate action.": "Ответ на создание не получен. Матч мог появиться на сервере. Кнопка ниже создаст новый матч; автоматического повтора не будет.",
 "You are offline. The saved match will reconnect when the connection returns.": "Нет подключения к сети. Связь с сохранённым матчем восстановится, когда сеть появится.",
 "The run ended. Fetching its server result…": "Матч завершён. Получаем результат от сервера…",
 "The match is running. Focus the field or use the buttons to submit input.": "Матч идёт. Выберите поле или используйте кнопки, чтобы отправлять команды.",
 "The service is preparing the match. Controls unlock when play begins.": "Сервис готовит матч. Управление станет доступно после начала игры.",
 "The service cannot find this saved match. Retry its lookup or create another match.": "Сервис не нашёл сохранённый матч. Проверьте его ещё раз или создайте другой.",
 "The result has not loaded yet. Your match is retained; reconnecting…": "Результат пока не загрузился. Данные матча сохранены; восстанавливаем связь…",
 "Connection lost. Your match is retained; reconnecting…": "Связь потеряна. Данные матча сохранены; подключаемся снова…",
 "This session cannot accept more inputs. Reconnect to view its result.": "Команды для этой сессии больше недоступны. Восстановите связь, чтобы увидеть результат.",
 "This input was not confirmed. It will not be sent again. Reconnecting to the match…": "Команда не подтверждена и не будет отправлена повторно. Восстанавливаем связь с матчем…",
 "The local session record is invalid or expired. You can start a new challenge.": "Запись сессии на устройстве повреждена или устарела. Можно начать новое испытание.",
 "A challenge is saved. Start its match when you are ready.": "Испытание сохранено. Начните матч, когда будете готовы.",
 "Restoring the saved match. The service will verify its current state and result.": "Восстанавливаем сохранённый матч. Сервис проверит его состояние и результат.",
 "CHALLENGE PASSPORT": "КАРТОЧКА ИСПЫТАНИЯ",
 "Awaiting server ID": "Ожидаем номер от сервера",
 "Use this link to challenge a friend to the same ruleset. Only the server result is presented as a result.": "Ссылка приглашает друга пройти те же правила. Результат считается подтверждённым после ответа сервера.",
 "Shareable challenge URL": "Ссылка для приглашения друга",
 "Share challenge ↗": "Поделиться испытанием ↗",
 "Copy invite link": "Скопировать ссылку",
 "Run this challenge again ↻": "Пройти ещё раз ↻",
 "Share result card ↗": "Поделиться карточкой ↗",
 "Download result card PNG ↓": "Скачать карточку PNG ↓",
 "PARTNER SLOT / INQUIRY ONLY": "ПАРТНЁРАМ / ОБСУЖДЕНИЕ",
 "A brand can sponsor the next challenge.": "Следующее испытание можно создать с партнёром.",
 "This is a commercial inquiry link, not a live ad. It appears after the result, never over active controls. No sponsor campaign is currently represented as active.": "Ссылка ведёт к обсуждению партнёрства и появляется после результата. Действующая рекламная кампания не подключена.",
 "Discuss a sponsored challenge ↗": "Обсудить партнёрское испытание ↗",
 "Opening a server-owned daily challenge...": "Запрашиваем испытание у игрового сервиса…",
 "The challenge service returned no challenge ID.": "Сервис не вернул номер испытания.",
 "The match service returned no match ID.": "Сервис не вернул номер матча.",
 "Shared challenge accepted by the match service. Use arrow keys or WASD.": "Сервис принял приглашение. На поле: A/D или ←/→; W, ↑ или пробел — прыжок.",
 "Match created. Use arrow keys or WASD to submit input.": "Матч создан. На поле: A/D или ←/→; W, ↑ или пробел — прыжок.",
 "Match active": "Матч идёт",
 "Retry shared challenge": "Повторить подключение",
 "Retry daily challenge": "Попробовать снова",
 "Unknown error": "Неизвестная ошибка",
 "FRIEND CHALLENGE / SERVER CHECK": "ИСПЫТАНИЕ ДРУГА / ПРОВЕРКА СЕРВЕРОМ",
 "FRIEND CHALLENGE / PENDING SERVER VALIDATION": "ИСПЫТАНИЕ ДРУГА / ОЖИДАЕТ ПРОВЕРКИ",
 "Finish a server-recorded run first.": "Сначала завершите матч и получите подтверждённый результат.",
 "Result card downloaded. Share the challenge link so a friend can run the same seed.": "Карточка скачана. Отправьте другу ссылку, чтобы он прошёл те же условия.",
 "Result card downloaded. It identifies the server match. Send the challenge invitation separately.": "Карточка скачана. В ней указан номер матча на сервере. Ссылку-приглашение отправьте отдельно.",
 "The share sheet opened. Share delivery depends on the target app.": "Окно отправки открыто. Дальнейшая отправка зависит от выбранного приложения.",
 "This browser cannot share files directly. The PNG card was downloaded instead.": "Браузер не поддерживает прямую отправку файлов. Карточка PNG скачана.",
 "Create or accept a challenge first.": "Сначала создайте испытание или примите приглашение.",
 "Invite link copied. Send it to a friend who can open the same challenge.": "Ссылка скопирована. Отправьте её другу.",
 "Share sheet opened. The recipient still needs to open the link and start the challenge.": "Окно отправки открыто. Получателю нужно открыть ссылку и начать испытание.",
 "Create another match": "Создать следующий матч",
 "Ready to run this same challenge again.": "Готово к повторному прохождению.",
 "A friend shared a challenge. Accept it to ask the match service to validate and start it.": "Вас пригласили в испытание. Примите приглашение, чтобы сервис проверил его и создал матч.",
 "Accept shared challenge": "Принять приглашение",
 "Server returned the result. Challenge a friend to compare this same ruleset.": "Сервер вернул результат. Предложите другу пройти те же условия.",
 "The match service is unavailable. Try again later.": "Игровой сервис недоступен. Попробуйте позже.",
 "The match service rejected this request.": "Игровой сервис отклонил запрос.",
 "The match service returned an invalid response.": "Сервис вернул ответ в неверном формате.",
 "The match service took too long to respond.": "Сервис не ответил вовремя. Повторите попытку.",
 "Enter the REMIX API URL first": "Укажите адрес сервиса в дополнительных настройках.",
 "Copy the challenge invite link": "Скопируйте ссылку-приглашение",
 "Before you start": "Перед запуском",
 "The Unity build is currently unavailable. The console below connects to the match service and displays its responses.": "Unity-сборка сейчас недоступна. Консоль ниже подключается к сервису матчей и показывает его ответы.",
 "Save and online: match results require the REMIX service. Page loading does not confirm an online match or a saved result.": "Сохранение и онлайн: результат матча подтверждает сервис REMIX. Открытая страница ещё не означает работающий онлайн или сохранённый результат.",
 "Console controls: focus its field and use A/D or left/right; W, up or Space jumps. Touch buttons are also available.": "Управление консолью: выберите поле, A/D или ←/→ — движение; W, ↑ или пробел — прыжок. Можно использовать экранные кнопки.",
 "Advanced connection settings": "Дополнительные настройки подключения",
 "Keep the default address unless you run your own compatible match service.": "Оставьте адрес по умолчанию, если вы не используете собственный совместимый игровой сервис.",
 "Console controls: focus the field or use the buttons below. A/D or arrows moves; W, up or Space jumps.": "Управление консолью: выберите поле или используйте кнопки ниже. A/D или ←/→ — движение; W, ↑ или пробел — прыжок.",
 "← Left": "← Влево",
 "Jump ↑": "Прыжок ↑",
 "Right →": "Вправо →",
 "Preferences cannot be saved in this browser. You can still play while this page is open.": "Браузер не сохраняет настройки. На открытой странице можно продолжить игру.",
 "This browser cannot save session recovery. Keep this page open; reloading may lose access to this match.": "Браузер не сохраняет данные для восстановления сессии. Оставьте страницу открытой: после перезагрузки доступ к этому матчу может потеряться."
};

const chinese={
 "OSGARD ENTERTAINMENT / 03": "OSGARD 娱乐 / 03",
 "One daily seed. One challenge link. Create a match, send inputs and compare the results returned by the match service.": "每天一条赛道，一条挑战链接。创建比赛、提交操作，并比较比赛服务确认的结果。",
 "DAILY CHALLENGE / SERVER-RECORDED RESULTS": "每日挑战 / 服务器记录的成绩",
 "Open challenge console ↗": "打开比赛控制台 ↗",
 "Unity build status ↗": "Unity 构建状态 ↗",
 "The loop": "玩法",
 "01 / CREATE": "01 / 创建",
 "Shape a challenge": "创建挑战",
 "Create a daily challenge and open its match in the console.": "创建每日挑战并在控制台中打开比赛。",
 "02 / PLAY": "02 / 游玩",
 "Enter the match": "进入比赛",
 "The service reports the countdown, match state and position after accepted inputs.": "服务器返回倒计时、比赛状态和位置。",
 "03 / REMIX": "03 / 再次挑战",
 "Save the result": "记录成绩",
 "Request a result recorded by the match service, then share the challenge link with a friend.": "获取服务器记录的结果，然后分享挑战链接。",
 "The console shows position and results from the match service. The separate Unity build is currently unavailable.": "控制台显示服务器位置及结果。独立 Unity 构建目前不可用。",
 "Before you start": "开始之前",
 "The Unity build is currently unavailable. The console below connects to the match service and displays its responses.": "Unity 构建目前不可用。下方控制台连接比赛服务并显示响应。",
 "LIVE MATCH CONSOLE": "在线比赛控制台",
 "Ready to enter": "准备开始",
 "Create daily challenge": "创建每日挑战",
 "Create or accept a challenge first.": "请先创建或接受挑战。",
 "Guest / invite mode": "访客 / 邀请模式",
 "Account-owned matches": "账号专属比赛",
 "Session access": "比赛权限",
 "SESSION ACCESS": "比赛权限",
 "Match running": "比赛进行中",
 "Waiting for the service": "正在等待服务器",
 "Start a new match": "开始新比赛",
 "Start this challenge": "开始挑战",
 "Result received": "已收到结果",
 "Download result card PNG ↓": "下载成绩卡 PNG ↓",
 "Share challenge ↗": "分享挑战 ↗",
 "Copy invite link": "复制邀请链接",
 "Run this challenge again ↻": "重新挑战 ↻",
 "← Left": "← 向左",
 "Right →": "向右 →",
 "Jump ↑": "跳跃 ↑",
 "The match service is unavailable. Try again later.": "比赛服务不可用，请稍后重试。",
 "The match service rejected this request.": "服务器拒绝了此次请求。",
 "The match service returned an invalid response.": "服务器返回的数据格式不正确。",
 "The match service took too long to respond.": "服务器响应超时。",
 "Advanced connection settings": "高级连接设置",
 "Keep the default address unless you run your own compatible match service.": "除非使用自己的兼容服务，否则请保留默认地址。",
 "Open a new daily challenge": "打开新每日挑战",
 "A brand can sponsor the next challenge.": "品牌可以赞助下一场挑战。",
 "04 / GROWTH + REVENUE": "04 / 增长与收益",
 "Invite a rival.": "邀请对手。",
 "Open a sponsor slot.": "开启赞助合作。",
 "Sponsor a challenge series ↗": "赞助系列挑战 ↗",
 "The daily challenge uses a shared UTC seed. Create a run, then send the invite link to a friend.": "每日挑战使用统一 UTC 编号。创建比赛后，可向好友发送邀请链接。",
 "The service is preparing the match. Controls unlock when play begins.": "服务器正在准备比赛，开始后将解锁操作。",
 "Console controls: focus its field or use the buttons below. A/D or arrows moves; W, up or Space jumps.": "控制台操作：点击场地，A/D 或方向键移动；W、上方向键或空格跳跃。",
 "Preferences cannot be saved in this browser. You can still play while this page is open.": "此浏览器无法保存设置。当前页面仍可继续使用。"
};
const originals=new WeakMap(),attributes=new WeakMap();
let ready=false,locale='ru';
try{const requested=new URLSearchParams(location.search).get('lang');locale=['ru','en','zh'].includes(requested)?requested:['ru','en','zh'].includes(persistence?.getItem('osgard:game-language'))?persistence.getItem('osgard:game-language'):'ru'}catch{}
const dynamic=[];
function t(value){
 const raw=String(value??''),key=raw.replace(/\s+/g,' ').trim();
 const source=ephemeralText(key);
 if(locale==='en')return source===key?raw:source;
 if(locale==='zh'){const translated=chinese[source];if(translated!==undefined)return translated; /* use existing Russian dictionary as fallback for unlocalized dynamic text */}
 let translated=dictionary[source];
 if(translated===undefined){for(const [pattern,render] of dynamic){const match=source.match(pattern);if(match){translated=render(...match.slice(1));break}}}
 return translated===undefined?raw:(raw.match(/^\s*/)?.[0]||'')+translated+(raw.match(/\s*$/)?.[0]||'');
}
function textNode(node){
 const parent=node.parentElement;if(!parent||parent.closest('script,style,noscript,[data-locale-tools],[data-no-translate]'))return;
 let state=originals.get(node);if(!state||node.nodeValue!==state.rendered)state={source:node.nodeValue,rendered:node.nodeValue};
 const rendered=t(state.source);if(node.nodeValue!==rendered)node.nodeValue=rendered;
 originals.set(node,{source:state.source,rendered});
}
function element(node){
 if(!node.getAttribute||node.closest?.('script,style,[data-locale-tools],[data-no-translate]'))return;
 let saved=attributes.get(node)||{};
 for(const name of ['aria-label','title','placeholder']){if(!node.hasAttribute(name))continue;const current=node.getAttribute(name);const before=saved[name];const source=before&&current===before.rendered?before.source:current;const rendered=t(source);if(current!==rendered)node.setAttribute(name,rendered);saved[name]={source,rendered}}
 attributes.set(node,saved);
}
function apply(root=document.body){
 if(!root)return;if(root.nodeType===3){textNode(root);return}element(root);
 const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);let node;while((node=walker.nextNode()))textNode(node);
 root.querySelectorAll?.('[aria-label],[title],[placeholder]').forEach(element);
}
function setLanguage(value){
 locale=['ru','en','zh'].includes(value)?value:'ru';persistence?.setItem('osgard:game-language',locale);
 document.documentElement.lang=locale;
 try{const url=new URL(location.href);url.searchParams.set('lang',locale);history.replaceState(null,'',url.href)}catch{}
 if(ready){window.RemixSession?.syncControls();apply();updateStorage();window.dispatchEvent(new Event('remix:language'));document.querySelectorAll('[data-game-language]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.gameLanguage===locale)))}
}
function languageTools(){
 const bar=document.createElement('div');bar.className='game-language';bar.dataset.localeTools='';bar.setAttribute('role','group');bar.setAttribute('aria-label','Язык / Language');
 for(const [code,label] of [['ru','Русский'],['en','English'],['zh','中文']]){const button=document.createElement('button');button.type='button';button.textContent=label;button.dataset.gameLanguage=code;button.setAttribute('aria-pressed',String(locale===code));button.addEventListener('click',()=>setLanguage(code));bar.appendChild(button)}return bar;
}
function watch(){
 const observer=new MutationObserver(records=>{for(const record of records){if(record.type==='characterData')textNode(record.target);else if(record.type==='attributes')element(record.target);else record.addedNodes.forEach(node=>apply(node))}});
 observer.observe(document.body,{subtree:true,childList:true,characterData:true,attributes:true,attributeFilter:['aria-label','title','placeholder']});
}

dynamic.push(
 [/^Assigned accounts · ([12]) \/ 2$/,count=>'Назначенных аккаунтов: '+count+' / 2'],
 [/^Addressed Core ID · (.+)$/,id=>'ID аккаунта получателя: '+id],
 [/^Invitation (.+) · (pending|accepted|revoked|expired|match_closed) · Match (.+)$/,(id,state,match)=>'Приглашение '+id+' · '+({pending:'ожидает принятия',accepted:'принято',revoked:'отозвано',expired:'истекло',match_closed:'матч завершён'})[state]+' · матч '+match],
 [/^Verified account: (.+)$/,name=>'Проверенный аккаунт: '+name],[/^Recover match (.+)$/,id=>'Восстановить матч '+id],
 [/^(Connection error|State error|Input error|Card export unavailable|Result-card sharing unavailable): (.+)$/,(kind,value)=>({'Connection error':'Ошибка подключения','State error':'Ошибка состояния','Input error':'Команда не отправлена','Card export unavailable':'Не удалось скачать карточку','Result-card sharing unavailable':'Не удалось отправить карточку'})[kind]+': '+t(value)],
 [/^Match (.+)$/,id=>'Матч '+id],[/^Friend challenge (.+)$/,id=>'Испытание друга '+id],
 [/^CHALLENGE \/ (.+)$/,id=>'ИСПЫТАНИЕ / '+id],[/^DAILY CHALLENGE \/ (.+)$/,date=>'ИСПЫТАНИЕ ДНЯ / '+date],
 [/^Seed (\d+) · Share this link to let a friend enter the same challenge\. The match API must accept the shared challenge before it starts\.$/,seed=>'Код условий: '+seed+'. Отправьте ссылку другу. Для запуска сервис должен подтвердить приглашение.'],
 [/^Invitation seed (\d+) · This number comes from the link or browser record\. The service must accept the challenge ID before play\.$/,seed=>'Код из приглашения: '+seed+'. Число взято из ссылки или записи браузера. Перед игрой сервис должен принять номер испытания.'],
 [/^Server result · score (.+)$/,score=>'Подтверждённый результат · очки: '+score],
 [/^Server result · (.+)$/,score=>'Подтверждённый результат · '+score.replace(/\bYou\b/g,'Вы').replace(/\bPlayer (\d+)/g,'Игрок $1')],[/^RESULTS · (.+)$/,score=>'РЕЗУЛЬТАТ · '+t(score)],
 [/^(\d+) player\(s\) · (\d+) accepted input frames$/,(players,frames)=>'Игроков: '+players+' · принятых команд: '+frames],
 [/^(\d+) s left in this phase$/,seconds=>'Осталось в этой фазе: '+seconds+' с'],
 [/^Server position · X ([-\d.]+) · Y ([-\d.]+)$/,(x,y)=>'Позиция на сервере · X '+x+' · Y '+y],
 [/^(.+) · (\d+) player\(s\) · (\d+) replay frames$/,(phase,players,frames)=>(({'WAITING':'Ожидание','COUNTDOWN':'Обратный отсчёт','PLAYING':'Матч идёт','RUNNING':'Матч идёт','RESULTS':'Результаты'})[phase]||phase)+' · игроков: '+players+' · кадров повтора: '+frames]
);
function ephemeralText(key){return key}
function updateStorage(){const node=document.querySelector('#remix-storage-state');if(node){node.hidden=!persistence?.ephemeral;node.textContent=t('This browser cannot save session recovery. Keep this page open; reloading may lose access to this match.')}}
function init(){
 ready=true;document.documentElement.lang=locale;
 const hero=document.querySelector('.hero'),tools=languageTools();hero.insertAdjacentElement('beforebegin',tools);
 const guide=document.createElement('aside');guide.className='remix-guide';guide.innerHTML='<strong>Before you start</strong><p>The Unity build is currently unavailable. The console below connects to the match service and displays its responses.</p><p>Console controls: focus its field and use A/D or left/right; W, up or Space jumps. Touch buttons are also available.</p><p>Save and online: match results require the REMIX service. Page loading does not confirm an online match or a saved result.</p>';hero.appendChild(guide);
 const api=document.querySelector('#api-url'),settings=document.createElement('details');settings.className='remix-settings';settings.innerHTML='<summary>Advanced connection settings</summary><p>Keep the default address unless you run your own compatible match service.</p><label>API URL</label>';api.insertAdjacentElement('beforebegin',settings);settings.querySelector('label').appendChild(api);
 const arena=document.querySelector('#arena');arena.tabIndex=0;arena.setAttribute('aria-describedby','remix-console-controls');const controls=document.createElement('div');controls.className='remix-console-controls';controls.innerHTML='<p id="remix-console-controls">Console controls: focus the field or use the buttons below. A/D or arrows moves; W, up or Space jumps.</p><div><button type="button" data-console-action="left">← Left</button><button type="button" data-console-action="jump">Jump ↑</button><button type="button" data-console-action="right">Right →</button></div><p id="remix-storage-state" role="status" hidden></p>';arena.insertAdjacentElement('afterend',controls);
 controls.querySelectorAll('[data-console-action]').forEach(button=>button.addEventListener('click',()=>{const action=button.dataset.consoleAction;if(action==='left')send(-1,0,false);if(action==='right')send(1,0,false);if(action==='jump')send(0,1,true)}));
 const status=document.querySelector('#match-status');status.setAttribute('role','status');status.setAttribute('aria-live','polite');
 window.RemixSession?.syncControls();apply();updateStorage();watch();
}
window.RemixUI={t,setLanguage,getLanguage:()=>locale,updateStorage};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();

})();
