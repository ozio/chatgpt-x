/* Shell: status bar, reveal drawer, front navigation, launch/restore, showcase messages. */
(function () {
  'use strict';
  var S = window.S;
  var on = M.on;
  var front = null, app = null, drawerEl = null, curChat = null, curRoot = 'chat';

  /* ---------- Shared helpers ---------- */
  S.modalScreen = function (s, doneTitle, opts) {
    opts = opts || {};
    var nav = new K.Nav();
    var rb = { title: doneTitle || 'Готово', style: 'done', action: function () { if (opts.onDone && opts.onDone() === false) return; nav.dismiss(); } };
    if (opts.cancel) s.left = { title: 'Отмена', action: function () { nav.dismiss(); } };
    if (doneTitle !== null) s.right = s.right || rb;
    nav.push(s, false);
    return K.present(nav, opts);
  };
  S.modalNav = function (s, opts) {
    var nav = new K.Nav();
    s.right = s.right || { title: 'Готово', style: 'done', action: function () { nav.dismiss(); } };
    nav.push(s, false);
    return K.present(nav, opts);
  };
  S.editor = function (o) {
    var s = K.screen(o.title, { cls: 'paper' });
    var ta = document.createElement('textarea');
    ta.value = o.text || '';
    ta.style.cssText = 'position:absolute;left:0;top:0;right:0;bottom:' + (o.note ? 54 : 0) + 'px;width:100%;border:0;outline:none;padding:12px;font-size:17px;line-height:23px;resize:none;background:#fff';
    s.el.innerHTML = '';
    s.el.appendChild(ta);
    if (o.note) { var n = K.h('div', 'note', o.note); n.style.cssText = 'position:absolute;left:0;right:0;bottom:0;height:54px;margin:0;padding:8px 14px;border-top:1px solid #dfe6e2;background:#f3f6f4'; s.el.appendChild(n); }
    var nav = S.modalScreen(s, o.done || 'Готово', { cancel: true, onDone: function () { o.action(ta.value.trim()); } });
    setTimeout(function () { ta.focus(); }, 450);
    return nav;
  };
  S.approval = function (app, action, params, ok) {
    K.alert({ title: 'Разрешить действие?', message: '«' + app + '» хочет: ' + action + '.', list: params, note: on('privacy.apps_permissions') ? 'Правила разрешений — в Настройках › Приложения.' : '', buttons: [{ title: 'Отклонить', cancel: true, action: function () { K.hud('Отклонено', 'none'); } }, { title: 'Разрешить', action: ok }] });
  };

  /* ---------- Status bar ---------- */
  function statusBar() {
    var sb = K.h('div', '');
    sb.id = 'statusbar';
    sb.innerHTML = '<span class="sb-left"><span class="bars"><i style="height:4px"></i><i style="height:6px"></i><i style="height:8px"></i><i style="height:10px"></i><i style="height:11px;opacity:.35"></i></span>Carrier <svg class="wifi" style="display:inline-block;vertical-align:-1px;margin-left:2px" width="14" height="10" viewBox="0 0 14 10"><path d="M7 9.5L.6 3.4a9.4 9.4 0 0 1 12.8 0z" fill="#fff"/></svg><span class="netspin">' + K.spinnerSVG('#fff') + '</span></span><span class="sb-time"></span><span class="sb-right">84 % <span class="battery"><i></i></span></span>';
    var t = sb.querySelector('.sb-time');
    function clock() { t.textContent = K.clock(Date.now()); }
    clock(); setInterval(clock, 20000);
    M.on_('conn scenario', function () { K.cls(sb, 'busy', M.conn.state === 'preparing'); K.cls(sb, 'offline', !!M.scenario.offline); });
    var taps = 0, tt = null;
    K.tap(sb, function () {
      taps++; clearTimeout(tt); tt = setTimeout(function () { taps = 0; }, 450);
      if (taps === 3) { taps = 0; S.prototypeScreen(true); }
    }, { instant: true });
    return sb;
  }

  /* ---------- Drawer ---------- */
  S.toggleDrawer = function (open) {
    if (open === undefined) open = !app.classList.contains('drawer-open');
    if (open) { var a = document.activeElement; if (a && a.blur) a.blur(); renderDrawer(); }
    K.cls(app, 'drawer-open', open);
  };
  var dq = '';
  function dayLabel(t) {
    var d = Math.floor((Date.now() - t) / 86400000);
    if (d < 1) return 'Сегодня';
    if (d < 2) return 'Вчера';
    if (d < 7) return 'Последние 7 дней';
    if (d < 30) return 'Последние 30 дней';
    return 'Раньше';
  }
  var shown = 7;
  function renderDrawer() {
    var d = drawerEl;
    var keepScroll = d.querySelector('.dscroll') ? d.querySelector('.dscroll').scrollTop : 0;
    d.innerHTML = '';
    var box = K.h('div', 'dr linen-dark');
    d.appendChild(box);
    var hasSearch = on('search.history');
    if (hasSearch) {
      var sb = K.h('div', 'searchbar dark', '<div class="sf"><span class="mag">' + K.glyph('search', 14, '#7f9188') + '</span><input type="search" placeholder="' + (on('search.global') ? 'Поиск везде' : 'Поиск по чатам') + '"><span class="clear">✕</span></div>');
      box.appendChild(sb);
      var inp = sb.querySelector('input');
      inp.value = dq;
      K.cls(sb, 'has-text', !!dq);
      inp.addEventListener('input', function () { dq = inp.value; K.cls(sb, 'has-text', !!dq); list(); }, false);
      K.tap(sb.querySelector('.clear'), function () { dq = ''; inp.value = ''; K.cls(sb, 'has-text', false); list(); }, { instant: true });
    }
    var sc = K.h('div', 'dscroll' + (hasSearch ? '' : ' nosearch'));
    box.appendChild(sc);
    function row(glyph, title, fn, cls, cnt) {
      var r = K.h('div', 'row' + (cls ? ' ' + cls : ''), (glyph ? '<span class="gl">' + K.glyph(glyph, 20, '#cfe7da') + '</span>' : '') + K.esc(title) + (cnt != null ? '<span class="cnt">' + cnt + '</span>' : ''));
      K.tap(r, fn);
      sc.appendChild(r);
      return r;
    }
    function head(t) { sc.appendChild(K.h('div', 'dh', K.esc(t))); }
    function chatRow(c) {
      var g = c.pinned && on('chat.pin') ? 'pin' : (c.locked && on('chat.lock') ? 'lock' : null);
      var r = row(g, c.title, function () { S.openChat(c.id); }, 'chat' + (g ? ' has-gl' : '') + (curChat === c.id ? ' cur' : ''));
      if (g) r.querySelector('.gl').innerHTML = K.glyph(g, 14, '#cfe7da');
      if (on('chat.rename')) K.hold(r, function () { chatMenu(c); });
      if (on('chat.delete')) K.swipeDelete(r, 'Удалить', function () { confirmDelete(c); });
    }
    function list() {
      sc.innerHTML = '';
      if (dq) return searchResults();
      row('compose', 'Новый чат', function () { S.openChat(null); }, curRoot === 'chat' && !curChat ? 'cur' : '');
      if (on('tools.translate')) row('translate', 'Перевод', function () { S.openRoot('translate'); }, curRoot === 'translate' ? 'cur' : '');
      if (on('library.browse')) row('library', 'Библиотека', function () { S.openRoot('library'); }, curRoot === 'library' ? 'cur' : '');
      if (on('images.library')) row('images', 'Изображения', function () { S.openRoot('images'); }, curRoot === 'images' ? 'cur' : '');
      if (on('gpts.explore')) row('gpt', 'GPT', function () { S.openRoot('gpts'); }, curRoot === 'gpts' ? 'cur' : '');
      if (on('tasks.list')) row('clock', 'Задачи', function () { S.openRoot('tasks'); }, curRoot === 'tasks' ? 'cur' : '', M.tasks.filter(function (t) { return t.active; }).length);
      if (window.C && C.tier > 0) row('terminal', 'Codex', function () { S.codexEnter(function () { S.openRoot('codex'); }); }, curRoot === 'codex' ? 'cur' : '', C.verified ? (C.waiting() || null) : null);
      if (on('chat.locked_list')) row('lock', 'Закрытые чаты', function () { S.openRoot('locked'); }, curRoot === 'locked' ? 'cur' : '');
      if (on('projects.chat')) {
        head('Проекты');
        if (on('projects.create')) row('plus', 'Новый проект', function () { S.newProject(); }, 'sub');
        M.projects.forEach(function (p) {
          var r = row(null, p.name, function () { S.openRoot('project', p.id); }, 'sub' + (curRoot === 'project:' + p.id ? ' cur' : ''), M.chats.filter(function (c) { return c.project === p.id; }).length);
          r.insertAdjacentHTML('afterbegin', '<span class="dot" style="background-image:-webkit-linear-gradient(top,' + ({ orange: '#ffc874,#e07a0c', blue: '#7fb5f5,#2a66cc', green: '#7fdcab,#1e9656', purple: '#c6a4f4,#6c3fc2' }[p.color]) + ')"></span>');
        });
      }
      var h = M.history();
      var pinned = on('chat.pin') ? h.filter(function (c) { return c.pinned; }) : [];
      if (pinned.length) { head('Закреплённые'); pinned.forEach(chatRow); }
      var rest = h.filter(function (c) { return pinned.indexOf(c) < 0; });
      var lastLabel = null;
      rest.slice(0, shown).forEach(function (c) { var l = dayLabel(c.t); if (l !== lastLabel) { head(l); lastLabel = l; } chatRow(c); });
      if (rest.length > shown) {
        var more = row(null, 'Показать ещё', function () {
          more.innerHTML = '<span class="spinner small">' + K.spinnerSVG('#cfe7da') + '</span>Загружаю…';
          setTimeout(function () { shown += 10; list(); }, 700);
        }, 'more');
      }
      if (!h.length) sc.appendChild(K.h('div', 'dempty', 'Здесь появятся ваши разговоры.'));
    }
    function searchResults() {
      var q = dq.toLowerCase();
      var chats = M.history().filter(function (c) { return c.title.toLowerCase().indexOf(q) >= 0 || c.msgs.some(function (m) { return (m.md || '').toLowerCase().indexOf(q) >= 0; }); });
      head('Чаты · ' + chats.length);
      chats.forEach(chatRow);
      if (on('search.global')) {
        var pr = M.projects.filter(function (p) { return p.name.toLowerCase().indexOf(q) >= 0; });
        if (pr.length) { head('Проекты'); pr.forEach(function (p) { row('folder', p.name, function () { S.openRoot('project', p.id); }, 'sub'); }); }
        var fl = M.library.filter(function (f) { return f.name.toLowerCase().indexOf(q) >= 0; });
        if (fl.length) { head('Файлы'); fl.forEach(function (f) { row('file', f.name, function () { S.openRoot('library'); }, 'sub'); }); }
        var gp = M.gpts.filter(function (g) { return g.name.toLowerCase().indexOf(q) >= 0; });
        if (gp.length) { head('GPT'); gp.forEach(function (g) { row('gpt', g.name, function () { S.openRoot('gpts'); }, 'sub'); }); }
      }
      if (!chats.length) sc.appendChild(K.h('div', 'dempty', 'Ничего не найдено по запросу «' + K.esc(dq) + '».'));
    }
    list();
    sc.scrollTop = keepScroll;
    var foot = K.h('div', 'foot', '<span class="av">' + M.user.initials + '</span><div class="nm">' + K.esc(M.user.name) + '</div><div class="em">' + K.esc(M.user.email) + '</div><span class="gear">' + K.glyph('gear', 20, '#cfe7da') + '</span>');
    K.tap(foot, function () { S.toggleDrawer(false); setTimeout(function () { S.account(); }, 250); });
    box.appendChild(foot);
  }
  S.renderDrawer = function () { if (drawerEl) renderDrawer(); };
  M.on_('history', function () { if (app && app.classList.contains('drawer-open')) renderDrawer(); });

  function chatMenu(c) {
    var b = [];
    if (on('chat.pin')) b.push({ title: c.pinned ? 'Открепить' : 'Закрепить', action: function () { c.pinned = !c.pinned; renderDrawer(); } });
    if (on('chat.rename')) b.push({ title: 'Переименовать', action: function () { K.alert({ title: 'Переименовать чат', field: { value: c.title }, buttons: [{ title: 'Отмена', cancel: true }, { title: 'Сохранить', action: function (v) { if (v) { c.title = v; renderDrawer(); } } }] }); } });
    if (on('projects.move_chat')) b.push({ title: c.project ? 'Убрать из проекта' : 'В проект…', action: function () {
      if (c.project) { c.project = null; renderDrawer(); K.hud('Убрано из проекта'); return; }
      K.sheet({ title: 'Переместить в проект', buttons: M.projects.map(function (p) { return { title: p.name, action: function () { c.project = p.id; renderDrawer(); K.hud('Перемещено'); } }; }) });
    } });
    if (on('chat.share_link')) b.push({ title: 'Поделиться', action: function () { S.shareChat(c); } });
    if (on('chat.lock')) b.push({ title: 'Закрыть PIN-кодом', action: function () { S.lockChat(c, function () { renderDrawer(); }); } });
    if (on('chat.archive')) b.push({ title: 'В архив', action: function () { c.archived = true; if (curChat === c.id) S.openChat(null); renderDrawer(); K.hud('В архиве'); } });
    if (on('chat.delete')) b.push({ title: 'Удалить', red: true, action: function () { confirmDelete(c); } });
    K.sheet({ title: c.title, buttons: b });
  }
  function confirmDelete(c) {
    K.sheet({ title: 'Удалить «' + c.title + '»? Чат исчезнет на всех устройствах.', buttons: [{ title: 'Удалить чат', red: true, action: function () { M.chats.splice(M.chats.indexOf(c), 1); if (curChat === c.id) S.openChat(null); renderDrawer(); } }] });
  }

  /* ---------- Front navigation ---------- */
  S.openChat = function (id, opts) {
    curChat = id; curRoot = opts && opts.project ? 'project:' + opts.project : 'chat';
    front.setRoot(S.chatScreen(id, opts));
    S.toggleDrawer(false);
  };
  S.openRoot = function (name, arg) {
    var map = { translate: S.translate, library: S.library, images: S.imagesScreen, gpts: S.gptsScreen, tasks: S.tasksScreen, codex: S.codexScreen, locked: S.lockedScreen, project: S.projectScreen };
    var scr = map[name](arg);
    scr.left = { icon: K.barGlyph('menu'), action: function () { S.toggleDrawer(); } };
    curChat = null; curRoot = name + (arg ? ':' + arg : '');
    if (name === 'locked') curRoot = 'locked';
    front.setRoot(scr);
    S.toggleDrawer(false);
  };
  S.front = function () { return front; };

  /* ---------- Launch: native session restore, or welcome ---------- */
  function launch() {
    var l = K.h('div', 'welcome linen-dark', '<div class="wl-logo"><img src="img/icon-114.png" alt=""></div><h1>ChatGPT X</h1><div class="restoring"><span class="spinner">' + K.spinnerSVG('#e6f2ec') + '</span>Восстанавливаю сессию…</div>');
    l.style.zIndex = 70;
    K.main().appendChild(l);
    setTimeout(function () {
      l.style.webkitTransition = 'opacity .4s'; l.style.opacity = 0;
      setTimeout(function () { if (l.parentNode) l.parentNode.removeChild(l); }, 450);
      if (M.scenario.renewFail) { M.session.state = 'expired'; M.emit('session'); }
    }, 1300);
  }

  function boot() {
    /* ?nofx — no transitions (screenshots in a background tab, slow devices) */
    if (/[?&]nofx/.test(location.search)) { var st = document.createElement('style'); st.textContent = '*{-webkit-transition:none!important;transition:none!important}'; document.head.appendChild(st); }
    app = K.h('div', '');
    app.id = 'app';
    document.body.appendChild(app);
    app.appendChild(statusBar());
    var main = K.h('div', ''); main.id = 'main'; app.appendChild(main);
    var ov = K.h('div', ''); ov.id = 'overlay'; app.appendChild(ov);
    if (on('preferences.appearance') && M.prefs.theme === 1) app.classList.add('dark');

    drawerEl = K.h('div', ''); drawerEl.id = 'drawer'; main.appendChild(drawerEl);
    var fr = K.h('div', ''); fr.id = 'front'; main.appendChild(fr);
    front = new K.Nav();
    fr.appendChild(front.el);
    var catcher = K.h('div', 'front-catch'); fr.appendChild(catcher);
    K.tap(catcher, function () { S.toggleDrawer(false); }, { instant: true });
    // swipe right on the chat navbar opens the drawer, as in the Facebook-era apps
    renderDrawer();

    if (!M.signedIn) { S.welcome(); }
    else {
      front.push(S.chatScreen(null), false);
      if (/[?&]open=codex/.test(location.search) && window.C && C.tier > 0) S.openRoot('codex');
      launch();
    }
    document.addEventListener('touchmove', function (e) {
      if (!K.closest(e.target, 'scroll') && !K.closest(e.target, 'dscroll') && !K.closest(e.target, 'a-list') && !K.closest(e.target, 'tray') && e.target.tagName !== 'TEXTAREA') e.preventDefault();
    }, false);

    window.addEventListener('message', function (e) {
      var d = e.data || {};
      if (d.type === 'stage') { try { localStorage.setItem('rc-stage', d.value); } catch (x) {} location.replace(location.pathname + '?stage=' + d.value); }
      if (d.type === 'scenario') M.setScenario(d.key, d.value);
      if (d.type === 'codex' && window.C) C.setTier(d.value);
      if (d.type === 'cmd') S.command(d.name);
    }, false);
    if (window.parent !== window) { try { window.parent.postMessage({ type: 'ready', stage: M.stage, scenario: M.scenario, codex: window.C ? C.tier : 0 }, '*'); } catch (x) {} }
  }
  S.command = function (name) {
    if (name === 'signout') { try { localStorage.setItem('rc-signedout', '1'); } catch (x) {} location.reload(); }
    if (name === 'signin') { try { localStorage.removeItem('rc-signedout'); } catch (x) {} location.reload(); }
    if (name === 'relaunch') location.reload();
    if (name === 'shared') S.sharedLink();
    if (name === 'drawer') S.toggleDrawer(true);
    if (name === 'voice' && on('voice.conversation')) S.voice(front.top());
    if (name === 'account') S.account();
    if (name === 'codex' && window.C && C.tier > 0) S.codexEnter(function () { S.openRoot('codex'); });
  };
  S.setStage = function (v) {
    try { localStorage.setItem('rc-stage', v); } catch (x) {}
    if (window.parent !== window) { try { window.parent.postMessage({ type: 'stage', value: v }, '*'); } catch (x) {} }
    location.replace(location.pathname + '?stage=' + v);
  };

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot, false);
  else boot();
})();
