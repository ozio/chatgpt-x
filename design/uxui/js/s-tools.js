/* Drawer destinations: translate, library, projects, images, GPTs, tasks, locked chats. */
(function () {
  'use strict';
  var S = window.S;
  var on = M.on;
  var LANGS = ['Определить', 'Русский', 'English', 'Deutsch', 'Français', 'Español', 'Татарча', '中文'];

  /* ---------- Translate (8; languages and sharing 7) ---------- */
  S.translate = function () {
    var s = K.screen('Перевод');
    var from = 0, to = 2;
    var bar = K.h('div', 'toolbar top tr-bar');
    s.el.insertBefore(bar, s.scroll);
    function drawBar() {
      if (on('tools.translate_language')) {
        bar.innerHTML = '<span class="lang">' + LANGS[from] + '</span><span class="swap">' + K.barGlyph('swap', 20) + '</span><span class="lang">' + LANGS[to] + '</span>';
        var ls = bar.querySelectorAll('.lang');
        K.tap(ls[0], function () { pick(true); }, { instant: true });
        K.tap(ls[1], function () { pick(false); }, { instant: true });
        K.tap(bar.querySelector('.swap'), function () { if (from === 0) from = 1; var t = from; from = to; to = t; drawBar(); out.innerHTML = ''; }, { instant: true });
      } else bar.innerHTML = '<span class="lang fixed">Определить</span><span class="arrow">→</span><span class="lang fixed">English</span>';
    }
    function pick(isFrom) {
      K.sheet({ title: isFrom ? 'С какого языка' : 'На какой язык', buttons: LANGS.filter(function (l, i) { return isFrom || i > 0; }).map(function (l) { var i = LANGS.indexOf(l); return { title: l, check: i === (isFrom ? from : to), action: function () { if (isFrom) from = i; else to = i; drawBar(); } }; }) });
    }
    drawBar();
    var box = K.h('div', 'tr-box', '<textarea placeholder="Введите или вставьте текст"></textarea><div class="tf"><span class="lbl"></span><span class="pill go">Перевести</span></div>');
    s.body.appendChild(box);
    var res = K.h('div', 'tr-box hidden', '<div class="out"></div><div class="tf"><span class="lbl">' + LANGS[to] + '</span>' + (on('tools.translate_share') ? '<span class="pill">Копировать</span><span class="pill">Поделиться</span>' : '') + '</div>');
    s.body.appendChild(res);
    var out = res.querySelector('.out'), ta = box.querySelector('textarea');
    ta.value = 'Прошу перенести оплату аренды на пять дней.';
    K.tap(box.querySelector('.pill'), function () {
      if (!ta.value.trim()) return;
      res.classList.remove('hidden'); out.innerHTML = '<span class="spinner small">' + K.spinnerSVG('#6b7a72') + '</span>';
      box.querySelector('.lbl').textContent = from === 0 ? 'Определён: русский' : '';
      res.querySelector('.lbl').textContent = LANGS[to];
      setTimeout(function () { out.textContent = to === 2 ? 'I would like to postpone the rent payment by five days.' : (to === 1 ? 'Прошу перенести оплату аренды на пять дней.' : 'Ich möchte die Mietzahlung um fünf Tage verschieben.'); }, 900);
    }, { instant: true });
    var ps = res.querySelectorAll('.pill');
    if (ps[0]) K.tap(ps[0], function () { K.hud('Скопировано'); }, { instant: true });
    if (ps[1]) K.tap(ps[1], function () { K.sheet({ buttons: [{ title: 'Отправить по почте' }, { title: 'Отправить сообщением' }, { title: 'Открыть в новом чате', action: function () { S.openChat(null); } }] }); }, { instant: true });
    s.body.appendChild(K.h('div', 'note', 'Перевод не сохраняется в истории чатов.'));
    return s;
  };

  /* ---------- Library (7; folders, trash, favourites, grid 6) ---------- */
  var KIND = { pdf: ['file', 'red'], sheet: ['chart', 'green'], image: ['photo', 'purple'], text: ['file', 'gray'], doc: ['file', 'blue'] };
  S.library = function () {
    var s = K.screen('Библиотека');
    var tab = 0, grid = false, q = '';
    if (on('library.filter_sort_layout')) s.right = { title: 'Сетка', action: function () { grid = !grid; s.right.title = grid ? 'Список' : 'Сетка'; s.nav.refreshBar(s); draw(); } };
    if (on('library.search')) {
      var sb = K.h('div', 'searchbar', '<div class="sf"><span class="mag">' + K.glyph('search', 14, '#7f9188') + '</span><input type="search" placeholder="Поиск в библиотеке"><span class="clear">✕</span></div>');
      s.body.appendChild(sb);
      sb.querySelector('input').addEventListener('input', function (e) { q = e.target.value.toLowerCase(); K.cls(sb, 'has-text', !!q); draw(); }, false);
    }
    if (on('library.favorite')) {
      var w = K.h('div', 'seg-wrap'); w.appendChild(K.seg(['Все', 'Избранное', 'Удалённые'], 0, function (i) { tab = i; draw(); }, true)); s.body.appendChild(w);
    }
    var list = K.h('div', ''); s.body.appendChild(list);
    function fileMenu(f) {
      var b = [{ title: 'Спросить о файле в новом чате', action: function () { S.openChat(null); setTimeout(function () { var t = S.front().top(); if (t.el.querySelector('.composer')) K.hud('Файл приложен', 'none'); }, 400); } }];
      if (on('library.conversation_files') && f.chat) b.push({ title: 'Открыть чат с файлом', action: function () { S.openChat(f.chat); } });
      if (on('library.favorite')) b.push({ title: f.fav ? 'Убрать из избранного' : 'В избранное', action: function () { f.fav = !f.fav; draw(); } });
      if (on('library.rename')) b.push({ title: 'Переименовать', action: function () { K.alert({ title: 'Переименовать', field: { value: f.name }, buttons: [{ title: 'Отмена', cancel: true }, { title: 'Сохранить', action: function (v) { if (v) { f.name = v; draw(); } } }] }); } });
      if (on('library.move')) b.push({ title: 'Переместить в папку…', action: function () { K.sheet({ buttons: M.folders.map(function (fo) { return { title: fo.name, action: function () { K.hud('Перемещено'); } }; }) }); } });
      if (on('library.delete')) b.push({ title: 'Удалить', red: true, action: function () { K.alert({ title: 'Удалить «' + f.name + '»?', message: f.chat ? 'Файл используется в чатах и проектах — там он станет недоступен. Его можно восстановить из «Удалённых» в течение 30 дней.' : 'Файл можно восстановить в течение 30 дней.', buttons: [{ title: 'Отмена', cancel: true }, { title: 'Удалить', red: true, action: function () { M.library.splice(M.library.indexOf(f), 1); M.trash.unshift(f); draw(); } }] }); } });
      K.sheet({ title: f.name + ' · ' + K.bytes(f.size), buttons: b });
    }
    function draw() {
      list.innerHTML = '';
      if (tab === 2) {
        var gt = K.group(list, null, 'Файлы удаляются навсегда через 30 дней.');
        M.trash.forEach(function (f) { K.cell(gt, { title: f.name, sub: 'Удалён ' + K.ago(f.t), icon: K.tile(KIND[f.kind][0], 'gray'), noArrow: true, action: function () { K.sheet({ title: f.name, buttons: [{ title: 'Восстановить', action: function () { M.trash.splice(M.trash.indexOf(f), 1); M.library.unshift(f); draw(); } }, { title: 'Удалить навсегда', red: true, action: function () { M.trash.splice(M.trash.indexOf(f), 1); draw(); } }] }); } }); });
        if (!M.trash.length) list.innerHTML = '<div class="empty"><b>Корзина пуста</b></div>';
        else if (on('library.delete_forever')) { var r = K.h('div', 'btn-row', '<div class="button red">Очистить корзину</div>'); list.appendChild(r); K.tap(r.firstChild, function () { K.sheet({ title: 'Удалить все файлы из корзины навсегда?', buttons: [{ title: 'Очистить', red: true, action: function () { M.trash.length = 0; draw(); } }] }); }); }
        return;
      }
      var items = M.library.filter(function (f) { return (!q || f.name.toLowerCase().indexOf(q) >= 0) && (tab !== 1 || f.fav); });
      if (on('library.folders') && tab === 0 && !q) {
        var gf = K.group(list, 'Папки');
        M.folders.forEach(function (fo) { K.cell(gf, { title: fo.name, icon: K.tile('folder', 'blue'), value: String(fo.n), action: function () { K.hud('Открыта папка «' + fo.name + '»', 'none'); } }); });
        K.cell(gf, { title: 'Новая папка', cls: 'link', icon: K.tile('plus', 'gray'), action: function () { K.alert({ title: 'Новая папка', field: { placeholder: 'Название' }, buttons: [{ title: 'Отмена', cancel: true }, { title: 'Создать', action: function (v) { if (v) { M.folders.push({ name: v, n: 0 }); draw(); } } }] }); } });
      }
      if (grid) {
        var gr = K.h('div', 'grid');
        items.forEach(function (f) { var it = K.h('div', 'gi', f.art ? '<div class="art ' + f.art + '"></div>' : '<div style="height:100px;background:#fff;text-align:center;padding-top:22px;font-size:10px;color:#4b5d55">' + K.tile(KIND[f.kind][0], KIND[f.kind][1], 40) + '<div style="margin-top:6px;padding:0 4px;overflow:hidden;white-space:nowrap;text-overflow:ellipsis">' + K.esc(f.name) + '</div></div>'); K.tap(it, function () { fileMenu(f); }); gr.appendChild(it); });
        list.appendChild(gr);
      } else {
        var g = K.group(list, tab === 1 ? 'Избранное' : 'Файлы', on('library.mounted_sources') && tab === 0 ? null : null);
        items.forEach(function (f) { K.cell(g, { title: f.name, sub: K.bytes(f.size) + ' · ' + K.ago(f.t), icon: K.tile(KIND[f.kind][0], KIND[f.kind][1]), noArrow: true, action: function () { fileMenu(f); } }); });
        if (!items.length) list.appendChild(K.h('div', 'empty', '<b>Ничего не найдено</b>'));
      }
      if (on('library.mounted_sources') && tab === 0 && !q) { var gm = K.group(list, 'Подключённые хранилища'); K.cell(gm, { title: 'Google Drive', sub: 'Синхронизировано 5 мин назад', icon: K.tile('cloud', 'yellow'), action: function () { K.hud('Google Drive', 'none'); } }); }
    }
    draw();
    return s;
  };

  /* ---------- Projects ---------- */
  var PC = ['orange', 'blue', 'green', 'purple'];
  S.projectScreen = function (id) {
    var p = M.project(id);
    var s = K.screen(p.name);
    s.right = { icon: K.barGlyph('compose'), action: function () { S.openChat(null, { project: p.id }); } };
    var tab = 0;
    var w = K.h('div', 'seg-wrap'); w.appendChild(K.seg(['Чаты', 'Файлы', 'Настройки'], 0, function (i) { tab = i; draw(); }, true)); s.body.appendChild(w);
    var box = K.h('div', ''); s.body.appendChild(box);
    function draw() {
      box.innerHTML = '';
      if (tab === 0) {
        var chats = M.chats.filter(function (c) { return c.project === p.id; });
        var g = K.group(box, null, 'Чаты проекта учитывают его файлы и инструкции.');
        K.cell(g, { title: 'Новый чат в проекте', cls: 'link', icon: K.tile('compose', p.color), action: function () { S.openChat(null, { project: p.id }); } });
        chats.forEach(function (c) { var cc = K.cell(g, { title: c.title, sub: K.ago(c.t), action: function () { S.openChat(c.id, { project: p.id }); } }); if (on('projects.move_chat')) K.hold(cc, function () { K.sheet({ title: c.title, buttons: [{ title: 'Убрать из проекта', action: function () { c.project = null; draw(); } }] }); }); });
      } else if (tab === 1) {
        var gf = K.group(box, 'Файлы проекта', 'Доступны во всех чатах проекта.');
        p.files.forEach(function (f, i) { var c = K.cell(gf, { title: f.name, sub: K.bytes(f.size), icon: K.tile(KIND[f.kind][0], KIND[f.kind][1]), noArrow: true }); K.swipeDelete(c, 'Удалить', function () { p.files.splice(i, 1); draw(); }); });
        K.cell(gf, { title: 'Добавить файл', cls: 'link', icon: K.tile('plus', 'gray'), action: function () { S.filePicker(function (f) { p.files.push({ name: f.name, size: 300e3, kind: f.kind === 'image' ? 'image' : 'pdf' }); draw(); }); } });
      } else {
        var gm = K.group(box, 'Память проекта', 'Изолированная память: проект не видит другие чаты, а другие чаты — его. Выбирается при создании, если сервер разрешает.');
        var cells = [['По умолчанию', 'default'], ['Только проект', 'project']].map(function (x) { return K.cell(gm, { title: x[0], plain: true, noArrow: true, check: p.memory === x[1], action: function (c) { p.memory = x[1]; cells.forEach(function (y) { K.cls(y, 'checked', y === c); }); } }); });
        if (on('projects.instructions')) {
          var gi = K.group(box, 'Инструкции проекта');
          var c = K.cell(gi, { title: '', cls: 'area' }); c.innerHTML = '';
          var ta = document.createElement('textarea'); ta.value = p.instructions; c.appendChild(ta);
          ta.addEventListener('input', function () { p.instructions = ta.value; }, false);
        }
        if (on('projects.edit')) {
          var ge = K.group(box, 'Оформление');
          K.cell(ge, { title: 'Название', plain: true, value: K.esc(p.name), action: function () { K.alert({ title: 'Название проекта', field: { value: p.name }, buttons: [{ title: 'Отмена', cancel: true }, { title: 'Сохранить', action: function (v) { if (v) { p.name = v; s.nav.setTitle(s, v); draw(); S.renderDrawer(); } } }] }); } });
          K.cell(ge, { title: 'Цвет', plain: true, value: { orange: 'Оранжевый', blue: 'Синий', green: 'Зелёный', purple: 'Фиолетовый' }[p.color], action: function () { p.color = PC[(PC.indexOf(p.color) + 1) % PC.length]; draw(); } });
        }
        if (on('projects.delete')) {
          var r = K.h('div', 'btn-row', '<div class="button red">Удалить проект</div>'); box.appendChild(r);
          K.tap(r.firstChild, function () { K.sheet({ title: 'Удалить «' + p.name + '» вместе с чатами и файлами? Это нельзя отменить.', buttons: [{ title: 'Удалить проект', red: true, action: function () { M.projects.splice(M.projects.indexOf(p), 1); M.chats = M.chats.filter(function (c) { return c.project !== p.id; }); S.openChat(null); } }] }); });
        }
      }
    }
    draw();
    return s;
  };
  S.newProject = function () {
    K.alert({ title: 'Новый проект', message: 'Проект объединяет чаты, файлы и инструкции.', field: { placeholder: 'Название' }, buttons: [{ title: 'Отмена', cancel: true }, { title: 'Создать', action: function (v) { if (!v) return; var p = { id: 'p' + M.uid(), name: v, color: 'green', memory: 'default', instructions: '', files: [] }; M.projects.push(p); S.openRoot('project', p.id); } }] });
  };

  /* ---------- Images (6) ---------- */
  S.imagesScreen = function () {
    var s = K.screen('Изображения', { cls: 'paper' });
    s.right = { icon: K.barGlyph('plus'), action: function () { S.openChat(null); K.hud('Опишите изображение', 'none'); } };
    var g = K.h('div', 'grid');
    M.images.forEach(function (im) { var it = K.h('div', 'gi', '<div class="art ' + im.art + '"></div>'); K.tap(it, function () { S.lightbox(im); }); g.appendChild(it); });
    s.body.appendChild(g);
    return s;
  };

  /* ---------- GPTs (6) ---------- */
  S.gptsScreen = function () {
    var s = K.screen('GPT');
    var cat = 0, q = '';
    var sb = K.h('div', 'searchbar', '<div class="sf"><span class="mag">' + K.glyph('search', 14, '#7f9188') + '</span><input type="search" placeholder="Поиск GPT"><span class="clear">✕</span></div>');
    s.body.appendChild(sb);
    sb.querySelector('input').addEventListener('input', function (e) { q = e.target.value.toLowerCase(); draw(); }, false);
    var w = K.h('div', 'seg-wrap'); w.appendChild(K.seg(['Популярные', 'Учёба', 'Работа'], 0, function (i) { cat = i; draw(); }, true)); s.body.appendChild(w);
    var box = K.h('div', ''); s.body.appendChild(box);
    function card(g, x, mine) {
      var c = K.cell(g, { titleHTML: K.esc(x.name), sub: K.esc(x.desc) + (x.by ? '<br><span style="font-size:12px">' + x.by + '</span>' : ''), icon: K.tile(x.glyph, x.color, 40), action: function () { s.nav.push(detail(x, mine)); } });
      c.style.paddingLeft = '62px'; c.querySelector('.cicon').style.top = '10px';
    }
    function draw() {
      box.innerHTML = '';
      if (!q && on('gpts.personal')) { var gm = K.group(box, 'Мои GPT'); M.myGpts.forEach(function (x) { card(gm, x, true); }); }
      var g = K.group(box, q ? 'Результаты' : 'Подборка');
      M.gpts.filter(function (x) { return q ? x.name.toLowerCase().indexOf(q) >= 0 : x.cat === cat || cat === 0; }).forEach(function (x) { card(g, x); });
    }
    function detail(x, mine) {
      var d = K.screen(x.name);
      d.body.innerHTML = '<div class="hero">' + K.tile(x.glyph, x.color, 57) + '<div class="nm">' + K.esc(x.name) + '</div><div class="em">' + K.esc(x.desc) + '</div></div>';
      var r = K.h('div', 'btn-row', '<div class="button green">Начать чат</div>'); d.body.appendChild(r);
      K.tap(r.firstChild, function () { S.openChat(null); });
      var g = K.group(d.body, 'Примеры');
      ['Что приготовить из курицы и риса?', 'Меню на неделю до 3000 ₽'].forEach(function (e) { K.cell(g, { title: e, plain: true, action: function () { S.openChat(null); } }); });
      if (on('gpts.action_permissions')) {
        var gp = K.group(d.body, 'Действия', 'Этот GPT может обращаться к внешнему сервису.');
        var c = K.cell(gp, { title: 'Спрашивать перед действием', cls: 'has-switch' }); c.querySelector('.t').classList.add('plain'); c.appendChild(K.toggle(true));
      }
      return d;
    }
    draw();
    return s;
  };

  /* ---------- Tasks (6) ---------- */
  S.tasksScreen = function () {
    var s = K.screen('Задачи');
    s.right = { icon: K.barGlyph('plus'), action: function () { edit(null); } };
    function draw() {
      s.body.innerHTML = '';
      var act = M.tasks.filter(function (t) { return t.active; }), paused = M.tasks.filter(function (t) { return !t.active; });
      function sect(title, list) {
        if (!list.length) return;
        var g = K.group(s.body, title);
        list.forEach(function (t) { K.cell(g, { titleHTML: '<span class="lamp ' + (t.active ? 'ok' : '') + '"></span>' + K.esc(t.name), sub: t.when + ' · последний запуск ' + t.last, action: function () { s.nav.push(detail(t)); } }); });
      }
      sect('Активные', act); sect('На паузе', paused);
      s.body.appendChild(K.h('div', 'note', 'Задачи выполняются на сервере; результат появляется в чате задачи. На iOS 6 без push — увидите его при открытии приложения.'));
    }
    function detail(t) {
      var d = K.screen(t.name);
      function dd() {
        d.body.innerHTML = '';
        var g = K.group(d.body, null);
        K.cell(g, { title: 'Запрос', sub: K.esc(t.prompt), noArrow: true }).classList.add('big');
        K.cell(g, { title: 'Расписание', plain: true, value: t.when, action: function () { edit(t); } });
        var c = K.cell(g, { title: 'Активна', cls: 'has-switch' }); c.querySelector('.t').classList.add('plain'); c.appendChild(K.toggle(t.active, function (v) { t.active = v; draw(); S.renderDrawer(); }));
        var r = K.h('div', 'btn-row', '<div class="button green">Запустить сейчас</div><div class="button">Изменить</div><div class="button red">Удалить задачу</div>'); d.body.appendChild(r);
        K.tap(r.childNodes[0], function () { var h = K.hud('Запускаю…', 'busy'); setTimeout(function () { t.last = 'только что'; h.done('Готово'); dd(); }, 1300); });
        K.tap(r.childNodes[1], function () { edit(t); });
        K.tap(r.childNodes[2], function () { K.sheet({ title: 'Удалить «' + t.name + '»?', buttons: [{ title: 'Удалить', red: true, action: function () { M.tasks.splice(M.tasks.indexOf(t), 1); d.nav.pop(); draw(); } }] }); });
      }
      dd();
      d.onReturn = dd;
      return d;
    }
    function edit(t) {
      var isNew = !t;
      t = t || { id: M.uid(), name: '', prompt: '', when: 'Ежедневно в 9:00', active: true, last: '—' };
      var e = K.screen(isNew ? 'Новая задача' : 'Изменить');
      var g = K.group(e.body, null);
      var cn = K.cell(g, { title: 'Название', cls: 'field-cell' }); var inN = K.h('input', 'field'); inN.value = t.name; inN.placeholder = 'Например, «Курс валют»'; cn.appendChild(inN);
      var gp = K.group(e.body, 'Что сделать');
      var cp = K.cell(gp, { title: '', cls: 'area' }); cp.innerHTML = ''; var ta = document.createElement('textarea'); ta.value = t.prompt; ta.placeholder = 'Инструкция для ChatGPT'; cp.appendChild(ta);
      var gs = K.group(e.body, 'Когда');
      var rep = ['Однократно', 'Каждый час', 'Ежедневно', 'Еженедельно', 'Ежемесячно', 'Ежегодно'], ri = 2;
      var w = K.h('div', 'seg-wrap'); w.style.margin = '0 0 8px';
      var cells = [];
      K.cell(gs, { title: 'Повтор', plain: true, value: rep[ri], action: function (c) { K.sheet({ buttons: rep.map(function (r, i) { return { title: r, check: i === ri, action: function () { ri = i; c.querySelector('.v').textContent = r; } }; }) }); } });
      K.cell(gs, { title: 'Время', plain: true, value: '9:00', action: function (c) { K.sheet({ title: 'Время запуска', buttons: [{ title: '8:00' }, { title: '9:00', check: true }, { title: 'Утром (гибко)' }, { title: 'Вечером (гибко)' }] }); } });
      void w; void cells;
      e.left = { title: 'Отмена', action: function () { nav.dismiss(); } };
      e.right = { title: 'Сохранить', style: 'done', action: function () {
        t.name = inN.value || 'Без названия'; t.prompt = ta.value; t.when = rep[ri] + ' в 9:00';
        if (isNew) M.tasks.unshift(t);
        nav.dismiss(); draw(); S.renderDrawer();
      } };
      var nav = new K.Nav(); nav.push(e, false); K.present(nav);
    }
    draw();
    s.onReturn = draw;
    return s;
  };

  /* ---------- Locked chats (6) ---------- */
  S.lockedScreen = function () {
    var s = { title: 'Закрытые чаты', backTitle: 'Закрытые' };
    s.el = K.h('div', 'linen');
    s.el.style.cssText = 'position:absolute;left:0;top:0;right:0;bottom:0';
    var pad = S.pinPad({ title: 'Введите PIN', msg: 'Закрытые чаты скрыты из списка и поиска.', check: function (v) { return v === M.prefs.pin; }, ok: function () { s.el.removeChild(pad); list(); } });
    s.el.appendChild(pad);
    function list() {
      var sc = K.h('div', 'scroll'), inner = K.h('div', 'inner'); sc.appendChild(inner); s.el.appendChild(sc);
      var lk = M.chats.filter(function (c) { return c.locked; });
      if (!lk.length) { inner.innerHTML = '<div class="empty">' + K.tile('lock', 'graphite', 57) + '<b>Нет закрытых чатов</b>Закрыть чат: удерживайте его в боковом меню.</div>'; return; }
      var g = K.group(inner, null, 'Пока чат закрыт, ChatGPT не пополняет из него память. Открытый снова чат учитывает обычные настройки.');
      lk.forEach(function (c) {
        var cc = K.cell(g, { title: c.title, sub: K.ago(c.t), icon: K.tile('lock', 'graphite'), action: function () { S.front().push(S.chatScreen(c.id, { pushed: true })); } });
        K.hold(cc, function () { K.sheet({ title: c.title, buttons: [{ title: 'Снять защиту', action: function () { c.locked = false; inner.innerHTML = ''; sc.parentNode.removeChild(sc); list(); K.hud('Чат снова в списке'); } }] }); });
      });
    }
    return s;
  };
})();
