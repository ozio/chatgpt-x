/* Account and settings: one grouped-table tree that grows with each stage. */
(function () {
  'use strict';
  var S = window.S;
  var on = M.on;

  function sw(g, title, key, sub, fn) {
    var c = K.cell(g, { title: title, cls: 'has-switch' });
    c.querySelector('.t').classList.add('plain');
    if (sub) c.appendChild(K.h('div', 'sw-sub', sub));
    c.appendChild(K.toggle(M.prefs[key], function (v) { M.prefs[key] = v; M.emit('prefs'); if (fn) fn(v); }));
    return c;
  }
  function checklist(g, items, key, fn) {
    var cells = items.map(function (t, i) {
      return K.cell(g, { title: t, plain: true, noArrow: true, check: M.prefs[key] === i, action: function (c) {
        M.prefs[key] = i; cells.forEach(function (x) { K.cls(x, 'checked', x === c); }); M.emit('prefs'); if (fn) fn(i);
      } });
    });
    return cells;
  }
  function push(parent, s) { parent.nav.push(s); }
  function ago(t) { return K.ago(t); }

  S.account = function () {
    var s = K.screen('Аккаунт');
    var b = s.body;
    b.appendChild(K.h('div', 'hero', '<div class="av">' + M.user.initials + '</div><div class="nm">' + K.esc(M.user.name) + '</div><div class="em">' + K.esc(M.user.email) + '</div>' + (on('subscription.plans') ? '<span class="badge-plan">' + M.user.plan + '</span>' : '')));

    /* 10: session restore / renew */
    var g = K.group(b, 'Сессия', 'Сессия хранится в Связке ключей этого iPhone и восстанавливается при запуске без входа. Пароль приложение не хранит.');
    var st = K.cell(g, { title: 'Состояние', plain: true, value: '' });
    var rn = K.cell(g, { title: 'Обновлена', plain: true, value: '' });
    function draw() {
      st.querySelector('.v').innerHTML = M.session.state === 'active' ? '<span class="lamp ok"></span>Активна' : '<span class="lamp warn"></span>Нужен вход';
      rn.querySelector('.v').textContent = ago(M.session.renewed);
    }
    draw();
    K.cell(g, { title: M.session.state === 'active' ? 'Проверить и обновить' : 'Войти снова', cls: 'link center', noArrow: true, action: function () {
      if (M.session.state !== 'active') { S.signIn({ reauth: true, done: function () { M.session.state = 'active'; M.session.renewed = Date.now(); M.emit('session'); draw(); } }); return; }
      var h = K.hud('Проверяю…', 'busy');
      setTimeout(function () {
        if (M.scenario.renewFail) { h.hide(); M.session.state = 'expired'; M.emit('session'); draw(); K.alert({ title: 'Сессия истекла', message: 'Сервис попросил войти снова. Чаты и черновики на iPhone сохранены.', buttons: [{ title: 'Позже', cancel: true }, { title: 'Войти', action: function () { S.signIn({ reauth: true, done: function () { M.session.state = 'active'; M.session.renewed = Date.now(); M.emit('session'); draw(); } }); } }] }); return; }
        M.session.renewed = Date.now(); draw(); h.done('Сессия активна');
      }, 1200);
    } });

    if (on('accessibility.large_text')) {
      var gc = K.group(b, 'Чат');
      K.cell(gc, { title: 'Размер текста', icon: K.tile('text', 'gray'), value: ['Мельче', 'Мелкий', 'Обычный', 'Крупный', 'Крупнее'][M.prefs.textSize], action: function () { push(s, textSize()); } });
    }
    if (on('preferences.instructions')) {
      var gp = K.group(b, 'Персонализация');
      K.cell(gp, { title: 'Инструкции и стиль', icon: K.tile('sliders', 'green'), action: function () { push(s, personalization()); } });
      K.cell(gp, { title: 'Память', icon: K.tile('brain', 'purple'), value: M.prefs.memory ? 'Вкл.' : 'Выкл.', action: function () { push(s, memory()); } });
      K.cell(gp, { title: 'Оформление', icon: K.tile('sun', 'orange'), value: ['Светлое', 'Тёмное'][M.prefs.theme], action: function () { push(s, appearance()); } });
      K.cell(gp, { title: 'Язык', icon: K.tile('globe', 'blue'), value: ['Системный', 'Русский', 'English'][M.prefs.language], action: function () { push(s, language()); } });
      if (on('preferences.visual_answers')) K.cell(gp, { title: 'Ответы', icon: K.tile('chart', 'teal'), action: function () { push(s, answers()); } });
      if (on('voice.choose_voice')) K.cell(gp, { title: 'Голос', icon: K.tile('voice', 'red'), value: M.prefs.voice, action: function () { S.voiceSettings(); } });
      var gd = K.group(b, 'Данные и безопасность');
      K.cell(gd, { title: 'Управление данными', icon: K.tile('archive', 'graphite'), action: function () { push(s, dataControls()); } });
      K.cell(gd, { title: 'Безопасность', icon: K.tile('shield', 'blue'), action: function () { push(s, security()); } });
      if (on('account.sessions.list')) K.cell(gd, { title: 'Устройства и сеансы', icon: K.tile('devices', 'gray'), value: String(M.devices.length), action: function () { push(s, devices()); } });
      if (on('privacy.locked_pin_create')) K.cell(gd, { title: 'PIN закрытых чатов', icon: K.tile('lock', 'graphite'), action: function () { push(s, pinScreen()); } });
      K.cell(gd, { title: 'Приватность', icon: K.tile('key', 'green'), action: function () { push(s, privacy()); } });
      K.cell(gd, { title: 'Возраст и безопасность', icon: K.tile('person', 'teal'), action: function () { push(s, age()); } });
    }
    if (M.any('preferences.notifications', 'integration.location', 'tools.apps_catalog')) {
      var ge = K.group(b, 'Устройство и приложения');
      if (on('preferences.notifications')) K.cell(ge, { title: 'Уведомления', icon: K.tile('bell', 'red'), action: function () { push(s, notifications()); } });
      if (on('integration.location')) K.cell(ge, { title: 'Местоположение', icon: K.tile('location', 'blue'), value: M.prefs.location ? 'Вкл.' : 'Выкл.', action: function () { push(s, location()); } });
      if (on('tools.apps_catalog')) K.cell(ge, { title: 'Приложения', icon: K.tile('apps', 'purple'), value: String(M.apps.filter(function (a) { return a.on; }).length), action: function () { push(s, apps()); } });
    }
    if (on('subscription.plans')) { var gpl = K.group(b, null); K.cell(gpl, { title: 'План', icon: K.tile('star', 'yellow'), value: M.user.plan, action: function () { push(s, plans()); } }); }
    if (on('account.logout')) {
      var row = K.h('div', 'btn-row', '<div class="button red">Выйти</div>');
      b.appendChild(row);
      K.tap(row.firstChild, function () {
        K.sheet({ title: 'Выйти из аккаунта на этом iPhone? Сессия и кэш будут удалены с устройства. Чаты останутся в аккаунте.', buttons: [{ title: 'Выйти', red: true, action: function () { var h = K.hud('Выхожу…', 'busy'); setTimeout(function () { h.hide(); S.command('signout'); }, 900); } }] });
      });
    }
    var gx = K.group(b, null);
    K.cell(gx, { title: 'Прототип: этап и сценарии', icon: K.appIcon(29), action: function () { push(s, S.prototypeScreen(false)); } });
    b.appendChild(K.h('div', 'group-foot', 'ChatGPT X 1.0 · прототип интерфейса · iPhone 5, iOS 6.1.4'));
    var nav = S.modalNav(s);
    M.on_('session', function () { if (K.inDoc(st)) draw(); });
    return nav;
  };

  function textSize() {
    var s = K.screen('Размер текста');
    var box = K.h('div', 'sizes', '<div class="preview">Так будут выглядеть ответы ChatGPT и ваши сообщения.</div><div class="slider"><span class="a1">A</span><span class="a2">A</span><div class="rail"></div><div class="fill"></div><div class="knob"></div><div class="ticks"></div></div>');
    s.body.appendChild(box);
    s.body.appendChild(K.h('div', 'group-foot', 'Работает вместе с «Крупным текстом» из Настроек iPhone › Основные › Универсальный доступ.'));
    var sizes = [14, 15, 16, 19, 22], slider = box.querySelector('.slider'), knob = box.querySelector('.knob'), fill = box.querySelector('.fill'), pv = box.querySelector('.preview'), ticks = box.querySelector('.ticks');
    function set(i) {
      M.prefs.textSize = i; M.emit('prefs');
      var w = slider.offsetWidth - 52, x = 26 + w * i / 4;
      knob.style.left = x + 'px'; fill.style.width = (x - 26) + 'px'; pv.style.fontSize = sizes[i] + 'px'; pv.style.lineHeight = Math.round(sizes[i] * 1.35) + 'px';
    }
    for (var i = 0; i < 5; i++) (function (i) { var t = K.h('i', ''); ticks.appendChild(t); K.tap(t, function () { set(i); }, { instant: true }); })(i);
    s.onShow = function () { var w = slider.offsetWidth - 52; var t = ticks.childNodes; for (var k = 0; k < 5; k++) t[k].style.left = (26 + w * k / 4) + 'px'; set(M.prefs.textSize); };
    return s;
  }

  function personalization() {
    var s = K.screen('Инструкции и стиль');
    var g = K.group(s.body, 'Что ChatGPT должен учитывать', 'Применяется к новым чатам.');
    var c = K.cell(g, { title: '', cls: 'area' }); c.innerHTML = '';
    var ta = document.createElement('textarea'); ta.value = M.prefs.instructions; c.appendChild(ta);
    ta.addEventListener('input', function () { M.prefs.instructions = ta.value; }, false);
    var g2 = K.group(s.body, 'О вас');
    [['Как обращаться', 'nickname'], ['Занятие', 'job'], ['Интересы', 'about']].forEach(function (x) {
      var cc = K.cell(g2, { title: x[0], cls: 'field-cell' }); cc.querySelector('.t').classList.add('plain');
      var inp = K.h('input', 'field'); inp.value = M.prefs[x[1]]; inp.style.left = '135px'; cc.appendChild(inp);
      inp.addEventListener('input', function () { M.prefs[x[1]] = inp.value; }, false);
    });
    var g3 = K.group(s.body, 'Стиль ответов');
    checklist(g3, ['По умолчанию', 'Дружелюбный', 'Деловой', 'Лаконичный', 'Скептик'], 'personality');
    s.body.appendChild(K.h('div', 'group-head', 'Характеристики'));
    [['Теплота', 'warm'], ['Эмодзи', 'emoji'], ['Заголовки и списки', 'headers']].forEach(function (x) {
      var w = K.h('div', 'seg-wrap'); w.style.marginTop = '6px';
      w.appendChild(K.h('div', 'note', x[0])); w.lastChild.style.margin = '0 2px 4px';
      w.appendChild(K.seg(['Меньше', 'Обычно', 'Больше'], M.prefs.chars[x[1]], function (i) { M.prefs.chars[x[1]] = i; }, true));
      s.body.appendChild(w);
    });
    var rs = K.h('div', 'btn-row', '<div class="button">Сбросить к исходным</div>'); s.body.appendChild(rs);
    K.tap(rs.firstChild, function () { M.prefs.chars = { warm: 1, emoji: 1, headers: 1 }; s.nav.pop(); K.hud('Сброшено'); });
    return s;
  }

  function memory() {
    var s = K.screen('Память');
    var g = K.group(s.body, null, 'ChatGPT запоминает полезные факты из разговоров. Закрытые и временные чаты память не пополняют.');
    sw(g, 'Сохранять воспоминания', 'memory');
    if (on('memory.history_reference')) { var g2 = K.group(s.body, null, 'Учитывать прошлые чаты при ответе.'); sw(g2, 'Ссылки на историю чатов', 'historyRef'); }
    if (on('memory.legacy_list_search')) {
      var g3 = K.group(s.body, null);
      K.cell(g3, { title: 'Сохранённые воспоминания', value: String(M.memories.length), action: function () { push(s, memoryList()); } });
    }
    return s;
  }
  function memoryList() {
    var s = K.screen('Воспоминания');
    var sb = K.h('div', 'searchbar', '<div class="sf"><span class="mag">' + K.glyph('search', 14, '#7f9188') + '</span><input type="search" placeholder="Поиск"><span class="clear">✕</span></div>');
    s.body.appendChild(sb);
    var list = K.h('div', ''); s.body.appendChild(list);
    var q = '';
    sb.querySelector('input').addEventListener('input', function (e) { q = e.target.value.toLowerCase(); draw(); }, false);
    function draw() {
      list.innerHTML = '';
      if (on('memory.capacity')) {
        var pct = Math.round(M.memories.length / 6 * 100);
        var cap = K.h('div', 'sizes', '<div style="font-size:14px;font-weight:bold;margin-bottom:8px">Заполнено ' + pct + ' %</div>');
        var p = K.progress(pct > 80 ? 'amber' : ''); p.set(pct / 100); cap.appendChild(p);
        if (pct > 80) cap.appendChild(K.h('div', 'sw-sub', 'Память почти заполнена — удалите неважное или включите автоуправление.'));
        list.appendChild(cap);
      }
      var g = K.group(list, null, on('memory.priority') ? '★ — важные: их ChatGPT не удалит при автоуправлении.' : null);
      M.memories.filter(function (m) { return !q || m.text.toLowerCase().indexOf(q) >= 0; }).forEach(function (m) {
        var c = K.cell(g, { titleHTML: (m.prio && on('memory.priority') ? '<span style="color:#e0a000">★</span> ' : '') + K.esc(m.text), sub: K.ago(m.t), noArrow: true, action: function () {
          var b = [];
          if (on('memory.priority')) b.push({ title: m.prio ? 'Снять отметку «важное»' : 'Отметить как важное', action: function () { m.prio = !m.prio; draw(); } });
          b.push({ title: 'Удалить', red: true, action: function () { M.memories.splice(M.memories.indexOf(m), 1); draw(); } });
          K.sheet({ title: m.text, buttons: b });
        } });
        c.querySelector('.t').classList.add('plain');
        K.swipeDelete(c, 'Удалить', function () { M.memories.splice(M.memories.indexOf(m), 1); draw(); });
      });
      if (on('memory.priority')) { var ga = K.group(list, null); sw(ga, 'Управлять автоматически', 'autoMemory'); }
      if (on('memory.delete_all')) {
        var r = K.h('div', 'btn-row', '<div class="button red">Удалить все воспоминания</div>'); list.appendChild(r);
        K.tap(r.firstChild, function () { K.sheet({ title: 'Удалить все сохранённые воспоминания? Это нельзя отменить.', buttons: [{ title: 'Удалить все', red: true, action: function () { M.memories.length = 0; draw(); } }] }); });
      }
    }
    draw();
    return s;
  }

  function appearance() {
    var s = K.screen('Оформление');
    var g = K.group(s.body, null, 'В iOS 6 нет системной тёмной темы, поэтому выбор хранится в приложении.');
    checklist(g, ['Светлое', 'Тёмное'], 'theme', function (i) { K.cls(document.getElementById('app'), 'dark', i === 1); });
    return s;
  }
  function language() {
    var s = K.screen('Язык');
    var g = K.group(s.body, null, 'Язык интерфейса не влияет на язык ответов и голоса.');
    checklist(g, ['Как в системе', 'Русский', 'English'], 'language');
    return s;
  }
  function answers() {
    var s = K.screen('Ответы');
    var g = K.group(s.body, null);
    sw(g, 'Визуальные ответы', 'visual', 'Карточки, графики и таблицы. Выключите для простого вида.');
    if (on('preferences.auto_web_search')) sw(g, 'Искать в интернете сам', 'autoSearch', 'ChatGPT решает, когда нужен свежий поиск.');
    if (on('preferences.image_creation')) sw(g, 'Создание изображений', 'imageGen');
    if (on('library.auto_context')) sw(g, 'Искать в моей библиотеке', 'libraryAuto', 'Подбирать файлы из Library к ответу.');
    return s;
  }

  function dataControls() {
    var s = K.screen('Управление данными');
    var g = K.group(s.body, null, 'Будущие разговоры, а не прошлые.');
    sw(g, 'Улучшать модели для всех', 'training', 'Разрешить использовать ваши чаты для обучения.');
    if (on('privacy.training.audio_video')) sw(g, 'Голос и видео для обучения', 'trainingVoice');
    var g2 = K.group(s.body, 'Чаты');
    K.cell(g2, { title: 'Архив', value: String(M.chats.filter(function (c) { return c.archived; }).length), action: function () { push(s, archive()); } });
    K.cell(g2, { title: 'Общие ссылки', value: String(M.sharedLinks.length), action: function () { push(s, links()); } });
    var g3 = K.group(s.body, 'На этом iPhone', 'Удаляются только временные копии: чаты и файлы библиотеки остаются в аккаунте.');
    var cache = K.cell(g3, { title: 'Кэш изображений и превью', plain: true, value: '38,4 МБ' });
    K.cell(g3, { title: 'Очистить кэш', cls: 'link center', noArrow: true, action: function () { var h = K.hud('Очищаю…', 'busy'); setTimeout(function () { cache.querySelector('.v').textContent = '0 КБ'; h.done('Очищено'); }, 900); } });
    if (on('privacy.export')) {
      var g4 = K.group(s.body, 'Аккаунт');
      K.cell(g4, { title: 'Экспорт данных', action: function () { K.alert({ title: 'Экспортировать данные?', message: 'Архив с историей и настройками придёт на ' + K.esc(M.user.email) + '. Ссылка действует 24 часа.', buttons: [{ title: 'Отмена', cancel: true }, { title: 'Экспорт', action: function () { K.hud('Запрос отправлен'); } }] }); } });
      if (on('privacy.apps_access')) K.cell(g4, { title: 'Доступ приложений к профилю', value: '1', action: function () { push(s, appsAccess()); } });
      K.cell(g4, { title: 'Удалить аккаунт', cls: 'destructive', action: function () { K.alert({ title: 'Удалить аккаунт?', message: 'Все чаты и данные будут удалены без возможности восстановления. Подписку, оформленную через App Store, нужно отменить отдельно.', field: { placeholder: 'Введите email для подтверждения' }, buttons: [{ title: 'Отмена', cancel: true }, { title: 'Удалить', red: true, action: function () { K.hud('Нужна повторная авторизация', 'none'); } }] }); } });
    }
    return s;
  }
  function archive() {
    var s = K.screen('Архив');
    function draw() {
      s.body.innerHTML = '';
      var a = M.chats.filter(function (c) { return c.archived; });
      if (!a.length) { s.body.innerHTML = '<div class="empty"><b>Архив пуст</b>Архивированные чаты появятся здесь.</div>'; return; }
      var g = K.group(s.body, null, 'Нажмите, чтобы вернуть чат в список.');
      a.forEach(function (c) { K.cell(g, { title: c.title, sub: K.ago(c.t), noArrow: true, action: function () { K.sheet({ title: c.title, buttons: [{ title: 'Вернуть из архива', action: function () { c.archived = false; draw(); K.hud('Возвращён'); } }, { title: 'Удалить', red: true, action: function () { M.chats.splice(M.chats.indexOf(c), 1); draw(); } }] }); } }); });
    }
    draw();
    return s;
  }
  function links() {
    var s = K.screen('Общие ссылки');
    function draw() {
      s.body.innerHTML = '';
      if (!M.sharedLinks.length) { s.body.innerHTML = '<div class="empty"><b>Нет ссылок</b>Ссылки на разговоры, которыми вы поделились, появятся здесь.</div>'; return; }
      var g = K.group(s.body, null, 'Удалённая ссылка перестаёт открываться у всех.');
      M.sharedLinks.forEach(function (l) { var c = K.cell(g, { title: l.title, sub: 'Создана ' + K.ago(l.t), noArrow: true, action: function () { K.sheet({ title: l.title, buttons: [{ title: 'Скопировать ссылку', action: function () { K.hud('Скопировано'); } }, { title: 'Удалить ссылку', red: true, action: function () { M.sharedLinks.splice(M.sharedLinks.indexOf(l), 1); draw(); } }] }); } }); K.swipeDelete(c, 'Удалить', function () { M.sharedLinks.splice(M.sharedLinks.indexOf(l), 1); draw(); }); });
    }
    draw();
    return s;
  }
  function appsAccess() {
    var s = K.screen('Доступ к профилю');
    var g = K.group(s.body, null, 'Эти приложения видят ваше имя и email.');
    K.cell(g, { title: 'Google Drive', icon: K.tile('cloud', 'yellow'), noArrow: true, action: function () { K.sheet({ title: 'Google Drive', buttons: [{ title: 'Отозвать доступ', red: true, action: function () { K.hud('Доступ отозван'); } }] }); } });
    return s;
  }

  function security() {
    var s = K.screen('Безопасность');
    function reauth(fn) { K.alert({ title: 'Подтвердите, что это вы', message: 'Для этого изменения нужно снова войти. Откроется страница входа.', buttons: [{ title: 'Отмена', cancel: true }, { title: 'Продолжить', action: function () { S.signIn({ reauth: true, done: fn }); } }] }); }
    var g = K.group(s.body, 'Вход');
    K.cell(g, { title: 'Email', plain: true, value: M.user.email, action: function () { reauth(function () { K.alert({ title: 'Новый email', field: { placeholder: 'name@example.com' }, buttons: [{ title: 'Отмена', cancel: true }, { title: 'Сохранить', action: function () { K.hud('Письмо отправлено'); } }] }); }); } });
    K.cell(g, { title: 'Пароль', plain: true, value: 'Изменить', action: function () { reauth(function () { K.hud('Пароль изменён'); }); } });
    var g2 = K.group(s.body, 'Двухэтапная проверка', 'При усиленной защите аккаунта часть настроек недоступна — их меняет администратор.');
    K.cell(g2, { title: 'Приложение-аутентификатор', plain: true, value: 'Вкл.', action: function () { push(s, mfa()); } });
    K.cell(g2, { title: 'Нет доступа к коду?', cls: 'link', action: function () { K.alert({ title: 'Восстановление доступа', message: 'Используйте резервный код или пройдите восстановление на сайте.', buttons: [{ title: 'Отмена', cancel: true }, { title: 'Открыть сайт' }] }); } });
    if (on('account.security.incoming_approval')) {
      var g3 = K.group(s.body, 'Запросы входа', 'Подтверждать вход на других устройствах с этого iPhone.');
      var c = K.cell(g3, { title: 'Подтверждения на этом iPhone', cls: 'has-switch' }); c.querySelector('.t').classList.add('plain'); c.appendChild(K.toggle(true));
      K.cell(g3, { title: 'Показать пример запроса', cls: 'link', action: function () { K.alert({ title: 'Это вы входите?', message: 'Mac · Safari · Казань<br>Сравните число на том экране:', list: [{ v: '47' }], buttons: [{ title: 'Нет', cancel: true, action: function () { K.hud('Вход отклонён'); } }, { title: 'Да, это я', action: function () { K.hud('Вход подтверждён'); } }] }); } });
    }
    return s;
  }
  function mfa() {
    var s = K.screen('Аутентификатор');
    s.body.innerHTML = '<div class="sizes" style="text-align:center"><div style="width:140px;height:140px;margin:0 auto 10px;background:-webkit-repeating-linear-gradient(0deg,#222 0,#222 7px,#fff 7px,#fff 14px),-webkit-repeating-linear-gradient(90deg,#222 0,#222 7px,#fff 7px,#fff 14px);background-blend-mode:difference;opacity:.85"></div><div style="font-family:Menlo,monospace;font-size:13px">JBSW Y3DP EHPK 3PXP</div><div class="sw-sub">Отсканируйте код или введите ключ в приложении-аутентификаторе, затем введите 6 цифр.</div></div>';
    var g = K.group(s.body, null);
    var c = K.cell(g, { title: 'Код', cls: 'field-cell' }); var inp = K.h('input', 'field'); inp.placeholder = '000 000'; c.appendChild(inp);
    var r = K.h('div', 'btn-row', '<div class="button green">Подтвердить</div><div class="button red">Отключить проверку</div>'); s.body.appendChild(r);
    K.tap(r.firstChild, function () { K.hud('Аутентификатор подключён'); });
    K.tap(r.lastChild, function () { K.alert({ title: 'Отключить двухэтапную проверку?', message: 'Аккаунт станет менее защищён.', buttons: [{ title: 'Отмена', cancel: true }, { title: 'Отключить', red: true }] }); });
    return s;
  }
  function devices() {
    var s = K.screen('Устройства');
    function draw() {
      s.body.innerHTML = '';
      var g = K.group(s.body, 'Активные сеансы', 'Выход на устройстве завершает его сеанс и отключает подтверждения входа на нём.');
      M.devices.forEach(function (d) {
        K.cell(g, { title: d.name, sub: d.where + ' · ' + (d.current ? 'это устройство' : K.ago(d.t)), noArrow: d.current, action: d.current ? null : function () { K.sheet({ title: d.name, buttons: [{ title: 'Выйти на этом устройстве', red: true, action: function () { M.devices.splice(M.devices.indexOf(d), 1); draw(); K.hud('Сеанс завершён'); } }] }); } });
      });
      var r = K.h('div', 'btn-row', '<div class="button red">Выйти на всех устройствах</div>'); s.body.appendChild(r);
      K.tap(r.firstChild, function () { K.sheet({ title: 'Выйти везде, включая этот iPhone? Понадобится войти заново.', buttons: [{ title: 'Выйти везде', red: true, action: function () { S.command('signout'); } }] }); });
    }
    draw();
    return s;
  }
  function pinScreen() {
    var s = K.screen('PIN закрытых чатов');
    var g = K.group(s.body, null, 'PIN из 4 цифр защищает раздел «Закрытые чаты». Он общий для аккаунта.');
    K.cell(g, { title: 'Сменить PIN', action: function () { askPin('Текущий PIN', function () { askPin('Новый PIN', function () { K.hud('PIN изменён'); }, true); }); } });
    K.cell(g, { title: 'Забыли PIN?', cls: 'destructive', action: function () { K.alert({ title: 'Сбросить PIN?', message: 'Все закрытые чаты будут удалены. Это нельзя отменить.', buttons: [{ title: 'Отмена', cancel: true }, { title: 'Сбросить', red: true, action: function () { M.chats = M.chats.filter(function (c) { return !c.locked; }); K.hud('PIN сброшен'); } }] }); } });
    function askPin(title, ok, any) {
      var p = S.pinPad({ title: title, check: function (v) { return any || v === M.prefs.pin; }, ok: function () { pres.dismiss(ok); } });
      var nav = new K.Nav(); nav.push({ title: title, el: p, left: { title: 'Отмена', action: function () { pres.dismiss(); } } }, false);
      var pres = K.present(nav);
    }
    return s;
  }
  function privacy() {
    var s = K.screen('Приватность');
    var g = K.group(s.body, 'Как используются данные');
    [['Чаты и обучение', 'Управляется в «Управлении данными»'], ['Память', 'Что ChatGPT помнит о вас'], ['Временные чаты', 'Не сохраняются в истории']].forEach(function (x) { K.cell(g, { title: x[0], sub: x[1], noArrow: true }); });
    var g2 = K.group(s.body, null, 'Откроется в Safari.');
    ['Политика конфиденциальности', 'Портал запросов о данных', 'Справка'].forEach(function (x) { K.cell(g2, { title: x, cls: 'link', action: function () { K.alert({ title: 'Открыть в Safari?', message: x, buttons: [{ title: 'Отмена', cancel: true }, { title: 'Открыть' }] }); } }); });
    return s;
  }
  function age() {
    var s = K.screen('Возраст');
    var g = K.group(s.body, null, 'Для подростков действуют дополнительные ограничения контента.');
    K.cell(g, { title: 'Возрастная группа', plain: true, value: 'Взрослый' });
    K.cell(g, { title: 'Подтвердить возраст', cls: 'link', action: function () { K.alert({ title: 'Проверка возраста', message: 'Проверка проходит на сайте сервиса. Открыть?', buttons: [{ title: 'Отмена', cancel: true }, { title: 'Открыть' }] }); } });
    var g2 = K.group(s.body, null);
    sw(g2, 'Меньше чувствительного контента', 'sensitive');
    return s;
  }
  function notifications() {
    var s = K.screen('Уведомления');
    var g = K.group(s.body, null, 'iOS 6 позволяет приложению доработать в фоне до 10 минут. Если ответ придёт за это время, вы получите уведомление.');
    sw(g, 'Ответ готов', 'notifyDone');
    var c = K.cell(g, { title: 'Задачи по расписанию', cls: 'has-switch' }); c.querySelector('.t').classList.add('plain'); c.appendChild(K.toggle(true));
    return s;
  }
  function location() {
    var s = K.screen('Местоположение');
    var g = K.group(s.body, null, 'Используется только для вопросов вроде «кафе рядом». iPhone спросит разрешение при первом использовании.');
    sw(g, 'Учитывать местоположение', 'location');
    var c = K.cell(g, { title: 'Точное', cls: 'has-switch' }); c.querySelector('.t').classList.add('plain'); c.appendChild(K.toggle(false));
    return s;
  }
  function apps() {
    var s = K.screen('Приложения');
    function draw() {
      s.body.innerHTML = '';
      var g = K.group(s.body, 'Подключённые и доступные', 'Приложения дают ChatGPT доступ к вашим сервисам. Действия, меняющие данные, требуют подтверждения.');
      M.apps.forEach(function (a) { K.cell(g, { title: a.name, sub: a.desc, icon: K.tile(a.glyph, a.color), value: a.on ? 'Вкл.' : '', action: function () { push(s, appDetail(a, draw)); } }); });
    }
    draw();
    return s;
  }
  function appDetail(a, redraw) {
    var s = K.screen(a.name);
    function draw() {
      s.body.innerHTML = '<div class="hero">' + K.tile(a.glyph, a.color, 57) + '<div class="nm">' + K.esc(a.name) + '</div><div class="em">' + K.esc(a.desc) + '</div></div>';
      if (!a.on) {
        var r = K.h('div', 'btn-row', '<div class="button green">Подключить</div>'); s.body.appendChild(r);
        K.tap(r.firstChild, function () { var h = K.hud('Подключаю…', 'busy'); setTimeout(function () { a.on = true; h.done('Подключено'); draw(); redraw(); }, 1200); });
        s.body.appendChild(K.h('div', 'note', 'Вход в сервис откроется на его странице. ChatGPT X не видит пароль.'));
        return;
      }
      var g = K.group(s.body, 'Разрешения');
      var perms = ['Всегда спрашивать', 'Только чтение', 'Чтение и безопасные действия', 'Все действия'];
      a.perm = a.perm || 0;
      var cells = perms.map(function (p, i) { return K.cell(g, { title: p, plain: true, noArrow: true, check: a.perm === i, action: function (c) { a.perm = i; cells.forEach(function (x) { K.cls(x, 'checked', x === c); }); } }); });
      var g2 = K.group(s.body, 'Состояние');
      K.cell(g2, { title: 'Синхронизация', plain: true, value: '<span class="lamp ok"></span>5 мин назад' });
      var r2 = K.h('div', 'btn-row', '<div class="button red">Отключить</div>'); s.body.appendChild(r2);
      K.tap(r2.firstChild, function () { K.sheet({ title: 'Отключить «' + a.name + '»? ChatGPT потеряет доступ к его данным.', buttons: [{ title: 'Отключить', red: true, action: function () { a.on = false; draw(); redraw(); } }] }); });
    }
    draw();
    return s;
  }
  function plans() {
    var s = K.screen('План');
    var P = [['Free', '0 ₽', 'Базовая модель, ограниченные сообщения'], ['Go', '≈ 5 $', 'Больше сообщений и загрузок'], ['Plus', '≈ 20 $', 'Модели «Думать», голос, исследования'], ['Pro', '≈ 200 $', 'Максимальные лимиты и Pro-модель']];
    var g = K.group(s.body, 'Планы', 'Цены ориентировочные; актуальные условия — на сайте. Оплата в приложении на iOS 6 недоступна.');
    P.forEach(function (p) { K.cell(g, { titleHTML: K.esc(p[0]) + (p[0] === M.user.plan ? ' <span class="badge-plan" style="margin:0 0 0 4px;vertical-align:2px">Ваш</span>' : ''), sub: p[2], value: p[1], noArrow: true }).classList.add('big'); });
    if (on('subscription.web_purchase')) {
      var g2 = K.group(s.body, null, 'Откроется в Safari.');
      K.cell(g2, { title: 'Изменить план на сайте', cls: 'link', action: function () {} });
      K.cell(g2, { title: 'Управление подпиской', cls: 'link', action: function () { K.alert({ title: 'Где оформлена подписка?', message: 'Подписку, купленную на другой платформе, меняют там же. Веб-подписку — на сайте.', buttons: [{ title: 'OK' }] }); } });
      s.body.appendChild(K.h('div', 'note', 'Если оплата не пройдёт, здесь появится предупреждение со сроком, до которого сохраняется доступ.'));
    }
    return s;
  }
})();
