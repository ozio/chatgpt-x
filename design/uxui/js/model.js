/* Prototype model: stage gating, scenarios, mock account data and a simulated
   send/stream pipeline. Nothing here talks to a network. */
(function () {
  'use strict';
  var M = window.M = {};

  /* ---------- Stage gating ---------- */
  var FEAT = {};
  window.FEATURES.included.forEach(function (f) { FEAT[f.id] = f; });
  M.feat = FEAT;
  M.STAGES = [10, 9, 8, 7, 6];
  M.stage = 10;
  try {
    var q = /[?&]stage=(\d+)/.exec(location.search);
    var saved = parseInt(localStorage.getItem('rc-stage'), 10);
    if (q) M.stage = parseInt(q[1], 10); else if (saved) M.stage = saved;
  } catch (e) {}
  if (M.STAGES.indexOf(M.stage) < 0) M.stage = 10;
  /* M.on('chat.copy_text') — is this function available at the current stage? */
  M.on = function (id) {
    var f = FEAT[id];
    if (!f) { if (window.console) console.warn('unknown feature', id); return false; }
    return f.u >= M.stage;
  };
  M.any = function () { for (var i = 0; i < arguments.length; i++) if (M.on(arguments[i])) return true; return false; };

  /* ---------- Events ---------- */
  var subs = {};
  M.on_ = function (names, fn) { names.split(' ').forEach(function (n) { (subs[n] = subs[n] || []).push(fn); }); };
  M.emit = function (n, a, b) { (subs[n] || []).slice().forEach(function (fn) { fn(a, b); }); };

  /* ---------- Scenarios (toggled from the showcase or the in-app prototype screen) ---------- */
  M.scenario = { offline: false, slowPrep: false, uncertain: false, cutoff: false, renewFail: false, uploadLimit: false, dictationFail: false, voiceNet: false, pinLock: false };
  try { var sc = JSON.parse(localStorage.getItem('rc-scn') || '{}'); for (var k in sc) M.scenario[k] = sc[k]; } catch (e) {}
  M.setScenario = function (k, v) { M.scenario[k] = v; try { localStorage.setItem('rc-scn', JSON.stringify(M.scenario)); } catch (e) {} M.emit('scenario', k, v); };

  /* ---------- Account ---------- */
  M.signedIn = true;
  try { if (localStorage.getItem('rc-signedout') === '1') M.signedIn = false; } catch (e) {}
  M.user = { name: 'Алексей Смирнов', email: 'alexey@example.com', initials: 'АС', plan: 'Plus' };
  M.session = { state: 'active', renewed: Date.now() - 4 * 60 * 1000, created: Date.now() - 6 * 86400000 };
  M.prefs = {
    textSize: 2, theme: 0, language: 0, memory: true, historyRef: true, training: false, trainingVoice: false,
    autoSearch: true, visual: true, imageGen: true, notifyDone: true, location: false, sensitive: true, autoMemory: true,
    libraryAuto: true, streamingDictation: true, voice: 'Сосна', voiceLang: 0, voiceMode: 0, transcript: true,
    instructions: 'Отвечай по-русски, коротко и по делу. Код — с комментариями.', nickname: 'Алексей', job: 'Инженер', about: 'Люблю старые iPhone и походы.',
    personality: 0, chars: { warm: 1, emoji: 0, headers: 1 }, pin: '1234', model: 0, effort: 1, autoSwitch: true, version: 0
  };
  M.models = [
    { name: 'Авто', sub: 'Сам решает, сколько думать' },
    { name: 'Мгновенно', sub: 'Быстрые ответы' },
    { name: 'Думать', sub: 'Дольше, для сложных задач' },
    { name: 'Pro', sub: 'Исследовательский уровень' }
  ];

  /* ---------- Conversations ---------- */
  var now = Date.now(), H = 3600000, D = 86400000;
  var uid = 100;
  M.uid = function () { return 'c' + (uid++); };
  function msg(role, md, extra) { var m = { id: M.uid(), role: role, md: md, state: 'done', t: now }; if (extra) for (var k in extra) m[k] = extra[k]; return m; }

  M.projects = [
    { id: 'p1', name: 'Ремонт квартиры', color: 'orange', memory: 'project', instructions: 'Бюджет 600 тыс. ₽, однушка 38 м², сроки — к марту.', files: [{ name: 'План квартиры.pdf', size: 1.8e6, kind: 'pdf' }, { name: 'Смета.xlsx', size: 54e3, kind: 'sheet' }] },
    { id: 'p2', name: 'Английский B2', color: 'blue', memory: 'default', instructions: 'Исправляй ошибки и объясняй правило.', files: [{ name: 'Список слов.txt', size: 12e3, kind: 'text' }] }
  ];

  M.chats = [
    { id: 'k1', title: 'Борщ на 4 порции', t: now - 0.6 * H, msgs: [
      msg('user', 'Как сварить борщ на 4 порции?'),
      msg('assistant', '## Борщ на 4 порции\n\nПонадобится около **1,5 часа**.\n\n### Продукты\n- говядина на кости — 500 г\n- свёкла — 2 шт.\n- картофель — 3 шт.\n- капуста — 300 г\n- морковь, лук — по 1 шт.\n- томатная паста — 1 ст. л.\n\n### Как готовить\n1. Залейте мясо 2,5 л воды и варите 1 час, снимая пену.\n2. Свёклу натрите и потушите с пастой и ложкой уксуса — так она сохранит цвет.\n3. Добавьте в бульон картофель, через 10 минут — капусту.\n4. Вмешайте зажарку из лука и моркови, затем свёклу.\n5. Доведите до кипения и дайте настояться 15 минут.\n\n> Подавайте со сметаной и чесночными пампушками.', { think: ['Понял вопрос', 'Подобрал пропорции на 4 порции'], thinkSec: 3 })
    ]},
    { id: 'k2', title: 'Python: прочитать CSV', t: now - 2 * H, msgs: [
      msg('user', 'Как в Python прочитать CSV и посчитать среднее по колонке price?'),
      msg('assistant', 'Проще всего — стандартным модулем `csv`, без сторонних библиотек:\n\n```python\nimport csv\n\nwith open("data.csv", newline="") as f:\n    rows = list(csv.DictReader(f))\n\nprices = [float(r["price"]) for r in rows]\nprint(sum(prices) / len(prices))\n```\n\nЕсли в файле есть пустые значения, отфильтруйте их: `if r["price"]`.')
    ]},
    { id: 'k3', title: 'Поездка в Казань на выходные', t: now - 26 * H, msgs: [
      msg('user', 'Что посмотреть в Казани за два дня?'),
      msg('assistant', '**День 1 — исторический центр**\n- Казанский кремль и мечеть Кул-Шариф\n- Улица Баумана, вечером — набережная\n\n**День 2 — окрестности**\n- Остров-град Свияжск (1 ч на метеоре летом)\n- Храм всех религий по дороге обратно\n\n| Место | Время | Билет |\n|---|---|---|\n| Кремль | 3 ч | бесплатно |\n| Свияжск | 5 ч | от 600 ₽ |\n\nРасписание метеоров меняется по сезону — проверьте перед поездкой.', { sources: [
        { title: 'Казанский кремль — официальный сайт', host: 'kazan-kremlin.ru' },
        { title: 'Свияжск: как добраться', host: 'sviyazhsk.ru' },
        { title: 'Речной вокзал Казани — расписание', host: 'rechport.ru' }], searched: true, think: ['Искал в интернете: «Казань что посмотреть 2 дня»', 'Сверил расписание метеоров', 'Составил маршрут'], thinkSec: 11 })
    ]},
    { id: 'k4', title: 'Как работает TLS 1.2', t: now - 3 * D, pinned: true, msgs: [
      msg('user', 'Объясни простыми словами рукопожатие TLS 1.2'),
      msg('assistant', 'Представьте, что браузер и сервер договариваются о секретном языке при свидетелях.\n\n1. **ClientHello** — браузер называет поддерживаемые шифры и случайное число.\n2. **ServerHello + сертификат** — сервер выбирает шифр и показывает «паспорт», подписанный центром сертификации.\n3. **Обмен ключами** — по ECDHE обе стороны вычисляют общий секрет, который не передаётся по сети.\n4. **Finished** — каждая сторона подтверждает, что видела тот же разговор.\n\nПосле этого данные идут зашифрованными симметричным ключом.')
    ]},
    { id: 'k5', title: 'Квартальный отчёт: выручка', t: now - 5 * D, msgs: [
      msg('user', 'Построй график выручки по месяцам: янв 1,2; фев 1,5; мар 1,9 млн'),
      msg('assistant', 'Выручка росла каждый месяц, в марте — **+27 %** к февралю.', { parts: [{ type: 'chart', title: 'Выручка, млн ₽', data: [['Янв', 1.2], ['Фев', 1.5], ['Мар', 1.9]] }] })
    ]},
    { id: 'k6', title: 'Логотип для кофейни', t: now - 6 * D, msgs: [
      msg('user', 'Нарисуй логотип кофейни «Зерно» в винтажном стиле'),
      msg('assistant', 'Вот вариант в винтажном стиле — круглая эмблема с зерном и лентой.', { parts: [{ type: 'image', w: 1024, h: 1024, art: 'coffee' }] })
    ]},
    { id: 'k7', title: 'Рынок электровелосипедов', t: now - 8 * D, msgs: [
      msg('user', 'Сделай исследование рынка электровелосипедов в России'),
      msg('assistant', '', { parts: [{ type: 'research', title: 'Рынок электровелосипедов в России', done: true, sources: 34, min: 9, pages: 12 }] })
    ]},
    { id: 'k8', title: 'Письмо арендодателю', t: now - 9 * D, msgs: [
      msg('user', 'Напиши письмо арендодателю: прошу перенести оплату на 5 дней'),
      msg('assistant', 'Вот черновик письма:', { parts: [{ type: 'email', to: 'landlord@example.com', cc: '', subject: 'Перенос оплаты аренды', body: 'Здравствуйте, Ирина Петровна!\n\nПрошу перенести оплату за декабрь на 5 дней — до 15-го числа. Задержка связана с переносом зарплаты. Остальные условия без изменений.\n\nСпасибо за понимание,\nАлексей' }] })
    ]},
    { id: 'k14', title: 'Договор аренды: правки', t: now - 1.5 * D, msgs: [
      msg('user', 'Проверь договор и внеси правки про сроки оплаты', { att: [{ name: 'Договор аренды.pdf', kind: 'pdf' }] }),
      msg('assistant', 'Исправил пункты 3.2 и 5.1: срок оплаты — до 10-го числа, штраф — не больше 0,1 % в день. Файл с правками ниже.', { parts: [{ type: 'file', name: 'Договор аренды (правки).docx', size: 48e3 }, { type: 'file', name: 'Договор аренды.pdf', expired: true }] })
    ]},
    { id: 'k9', title: 'Плитка в ванную: расчёт', t: now - 4 * D, project: 'p1', msgs: [
      msg('user', 'Сколько плитки нужно на стены ванной 1,7×1,5, высота 2,5 м?'),
      msg('assistant', 'Периметр 6,4 м × высота 2,5 м = **16 м²**. Минус дверь (≈1,4 м²) — 14,6 м². С запасом 10 % на подрезку возьмите **16 м²** плитки.')
    ]},
    { id: 'k10', title: 'Present Perfect vs Past Simple', t: now - 12 * D, project: 'p2', msgs: [
      msg('user', 'I have seen him yesterday — правильно?'),
      msg('assistant', 'Почти! С точным временем в прошлом (*yesterday*) нужен **Past Simple**: *I saw him yesterday.*\n\nPresent Perfect — когда время не указано или период ещё идёт: *I have seen him this week.*')
    ]},
    { id: 'k11', title: 'Подарок маме на юбилей', t: now - 15 * D, msgs: [
      msg('user', 'Идеи подарка маме на 60 лет, она любит сад'),
      msg('assistant', '- Набор японских садовых ножниц\n- Сертификат в питомник растений\n- Фотокнига «60 лет — 60 фотографий»\n- Мастер-класс по флористике вместе с вами')
    ]},
    { id: 'k12', title: 'Дневник: мысли о работе', t: now - 20 * D, locked: true, msgs: [
      msg('user', 'Помоги разобраться, стоит ли менять работу'),
      msg('assistant', 'Давайте разложим по полочкам: что сейчас радует, что утомляет и чего не хватает. Начнём с первого — что вам нравится в текущей работе?')
    ]},
    { id: 'k13', title: 'Старый чат про iOS 6', t: now - 60 * D, archived: true, msgs: [
      msg('user', 'Какие приложения ещё работают на iOS 6?'),
      msg('assistant', 'Немногие: большинство сервисов требуют TLS 1.2 и новые API. Помогают твики и собственные клиенты.')
    ]}
  ];
  M.sharedLinks = [{ chat: 'k3', title: 'Поездка в Казань на выходные', t: now - 20 * H }];
  M.memories = [
    { text: 'Живёт в Казани', t: now - 30 * D, prio: false },
    { text: 'Пользуется iPhone 5 с iOS 6', t: now - 12 * D, prio: true },
    { text: 'Делает ремонт в однокомнатной квартире', t: now - 5 * D, prio: false },
    { text: 'Учит английский, цель — уровень B2', t: now - 40 * D, prio: false },
    { text: 'Предпочитает короткие ответы', t: now - 50 * D, prio: true }
  ];
  M.library = [
    { id: 'l1', name: 'Смета.xlsx', kind: 'sheet', size: 54e3, t: now - 4 * D, chat: 'k9', fav: false },
    { id: 'l2', name: 'План квартиры.pdf', kind: 'pdf', size: 1.8e6, t: now - 4 * D, chat: 'k9', fav: true },
    { id: 'l3', name: 'Логотип «Зерно».png', kind: 'image', size: 640e3, t: now - 6 * D, chat: 'k6', fav: true, art: 'coffee' },
    { id: 'l4', name: 'Рынок e-bike.pdf', kind: 'pdf', size: 2.4e6, t: now - 8 * D, chat: 'k7', fav: false },
    { id: 'l5', name: 'Список слов.txt', kind: 'text', size: 12e3, t: now - 12 * D, chat: 'k10', fav: false },
    { id: 'l6', name: 'data.csv', kind: 'sheet', size: 8e3, t: now - 2 * H, chat: 'k2', fav: false }
  ];
  M.trash = [{ id: 'l9', name: 'Старый договор.pdf', kind: 'pdf', size: 900e3, t: now - 3 * D }];
  M.folders = [{ name: 'Ремонт', n: 2 }, { name: 'Учёба', n: 1 }];
  M.images = [
    { art: 'coffee', prompt: 'Логотип кофейни «Зерно»' }, { art: 'mountains', prompt: 'Горы на рассвете, акварель' },
    { art: 'robot', prompt: 'Ретро-робот с iPhone 5' }, { art: 'sea', prompt: 'Маяк в шторм' },
    { art: 'forest', prompt: 'Лес и туман' }, { art: 'city', prompt: 'Ночная Казань, неон' }
  ];
  M.tasks = [
    { id: 't1', name: 'Курс валют утром', prompt: 'Пришли курс доллара и евро ЦБ на сегодня', when: 'Ежедневно в 8:00', active: true, last: 'Сегодня, 8:00' },
    { id: 't2', name: 'Слова на неделю', prompt: 'Подбери 10 слов уровня B2 с примерами', when: 'По понедельникам в 9:00', active: true, last: 'Пн, 9:00' },
    { id: 't3', name: 'Напомнить про счётчики', prompt: 'Напомни передать показания воды', when: 'Ежемесячно, 20-го', active: false, last: '20 окт.' }
  ];
  M.gpts = [
    { name: 'Шеф-повар', by: 'Сообщество', cat: 0, color: 'orange', glyph: 'star', desc: 'Рецепты из того, что есть в холодильнике.' },
    { name: 'Репетитор английского', by: 'Сообщество', cat: 1, color: 'blue', glyph: 'book', desc: 'Разговорная практика и исправление ошибок.' },
    { name: 'Юрист-помощник', by: 'Сообщество', cat: 2, color: 'graphite', glyph: 'shield', desc: 'Объясняет договоры простыми словами.' },
    { name: 'Код на Objective-C', by: 'Сообщество', cat: 2, color: 'purple', glyph: 'file', desc: 'Помогает с UIKit и ручным управлением памятью.' },
    { name: 'Планировщик путешествий', by: 'Сообщество', cat: 0, color: 'teal', glyph: 'globe', desc: 'Маршруты, бюджеты и списки вещей.' }
  ];
  M.myGpts = [{ name: 'Мой ремонт', color: 'orange', glyph: 'folder', desc: 'Знает смету и план квартиры.' }];
  M.apps = [
    { name: 'Google Drive', color: 'yellow', glyph: 'cloud', on: true, desc: 'Файлы из Диска в ответах и Library.' },
    { name: 'Почта', color: 'blue', glyph: 'mail', on: false, desc: 'Черновики и отправка писем.' },
    { name: 'Календарь', color: 'red', glyph: 'clock', on: false, desc: 'События и напоминания.' },
    { name: 'GitHub', color: 'graphite', glyph: 'branch', on: false, desc: 'Код и задачи репозиториев.' }
  ];
  M.devices = [
    { name: 'iPhone 5 · ChatGPT X', where: 'Казань', t: now, current: true },
    { name: 'Mac · Safari', where: 'Казань', t: now - 2 * H },
    { name: 'iPad · ChatGPT', where: 'Москва', t: now - 9 * D }
  ];

  M.chat = function (id) { for (var i = 0; i < M.chats.length; i++) if (M.chats[i].id === id) return M.chats[i]; return null; };
  M.project = function (id) { for (var i = 0; i < M.projects.length; i++) if (M.projects[i].id === id) return M.projects[i]; return null; };
  /* Chats visible in the main history list at the current stage. */
  M.history = function () {
    return M.chats.filter(function (c) {
      if (c.temp) return false;
      if (c.archived && M.on('chat.archive')) return false;
      if (c.locked && M.on('chat.lock')) return false;
      if (c.project && M.on('projects.chat')) return false;
      return true;
    }).sort(function (a, b) { return b.t - a.t; });
  };

  /* ---------- Send readiness: the honest "lamp" of the composer ----------
     The real build prepares the website send handler on the phone; cold
     preparation took ~100 s in physical tests. The prototype compresses it. */
  M.conn = { state: 'cold', left: 0, total: 0 };
  var prepTimer = null;
  M.prepare = function () {
    if (M.conn.state === 'ready' || M.conn.state === 'preparing') return;
    if (M.scenario.offline) { M.conn.state = 'offline'; M.emit('conn'); return; }
    var total = M.scenario.slowPrep ? 24 : 5;
    M.conn = { state: 'preparing', left: total, total: total };
    M.emit('conn');
    clearInterval(prepTimer);
    prepTimer = setInterval(function () {
      M.conn.left--;
      if (M.conn.left <= 0) { clearInterval(prepTimer); M.conn.state = 'ready'; }
      M.emit('conn');
    }, 1000);
  };
  M.resetConn = function () { clearInterval(prepTimer); M.conn = { state: 'cold', left: 0, total: 0 }; M.emit('conn'); };
  M.on_('scenario', function (k, v) {
    if (k === 'offline') {
      if (v) { clearInterval(prepTimer); M.conn.state = 'offline'; M.emit('conn'); }
      else { M.conn.state = 'cold'; M.prepare(); }
    }
  });

  /* ---------- Replies ---------- */
  M.replyFor = function (text, mode) {
    var t = text.toLowerCase();
    if (mode === 'image' || /нарисуй|картинк|изображени/.test(t)) {
      return { md: 'Готово — вот изображение по вашему описанию.', parts: [{ type: 'image', w: 1024, h: 1024, art: ['mountains', 'sea', 'forest', 'city', 'robot'][text.length % 5], making: true }], think: ['Уточнил стиль', 'Создаю изображение'], thinkSec: 6 };
    }
    if (mode === 'research') {
      return { md: '', parts: [{ type: 'research', title: text.length > 40 ? text.slice(0, 40) + '…' : text, done: false, sources: 0, min: 0, pages: 0 }] };
    }
    if (mode === 'study') {
      return { md: 'Давайте разберёмся вместе, а не просто получим ответ. 🙂\n\nСначала вопрос к вам: **что вы уже знаете об этой теме?** Попробуйте сформулировать в одном-двух предложениях — от этого и оттолкнёмся.' };
    }
    if (/план|маршрут/.test(t) && M.on('compose.clarifications')) {
      return { md: 'Чтобы составить хороший план, уточню пару деталей:', parts: [{ type: 'clarify', qs: [
        { q: 'Для кого план?', opts: ['Только для меня', 'Для семьи с детьми', 'Для компании друзей'], multi: false },
        { q: 'Что важнее всего?', opts: ['Бюджет', 'Скорость', 'Впечатления', 'Комфорт'], multi: true }] }] };
    }
    if (/календар|встреч|событи/.test(t) && M.on('tools.action_approval')) {
      return { md: 'Создам событие в вашем календаре — нужно ваше подтверждение:', parts: [{ type: 'approve', app: 'Календарь', action: 'создать событие', params: [{ k: 'Название', v: 'Встреча с арендодателем' }, { k: 'Когда', v: 'пт, 15:00–16:00' }, { k: 'Где', v: 'ул. Баумана, 12' }] }] };
    }
    if (/письм|email|почт/.test(t)) {
      return { md: 'Вот черновик письма:', parts: [{ type: 'email', to: '', cc: '', subject: 'Вопрос', body: 'Здравствуйте!\n\n' + text + '\n\nС уважением,\nАлексей' }] };
    }
    if (/код|python|функц|скрипт|objective/.test(t)) {
      return { md: 'Вот пример на Objective-C для iOS 6 с ручным управлением памятью:\n\n```objc\nNSString *name = [[NSString alloc] initWithFormat:@"%@", input];\nlabel.text = name;\n[name release]; // MRC: освобождаем сами\n```\n\nВ iOS 6 без ARC важно, чтобы каждому `alloc` соответствовал `release`.', think: ['Разобрал задачу', 'Проверил синтаксис для SDK 6.1'], thinkSec: 7 };
    }
    if (mode === 'web' || /новост|погод|курс|сегодня/.test(t)) {
      return { md: 'По данным на сегодня: **погода в Казани** — облачно, +3 °C, к вечеру слабый дождь. Ветер северо-западный, 5 м/с.\n\nЗавтра похолодает до −1 °C, возможен мокрый снег.', sources: [{ title: 'Прогноз погоды — Казань', host: 'meteo.example' }, { title: 'Гидрометцентр: Татарстан', host: 'meteoinfo.example' }], searched: true, think: ['Искал в интернете: «погода Казань сегодня»', 'Сравнил два источника'], thinkSec: 5 };
    }
    return { md: 'Хороший вопрос. Коротко:\n\n- **Главное** — начните с самого простого шага и проверьте результат.\n- Если что-то не получится, опишите, что именно вы видите, — разберёмся.\n- Для сложных случаев полезно записать шаги, чтобы вернуться к ним позже.\n\nХотите, распишу подробнее на вашем примере?', think: ['Понял вопрос', 'Сформулировал ответ'], thinkSec: 2 };
  };
  M.alternate = '**Другой вариант ответа.**\n\nПопробуем зайти с другой стороны: разбейте задачу на три части — что есть сейчас, что нужно получить и что мешает. Для каждой части запишите одно действие на сегодня.';
  M.continuation = '\n\n5. Через 15 минут разлейте по тарелкам и добавьте зелень.\n\nПриятного аппетита!';
})();
