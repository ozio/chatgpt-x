/* Codex section: tasks on the user's computer or in the account's cloud, three graceful tiers.
   Tier 1 (9–10): the core loop — verify device, pick project, start, watch transcript,
   approve, answer, read commands and diff. Tier 2 (8): connections, cloud, model, plan,
   network approval, review, MCP. Tier 3 (1–7): organisation, settings and extras.
   Everything is simulated; nothing here talks to a network. */
(function () {
  'use strict';
  var S = window.S, C = window.C = {};
  var now = Date.now(), MIN = 60000, H = 3600000;

  /* ---------- Tier gating ---------- */
  var FEAT = {};
  window.CODEX_FEATURES.list.forEach(function (f) { FEAT[f.id] = f; });
  C.tier = 1;
  try {
    var q = /[?&]codex=(\d)/.exec(location.search), sv = localStorage.getItem('rc-codex');
    if (q) C.tier = +q[1]; else if (sv != null) C.tier = +sv;
  } catch (e) {}
  if ([0, 1, 2, 3].indexOf(C.tier) < 0) C.tier = 1;
  C.on = function (id) { var f = FEAT[id]; if (!f) { if (window.console) console.warn('unknown codex feature', id); return false; } return C.tier > 0 && f.tier <= C.tier; };
  C.setTier = function (v) {
    try { localStorage.setItem('rc-codex', v); } catch (e) {}
    if (window.parent !== window) { try { window.parent.postMessage({ type: 'codex', value: v }, '*'); } catch (e) {} }
    var u = location.search.replace(/[?&]codex=\d/, '');
    location.replace(location.pathname + (u ? u + '&' : '?') + 'codex=' + v + '&open=codex');
  };
  C.verified = false;
  try { C.verified = localStorage.getItem('rc-cx-verified') === '1'; } catch (e) {}
  if (C.tier < 1) C.verified = false;

  /* ---------- Mock data ---------- */
  C.workspaces = [
    { id: 'w1', name: 'shop-web', path: '~/src/shop-web', branch: 'main' },
    { id: 'w2', name: 'shop-api', path: '~/src/shop-api', branch: 'main' },
    { id: 'w3', name: 'dotfiles', path: '~/dotfiles', branch: 'master' }
  ];
  C.hosts = [
    { id: 'h1', name: 'MacBook Pro', via: 'SSH · 192.168.1.20', online: true },
    { id: 'h2', name: 'iMac в офисе', via: 'Сопряжение', online: false, seen: 'вчера в 19:40' }
  ];
  C.envs = [
    { id: 'e1', name: 'shop-web', repo: 'github.com/acme/shop-web', setup: 'npm ci · 41 с', machine: 'Стандартный' },
    { id: 'e2', name: 'shop-api', repo: 'github.com/acme/shop-api', setup: 'pip install -r requirements.txt · 1 мин 12 с', machine: 'Стандартный' }
  ];
  C.where = 'h1';
  C.models = [{ name: 'GPT-5.5-Codex', sub: 'Для кода, по умолчанию' }, { name: 'GPT-5.5', sub: 'Общий, для анализа и текста' }, { name: 'GPT-5.5 mini', sub: 'Быстро и экономно' }];
  C.prefs = { model: 0, effort: 1, fast: false, plan: false, policy: 1, style: 0, lock: false };

  function L(t) { var a = 0, d = 0; t.forEach(function (l) { if (l.charAt(0) === '+') a++; else if (l.charAt(0) === '-') d++; }); return [a, d]; }
  function file(p, k, hunks) { var a = 0, d = 0; hunks.forEach(function (h) { var x = L(h.lines); a += x[0]; d += x[1]; }); return { p: p, k: k, a: a, d: d, hunks: hunks }; }
  var DIFF_LINK = [
    file('src/auth/link.js', 'M', [{ h: 'function verifyLink(token)', o: 12, n: 12, lines: [
      ' export function verifyLink(token) {',
      '-  const data = jwt.decode(token);',
      '-  if (data.exp < Date.now()) return null;',
      '+  const data = jwt.verify(token, SECRET, {',
      '+    algorithms: ["HS256"],',
      '+    clockTolerance: 30',
      '+  });',
      '   return findUser(data.sub);',
      ' }'] }]),
    file('src/auth/link.test.js', 'A', [{ h: 'новый файл', o: 0, n: 1, lines: [
      '+import { verifyLink } from "./link";',
      '+',
      '+test("просроченная ссылка не пускает", () => {',
      '+  expect(verifyLink(expired)).toBeNull();',
      '+});'] }])
  ];
  var DIFF_CSS = [
    file('build/css.js', 'M', [{ h: 'async function buildCss()', o: 30, n: 30, lines: [
      ' async function buildCss() {',
      '-  const files = await glob("src/**/*.css");',
      '-  for (const f of files) await compile(f);',
      '+  const files = await glob("src/**/*.css");',
      '+  const stale = files.filter(cache.changed);',
      '+  await Promise.all(stale.map(compile));',
      '+  cache.save();',
      ' }'] }, { h: 'module.exports', o: 58, n: 59, lines: [
      ' module.exports = {',
      '-  buildCss',
      '+  buildCss,',
      '+  clearCache: cache.clear',
      ' };'] }]),
    file('build/cache.js', 'A', [{ h: 'новый файл', o: 0, n: 1, lines: [
      '+const fs = require("fs");',
      '+const FILE = ".cache/css.json";',
      '+let seen = load();',
      '+exports.changed = (f) => mtime(f) !== seen[f];',
      '+exports.save = () => fs.writeFileSync(FILE, JSON.stringify(seen));',
      '+exports.clear = () => { seen = {}; };'] }]),
    file('package.json', 'M', [{ h: '"scripts"', o: 6, n: 6, lines: [
      '   "scripts": {',
      '-    "css": "node build/css.js"',
      '+    "css": "node build/css.js",',
      '+    "css:clean": "node -e \\"require(\'./build/css\').clearCache()\\""',
      '   },'] }])
  ];
  DIFF_CSS[0].review = [{ after: 5, text: 'Кэш не сбрасывается при смене browserslist — после обновления браузеров CSS останется старым.' }];

  function tsk(o) { o.items = o.items || []; o.t = o.t || now; return o; }
  C.tasks = [
    tsk({ id: 'x1', title: 'Починить вход по ссылке', ws: 'shop-web', host: 'h1', t: now - 4 * MIN, state: 'run', diff: DIFF_LINK, items: [
      { k: 'user', text: 'Вход по ссылке из письма пускает даже с просроченной ссылкой. Найди причину и исправь, добавь тест.' },
      { k: 'agent', md: 'Ищу, где проверяется ссылка.' },
      { k: 'cmd', cmd: 'rg -n "verifyLink" src', out: ['src/auth/link.js:12:export function verifyLink(token) {', 'src/routes/login.js:44:  const user = verifyLink(req.query.t);'], exit: 0, sec: 0.2 },
      { k: 'agent', md: 'Причина: токен только **декодируется**, подпись и срок не проверяются по-настоящему. Заменил `jwt.decode` на `jwt.verify` и добавил тест.' },
      { k: 'files', files: DIFF_LINK },
      { k: 'approval', kind: 'cmd', cmd: 'npm test -- src/auth', cwd: '~/src/shop-web', why: 'Запустить тесты модуля входа', state: 'pending' }
    ]}),
    tsk({ id: 'x2', title: 'Добавить тёмную тему в настройки', ws: 'shop-web', host: 'h1', t: now - 18 * MIN, state: 'run', items: [
      { k: 'user', text: 'Добавь в настройки профиля переключатель тёмной темы.' },
      { k: 'agent', md: 'В проекте уже есть CSS-переменные для цветов, так что тема ляжет поверх них.' },
      { k: 'ask', q: 'Как включать тёмную тему?', opts: ['Как в системе', 'Только вручную', 'Как в системе + ручной выбор'], state: 'pending' }
    ]}),
    tsk({ id: 'x3', title: 'Обновить зависимости', ws: 'shop-api', host: 'h1', t: now - 1 * MIN, state: 'run', live: true, items: [
      { k: 'user', text: 'Обнови зависимости до последних патч-версий и прогони тесты.' },
      { k: 'agent', md: 'Обновляю патч-версии, мажорные не трогаю.' }
    ]}),
    tsk({ id: 'x4', title: 'Ускорить сборку CSS', ws: 'shop-web', host: 'h1', t: now - 2 * H, state: 'done', diff: DIFF_CSS, goal: { text: 'Сборка CSS быстрее 2 с', used: 0.35 }, items: [
      { k: 'user', text: 'Сборка CSS идёт 9 секунд. Ускорь, не меняя результат.' },
      { k: 'plan', state: 'done', steps: [{ t: 'Замерить, какие шаги медленные', done: true }, { t: 'Пересобирать только изменённые файлы', done: true }, { t: 'Сравнить результат со старой сборкой', done: true }] },
      { k: 'hook', name: 'pre-run · проверка рабочей копии', ok: true, sec: 0.4 },
      { k: 'sub', agents: [{ name: 'Замеры сборки', state: 'done', note: '9,1 с → 1,6 с' }, { name: 'Сравнение CSS', state: 'done', note: 'идентичен' }] },
      { k: 'cmd', cmd: 'npm run css', out: ['> node build/css.js', 'compiled 3 of 148 files', 'done in 1.6s'], exit: 0, sec: 1.6 },
      { k: 'mcp', server: 'github', tool: 'create_issue', args: 'title: «Сбрасывать кэш CSS при смене browserslist»', result: 'Создана задача #212', state: 'done' },
      { k: 'files', files: DIFF_CSS },
      { k: 'rich', title: 'Время сборки, с', bars: [['до', 9.1], ['после', 1.6]] },
      { k: 'review', n: 1 },
      { k: 'agent', md: 'Готово: сборка **9,1 с → 1,6 с**, CSS побайтно совпадает. Кэш лежит в `.cache/css.json`, сбросить — `npm run css:clean`.' }
    ]}),
    tsk({ id: 'x5', title: 'Тесты для парсера дат', ws: 'shop-api', host: 'h1', t: now - 26 * H, state: 'err', items: [
      { k: 'user', text: 'Напиши тесты для parse_date и почини, если найдёшь ошибки.' },
      { k: 'cmd', cmd: 'pytest tests/test_dates.py', out: ['collected 12 items', 'tests/test_dates.py ........F...', 'FAILED test_dst_switch - AssertionError', '1 failed, 11 passed in 0.84s'], exit: 1, sec: 0.8 },
      { k: 'hook', name: 'post-run · линтер', ok: false, sec: 1.2, note: 'остановил задачу: 2 ошибки flake8' },
      { k: 'agent', md: 'Один тест падает на переходе на летнее время. Нужна ваша помощь: в какой зоне считать даты без смещения?' }
    ]}),
    tsk({ id: 'x6', title: 'Переименовать модуль auth', ws: 'shop-web', host: 'h1', t: now - 5 * 24 * H, state: 'done', archived: true, items: [
      { k: 'user', text: 'Переименуй модуль auth в session.' },
      { k: 'agent', md: 'Переименовал модуль и 14 импортов.' }
    ]})
  ];
  C.task = function (id) { for (var i = 0; i < C.tasks.length; i++) if (C.tasks[i].id === id) return C.tasks[i]; return null; };
  C.pending = function (t) { for (var i = 0; i < t.items.length; i++) { var it = t.items[i]; if ((it.k === 'approval' || it.k === 'ask' || (it.k === 'plan' && C.on('codex.plan'))) && it.state === 'pending') return it; } return null; };
  C.waiting = function () { return C.tasks.filter(function (t) { return !t.archived && t.state === 'run' && C.pending(t); }).length; };
  C.sum = function (files) { var a = 0, d = 0; (files || []).forEach(function (f) { a += f.a; d += f.d; }); return [a, d]; };
  C.wsOf = function (name) { for (var i = 0; i < C.workspaces.length; i++) if (C.workspaces[i].name === name) return C.workspaces[i]; return C.workspaces[0]; };
  C.hostName = function (id) { var h = C.hosts.filter(function (x) { return x.id === id; })[0]; if (h) return h.name; var e = C.envs.filter(function (x) { return x.id === id; })[0]; return e ? 'Облако · ' + e.name : 'Компьютер'; };
  var subs = [];
  C.changed = function (t) { subs.slice().forEach(function (f) { f(t); }); S.renderDrawer(); };
  C.listen = function (el, fn) { subs.push(function (t) { if (K.inDoc(el)) fn(t); }); };

  /* ---------- Simulation: a task advances by itself until it needs the user ---------- */
  function later(ms, fn) { setTimeout(fn, ms); }
  C.liveCmd = function (t, cmd, lines, exit, then) {
    var it = { k: 'cmd', cmd: cmd, out: [], state: 'run', started: Date.now() };
    t.items.push(it); C.changed(t);
    var i = 0;
    (function step() {
      if (it.stopped) return;
      if (i < lines.length) { it.out.push(lines[i++]); C.changed(t); later(700, step); return; }
      it.state = 'done'; it.exit = exit; it.sec = Math.round((Date.now() - it.started) / 100) / 10; C.changed(t);
      if (then) later(700, then);
    })();
    return it;
  };
  function runDeps(t) {
    C.liveCmd(t, 'npm outdated --long', ['Package   Current  Wanted', 'fastify   4.26.1   4.26.2', 'pg        8.11.3   8.11.5', 'zod       3.22.4   3.22.6'], 0, function () {
      t.items.push({ k: 'approval', kind: 'net', domain: 'registry.npmjs.org', cmd: 'npm update fastify pg zod', why: 'Скачать обновлённые пакеты', state: 'pending' });
      t.state = 'run'; C.changed(t);
    });
  }
  C.afterApproval = function (t, it) {
    if (t.id === 'x1') {
      C.liveCmd(t, it.cmd, ['PASS src/auth/link.test.js', '  ✓ просроченная ссылка не пускает (4 ms)', 'Tests: 6 passed, 6 total'], 0, function () {
        t.items.push({ k: 'agent', md: 'Тесты проходят. Изменения готовы к проверке: 2 файла.' });
        finish(t);
      });
    } else if (t.id === 'x3') {
      C.liveCmd(t, it.cmd, ['changed 3 packages in 4s'], 0, function () {
        C.liveCmd(t, 'npm test', ['Tests: 58 passed, 58 total'], 0, function () {
          t.diff = [file('package-lock.json', 'M', [{ h: '"node_modules/zod"', o: 812, n: 812, lines: ['   "node_modules/zod": {', '-    "version": "3.22.4",', '+    "version": "3.22.6",', '   },'] }])];
          t.items.push({ k: 'files', files: t.diff });
          t.items.push({ k: 'agent', md: 'Обновил 3 пакета, все 58 тестов проходят.' });
          finish(t);
        });
      });
    } else { t.items.push({ k: 'agent', md: 'Продолжаю.' }); C.changed(t); }
  };
  C.afterDeny = function (t, it) {
    t.items.push({ k: 'agent', md: 'Хорошо, не выполняю `' + it.cmd + '`. Скажите, как поступить иначе.' }); C.changed(t);
  };
  C.afterAnswer = function (t, it, ans) {
    t.items.push({ k: 'agent', md: 'Делаю так: **' + ans + '**.' }); C.changed(t);
    later(900, function () {
      C.liveCmd(t, 'npm run lint', ['✔ 0 problems'], 0, function () {
        t.diff = [file('src/settings/theme.js', 'A', [{ h: 'новый файл', o: 0, n: 1, lines: ['+export function applyTheme(mode) {', '+  document.body.dataset.theme = mode;', '+}'] }])];
        t.items.push({ k: 'files', files: t.diff });
        t.items.push({ k: 'agent', md: 'Переключатель добавлен в «Профиль › Оформление».' });
        finish(t);
      });
    });
  };
  function finish(t) { t.state = 'done'; t.t = Date.now(); C.changed(t); }
  C.reply = function (t, text) {
    t.items.push({ k: 'user', text: text });
    if (t.state !== 'run') { t.state = 'run'; }
    C.changed(t);
    later(1200, function () { t.items.push({ k: 'agent', md: t.state === 'run' && C.pending(t) ? 'Учту это, когда вы ответите на запрос выше.' : 'Принял, учитываю: «' + text + '».' }); if (!C.pending(t) && t.state === 'run') finish(t); else C.changed(t); });
  };
  C.newTask = function (o) {
    var t = tsk({ id: 'x' + (+new Date()), title: o.title, ws: o.ws, host: C.where, state: 'run', t: Date.now(), items: [{ k: 'user', text: o.text, att: o.att }] });
    if (o.goal) t.goal = { text: o.goal, used: 0 };
    C.tasks.unshift(t);
    later(900, function () {
      if (o.plan) {
        t.items.push({ k: 'plan', state: 'pending', steps: [{ t: 'Найти место в коде, где это делается' }, { t: 'Внести изменение и обновить тесты' }, { t: 'Запустить тесты и показать diff' }] });
        C.changed(t); return;
      }
      startWork(t);
    });
    return t;
  };
  function startWork(t) {
    t.items.push({ k: 'agent', md: 'Смотрю структуру проекта **' + K.esc(t.ws) + '**.' }); C.changed(t);
    later(800, function () {
      C.liveCmd(t, 'git status --short && ls src', ['src/: auth  routes  settings  ui'], 0, function () {
        t.items.push({ k: 'approval', kind: 'cmd', cmd: 'npm test', cwd: C.wsOf(t.ws).path, why: 'Проверить, что всё работает до изменений', state: 'pending' });
        C.changed(t);
      });
    });
  }
  C.acceptPlan = function (t, it) {
    it.state = 'go'; C.changed(t);
    later(600, function () { it.steps[0].done = true; C.changed(t); startWork(t); });
  };

  /* ---------- Shared bits ---------- */
  function lampFor(t) {
    if (t.state === 'err') return 'err';
    if (t.state === 'done') return 'ok';
    return C.pending(t) ? 'info' : 'busy';
  }
  function statusText(t) {
    if (t.state === 'err') return 'Остановлена с ошибкой';
    if (t.state === 'done') { var s = C.sum(t.diff); return 'Готово' + (t.diff ? ' · +' + s[0] + ' −' + s[1] : ''); }
    var p = C.pending(t);
    if (p) return p.k === 'ask' ? 'Ждёт вашего ответа' : (p.k === 'plan' ? 'Ждёт согласия с планом' : 'Ждёт разрешения');
    return 'Выполняется · ' + K.ago(t.t).replace(/ назад$/, '');
  }
  function ph(title, glyph, color) {
    return K.h('div', 'part ph', K.tile(glyph, color, 29) + '<b>' + title + '</b>Этот элемент задачи пока не показывается на iPhone — он сохранён в задаче.');
  }
  function plusMinus(a, d) { return '<span class="cx-pm"><i class="a">+' + a + '</i> <i class="d">−' + d + '</i></span>'; }
  function badge(k) { return '<span class="cx-k ' + k + '">' + k + '</span>'; }
  function splitPath(p) { var i = p.lastIndexOf('/'); return i < 0 ? ['', p] : [p.slice(0, i + 1), p.slice(i + 1)]; }

  /* ---------- Root: Codex ---------- */
  S.codexScreen = function () {
    var s = K.screen('Codex');
    var filter = 0;
    s.right = { icon: K.barGlyph('compose'), action: function () { if (C.verified) newTask(s); } };
    function draw() {
      var keep = s.scroll.scrollTop;
      s.body.innerHTML = '';
      if (!C.verified) return setup();
      if (C.on('codex.connections')) {
        var gh = K.group(s.body, null);
        var cur = C.hosts.filter(function (h) { return h.id === C.where; })[0];
        var env = C.envs.filter(function (e) { return e.id === C.where; })[0];
        K.cell(gh, { icon: K.tile(env ? 'cloud' : 'devices', env ? 'blue' : 'dark'), titleHTML: K.esc(cur ? cur.name : 'Облако · ' + env.name), sub: '<span class="lamp ' + (env || cur.online ? 'ok' : '') + '"></span>' + (env ? env.repo : (cur.online ? 'Подключён · ' + cur.via : 'Не в сети')), action: function () { s.nav.push(connections()); } }).classList.add('cx-host');
      }
      var segs = ['Активные', 'Готовые']; if (C.on('codex.archive')) segs.push('Архив');
      if (filter >= segs.length) filter = 0;
      var w = K.h('div', 'seg-wrap'); w.appendChild(K.seg(segs, filter, function (i) { filter = i; draw(); }, true)); s.body.appendChild(w);
      var list = C.tasks.filter(function (t) {
        if (t.archived) return filter === 2;
        if (filter === 2) return false;
        return filter === 0 ? t.state === 'run' : t.state !== 'run';
      });
      function sect(title, arr) {
        if (!arr.length) return;
        var g = K.group(s.body, title);
        arr.forEach(function (t) { taskRow(g, t); });
      }
      if (filter === 0) {
        sect('Ждут вас', list.filter(function (t) { return C.pending(t); }));
        sect('Выполняются', list.filter(function (t) { return !C.pending(t); }));
      } else sect(filter === 1 ? 'Готово' : 'Архив', list);
      if (!list.length) s.body.appendChild(K.h('div', 'empty', filter === 0 ? '<b>Нет активных задач</b>Нажмите ✎, чтобы поручить Codex работу в проекте.' : (filter === 1 ? '<b>Пока ничего не завершено</b>' : '<b>Архив пуст</b>Смахните задачу влево, чтобы убрать её сюда.')));
      if (C.on('codex.approval-policy')) {
        var gs = K.group(s.body, null);
        K.cell(gs, { icon: K.tile('gear', 'gray'), title: 'Настройки Codex', action: function () { s.nav.push(settings()); } });
      }
      s.body.appendChild(K.h('div', 'note', 'Codex работает ' + (C.on('codex.cloud') ? 'на вашем компьютере или в облаке' : 'там, где его запустил ваш аккаунт') + '. iPhone показывает ход работы и останавливает задачу только там, где нужно ваше решение.'));
      s.scroll.scrollTop = keep;
    }
    function taskRow(g, t) {
      var s2 = C.sum(t.diff), p = C.pending(t);
      var c = K.cell(g, { titleHTML: '<span class="lamp ' + lampFor(t) + '"></span>' + K.esc(t.title), sub: K.esc(t.ws) + ' · ' + (p ? '<b class="cx-need">' + statusText(t) + '</b>' : (t.state === 'run' ? 'выполняется' : K.ago(t.t))), value: t.diff ? plusMinus(s2[0], s2[1]) : null, action: function () { s.nav.push(S.codexTask(t.id)); } });
      c.classList.add('cx-row');
      if (C.on('codex.archive') && !t.archived) K.swipeDelete(c, 'В архив', function () { t.archived = true; K.hud('В архиве'); draw(); S.renderDrawer(); });
      if (C.on('codex.rename')) K.hold(c, function () { taskMenu(t, s, draw); });
    }
    function setup() {
      var b = s.body;
      var box = K.h('div', 'cx-setup', K.tile('shield', 'dark', 57) + '<h2>Проверка iPhone для Codex</h2><p>Codex запускает команды и меняет файлы в ваших проектах. Один раз подтвердим, что этот iPhone принадлежит вашему аккаунту. Ключ устройства хранится в связке ключей iPhone и никуда не передаётся.</p>');
      b.appendChild(box);
      var g = K.group(b, null);
      var steps = ['Создаю ключ устройства', 'Подписываю запрос аккаунта', 'Аккаунт подтвердил iPhone'];
      var cells = steps.map(function (x) { var c = K.cell(g, { titleHTML: '<span class="lamp"></span>' + x }); c.classList.add('noarrow'); return c; });
      var r = K.h('div', 'btn-row', '<div class="button green">Проверить iPhone</div>'); b.appendChild(r);
      var busy = false;
      K.tap(r.firstChild, function () {
        if (busy) return; busy = true; K.disable(r.firstChild, true);
        var i = 0;
        (function next() {
          if (i > 0) cells[i - 1].querySelector('.lamp').className = 'lamp ok';
          if (i === steps.length) { C.verified = true; try { localStorage.setItem('rc-cx-verified', '1'); } catch (e) {} setTimeout(function () { K.hud('iPhone подтверждён'); draw(); }, 400); return; }
          cells[i].querySelector('.lamp').className = 'lamp busy';
          i++; setTimeout(next, 900);
        })();
      });
      b.appendChild(K.h('div', 'note', 'Если проверка не пройдёт, раздел Codex останется закрытым, а обычные чаты продолжат работать.'));
    }
    C.listen(s.el, function () { if (!s.nav || s.nav.top() === s) draw(); });
    draw();
    s.onReturn = draw;
    return s;
  };

  function taskMenu(t, scr, redraw) {
    var b = [];
    if (C.on('codex.rename')) b.push({ title: 'Переименовать', action: function () { K.alert({ title: 'Название задачи', field: { value: t.title }, buttons: [{ title: 'Отмена', cancel: true }, { title: 'Сохранить', action: function (v) { if (v) { t.title = v; C.changed(t); if (redraw) redraw(); } } }] }); } });
    if (C.on('codex.fork')) b.push({ title: 'Ответвить', action: function () {
      var f = tsk({ id: 'x' + (+new Date()), title: t.title + ' (ветка)', ws: t.ws, host: t.host, state: 'done', t: Date.now(), diff: t.diff, items: t.items.filter(function (it) { return it.k === 'user' || it.k === 'agent' || it.k === 'files'; }).concat([{ k: 'agent', md: 'Это ответвление. Исходная задача не изменится — опишите другой подход.' }]) });
      C.tasks.unshift(f); C.changed(f); K.hud('Ответвлено'); scr.nav.push(S.codexTask(f.id));
    } });
    if (C.on('codex.files')) b.push({ title: 'Файлы проекта', action: function () { scr.nav.push(files(C.wsOf(t.ws), '')); } });
    if (C.on('codex.archive')) b.push({ title: t.archived ? 'Вернуть из архива' : 'В архив', action: function () { t.archived = !t.archived; K.hud(t.archived ? 'В архиве' : 'Возвращено'); C.changed(t); if (redraw) redraw(); } });
    K.sheet({ title: t.title, buttons: b });
  }

  /* ---------- Task transcript ---------- */
  S.codexTask = function (id) {
    var t = C.task(id);
    var s = { title: t.title, backTitle: 'Задача' };
    var el = s.el = K.h('div', 'chat linen cx-task');
    el.style.position = 'absolute';
    var banner = K.h('div', 'banner hidden');
    var scroll = K.h('div', 'scroll'), inner = K.h('div', 'inner');
    scroll.appendChild(inner); el.appendChild(scroll); el.appendChild(banner);
    var comp = composer();
    el.appendChild(comp.el);
    var tv = K.h('div', 'tv-inner cx-tv');
    s.titleView = tv;
    if (C.on('codex.rename')) s.right = { icon: K.barGlyph('more'), action: function () { taskMenu(t, s, function () { title(); draw(); }); } };
    function title() { tv.innerHTML = '<span class="tt">' + K.esc(t.title) + '</span><span class="st"><span class="lamp ' + lampFor(t) + '"></span>' + statusText(t) + '</span>'; }
    var drop = null;
    function draw() {
      var atEnd = scroll.scrollTop + scroll.clientHeight >= scroll.scrollHeight - 30;
      inner.innerHTML = '';
      if (t.goal && C.on('codex.goals')) {
        var gl = K.h('div', 'cx-goal', '<div class="gt"><b>Цель:</b> ' + K.esc(t.goal.text) + '<span>бюджет ' + Math.round(t.goal.used * 100) + ' %</span></div>');
        var pr = K.progress(); pr.set(t.goal.used); gl.appendChild(pr); inner.appendChild(gl);
      }
      if (t.diff) {
        var sm = C.sum(t.diff);
        var strip = K.h('div', 'cx-strip', K.glyph('branch', 16, '#3c6f57') + '<b>Изменения</b> · ' + t.diff.length + ' ' + plural(t.diff.length, 'файл', 'файла', 'файлов') + plusMinus(sm[0], sm[1]) + K.chev());
        K.tap(strip, function () { s.nav.push(S.codexDiff(t)); });
        inner.appendChild(strip);
      }
      t.items.forEach(function (it) { var n = item(it); if (n) inner.appendChild(n); });
      if (t.state === 'run' && !C.pending(t) && !runningCmd()) inner.appendChild(K.h('div', 'cx-working', '<span class="spinner small">' + K.spinnerSVG('#5f6f67') + '</span>Codex работает…'));
      if (t.state !== 'run' && C.on('codex.feedback')) inner.appendChild(feedback());
      title(); comp.refresh();
      if (atEnd) scroll.scrollTop = scroll.scrollHeight;
    }
    function stopCmd(it) { it.stopped = true; it.state = 'done'; it.exit = 130; it.sec = Math.round((Date.now() - it.started) / 100) / 10; t.items.push({ k: 'agent', md: 'Команда остановлена по вашему запросу. Что сделать дальше?' }); t.state = 'done'; C.changed(t); }
    function runningCmd() { for (var i = 0; i < t.items.length; i++) if (t.items[i].k === 'cmd' && t.items[i].state === 'run') return t.items[i]; return null; }
    function wrap(cls, html) { var w = K.h('div', 'msg asst cx-item ' + (cls || '')); if (html != null) w.innerHTML = html; return w; }
    function item(it) {
      if (it.k === 'user') {
        var u = K.h('div', 'msg user');
        u.innerHTML = (it.att ? '<div class="cx-att">' + K.glyph('photo', 14, '#fff') + ' ' + K.esc(it.att) + '</div>' : '') + '<div class="bubble">' + K.esc(it.text) + '</div>';
        return u;
      }
      if (it.k === 'agent') { var a = wrap('', '<div class="card"><div class="who">' + K.glyph('terminal', 16, '#3c6f57', ' style="float:left;margin-right:6px"') + 'Codex</div><div class="md">' + S.md(it.md) + '</div></div>'); return a; }
      if (it.k === 'gap') return K.h('div', 'cx-gap', '<span class="lamp ok"></span>Связь восстановлена · загружено ' + it.n + ' ' + plural(it.n, 'событие', 'события', 'событий'));
      if (it.k === 'cmd') return cmdCard(it);
      if (it.k === 'files') return filesCard(it);
      if (it.k === 'approval') return approvalCard(it);
      if (it.k === 'ask') return askCard(it);
      if (it.k === 'plan') return C.on('codex.plan') ? planCard(it) : wrap('', '').appendChild(ph('План работы', 'sliders', 'green')).parentNode;
      if (it.k === 'mcp') return C.on('codex.mcp') ? mcpCard(it) : wrap('', '').appendChild(ph('Вызов инструмента', 'apps', 'purple')).parentNode;
      if (it.k === 'review') return C.on('codex.review') ? reviewCard(it) : wrap('', '').appendChild(ph('Ревью изменений', 'edit', 'orange')).parentNode;
      if (it.k === 'sub') return C.on('codex.subagents') ? subCard(it) : wrap('', '').appendChild(ph('Подагенты', 'person', 'teal')).parentNode;
      if (it.k === 'rich') return C.on('codex.rich-output') ? richCard(it) : wrap('', '').appendChild(ph('График', 'chart', 'teal')).parentNode;
      if (it.k === 'hook') return C.on('codex.hooks') ? K.h('div', 'cx-hook' + (it.ok ? '' : ' bad'), '<span class="lamp ' + (it.ok ? 'ok' : 'err') + '"></span>hook ' + K.esc(it.name) + ' · ' + (it.ok ? 'прошёл' : K.esc(it.note || 'остановил')) + ' · ' + String(it.sec).replace('.', ',') + ' с') : null;
      return null;
    }
    function cmdCard(it) {
      var run = it.state === 'run';
      var head = run ? '<span class="lamp busy"></span>выполняется<span class="cc stop">Стоп</span>' : '<span class="lamp ' + (it.exit === 0 ? 'ok' : 'err') + '"></span>код ' + it.exit + ' · ' + String(it.sec).replace('.', ',') + ' с' + (it.stopped ? ' · остановлено' : '');
      var tail = it.out.slice(-4);
      var w = wrap('', '<div class="code cx-term"><div class="ch">Терминал<span class="cst">' + head + '</span></div><pre><span class="pr">$ </span>' + K.esc(it.cmd) + (tail.length ? '\n' + K.esc(tail.join('\n')) : '') + (it.out.length > 4 ? '\n<span class="more">… ещё ' + (it.out.length - 4) + ' стр.</span>' : '') + '</pre></div>');
      var stop = w.querySelector('.stop');
      if (stop) K.tap(stop, function () { stopCmd(it); }, { instant: true });
      K.tap(w.querySelector('pre'), function () { s.nav.push(output(it)); });
      return w;
    }
    function filesCard(it) {
      var sm = C.sum(it.files);
      var w = wrap('', '<div class="cx-files"><div class="fh">Изменено ' + it.files.length + ' ' + plural(it.files.length, 'файл', 'файла', 'файлов') + plusMinus(sm[0], sm[1]) + '</div></div>');
      var box = w.firstChild;
      it.files.forEach(function (f) {
        var sp = splitPath(f.p);
        var r = K.h('div', 'fr', badge(f.k) + '<span class="fp"><small>' + K.esc(sp[0]) + '</small>' + K.esc(sp[1]) + '</span>' + plusMinus(f.a, f.d));
        K.tap(r, function () { s.nav.push(S.codexFile(t, f)); });
        box.appendChild(r);
      });
      return w;
    }
    function approvalCard(it) {
      var net = it.kind === 'net', mcp = it.kind === 'mcp';
      var head = net ? 'Codex просит доступ в сеть' : (mcp ? 'Codex хочет вызвать инструмент' : 'Codex ждёт разрешения');
      var body = '<div class="ah"><span class="lamp ' + (it.state === 'pending' ? 'info' : (it.state === 'denied' ? 'err' : 'ok')) + '"></span>' + head + '</div>';
      if (net) body += '<div class="aw">' + (C.on('codex.network-approval') ? K.tile('globe', 'blue', 29) : '') + '<b>' + K.esc(it.domain) + '</b><small>' + K.esc(it.why) + '</small></div>';
      else body += '<div class="aw"><small>' + K.esc(it.why) + (it.cwd ? ' · в ' + K.esc(it.cwd) : '') + '</small></div>';
      body += '<pre>$ ' + K.esc(it.cmd) + '</pre>';
      if (it.state === 'pending') body += '<div class="ab"><div class="button small">Отклонить</div><div class="button small green">' + (net && C.on('codex.network-approval') ? 'Разрешить…' : 'Разрешить') + '</div></div>';
      else body += '<div class="ar">' + (it.state === 'denied' ? 'Отклонено' : (it.always ? 'Разрешено всегда для ' + K.esc(it.domain) : 'Разрешено')) + '</div>';
      var w = wrap('', '<div class="cx-approve' + (it.state === 'pending' ? ' pending' : '') + '">' + body + '</div>');
      if (it.state === 'pending') {
        var bs = w.querySelectorAll('.ab .button');
        K.tap(bs[0], function () { it.state = 'denied'; C.changed(t); C.afterDeny(t, it); });
        K.tap(bs[1], function () {
          function ok(always) { it.state = 'ok'; it.always = always; C.changed(t); C.afterApproval(t, it); }
          if (net && C.on('codex.network-approval')) K.sheet({ title: 'Доступ к ' + it.domain + ' для этой задачи', buttons: [{ title: 'Только сейчас', action: function () { ok(false); } }, { title: 'Всегда для ' + it.domain, action: function () { ok(true); } }] });
          else ok(false);
        });
      }
      return w;
    }
    function askCard(it) {
      var sel = it.sel != null ? it.sel : -1;
      var w = wrap('', '');
      var html = '<div class="clarify' + (it.state !== 'pending' ? ' answered' : '') + '"><div class="cq">' + K.esc(it.q) + '<small>Codex спрашивает</small></div>';
      it.opts.forEach(function (o, i) { html += '<div class="opt' + (i === sel ? ' checked' : '') + '">' + K.esc(o) + '<span class="check"></span></div>'; });
      if (it.state === 'pending') html += '<div class="own"><input type="text" placeholder="Свой ответ"></div><div class="cf"><div class="button small green" style="display:inline-block;padding:0 18px">Ответить</div></div>';
      else html += '<div class="cf" style="text-align:left;font-size:13px;color:#5f6f67">Ваш ответ: <b>' + K.esc(it.answer) + '</b></div>';
      w.innerHTML = html + '</div>';
      if (it.state !== 'pending') return w;
      var opts = w.querySelectorAll('.opt'), inp = w.querySelector('input'), go = w.querySelector('.cf .button');
      function upd() { K.disable(go, sel < 0 && !inp.value.trim()); }
      Array.prototype.forEach.call(opts, function (o, i) { K.tap(o, function () { sel = i; it.sel = i; inp.value = ''; Array.prototype.forEach.call(opts, function (x, k) { K.cls(x, 'checked', k === i); }); upd(); }, { instant: true }); });
      inp.addEventListener('input', function () { if (inp.value) { sel = -1; it.sel = null; Array.prototype.forEach.call(opts, function (x) { x.classList.remove('checked'); }); } upd(); }, false);
      K.tap(go, function () { if (go._disabled) return; it.answer = inp.value.trim() || it.opts[sel]; it.state = 'done'; C.changed(t); C.afterAnswer(t, it, it.answer); });
      upd();
      return w;
    }
    function planCard(it) {
      var html = '<div class="cx-plan"><div class="ph2">' + K.glyph('sliders', 16, '#3c6f57') + ' План' + (it.state === 'pending' ? '<span>ждёт согласия</span>' : '') + '</div>';
      it.steps.forEach(function (st, i) { html += '<div class="ps' + (st.done ? ' done' : '') + '"><span class="n">' + (st.done ? '✓' : i + 1) + '</span>' + K.esc(st.t) + '</div>'; });
      if (it.state === 'pending') html += '<div class="ab"><div class="button small">Изменить</div><div class="button small green">Выполнить план</div></div>';
      var w = wrap('', html + '</div>');
      if (it.state === 'pending') {
        var bs = w.querySelectorAll('.ab .button');
        K.tap(bs[0], function () { comp.focus('План: '); });
        K.tap(bs[1], function () { C.acceptPlan(t, it); });
      }
      return w;
    }
    function mcpCard(it) {
      return wrap('', '<div class="cx-mcp">' + K.tile('apps', 'purple', 29) + '<div class="mt"><b>' + K.esc(it.server) + '</b> · ' + K.esc(it.tool) + '</div><div class="ma">' + K.esc(it.args) + '</div><div class="mr"><span class="lamp ok"></span>' + K.esc(it.result) + '</div></div>');
    }
    function reviewCard(it) {
      var w = wrap('', '<div class="cx-strip review">' + K.glyph('edit', 16, '#8a6a00') + '<b>Ревью</b> · ' + it.n + ' ' + plural(it.n, 'замечание', 'замечания', 'замечаний') + K.chev() + '</div>');
      K.tap(w.firstChild, function () { s.nav.push(S.codexDiff(t)); });
      return w;
    }
    function subCard(it) {
      var html = '<div class="cx-files"><div class="fh">Подагенты · ' + it.agents.length + '</div>';
      it.agents.forEach(function (a) { html += '<div class="fr"><span class="lamp ' + (a.state === 'done' ? 'ok' : 'busy') + '"></span><span class="fp">' + K.esc(a.name) + '</span><span class="cx-pm"><i>' + K.esc(a.note) + '</i></span></div>'; });
      return wrap('', html + '</div>');
    }
    function richCard(it) {
      var max = 0; it.bars.forEach(function (b) { max = Math.max(max, b[1]); });
      var html = '<div class="cx-rich"><div class="rt">' + K.esc(it.title) + '</div>';
      it.bars.forEach(function (b) { html += '<div class="rb"><span>' + K.esc(b[0]) + '</span><i style="width:' + Math.round(b[1] / max * 190) + 'px"></i><b>' + String(b[1]).replace('.', ',') + '</b></div>'; });
      return wrap('', html + '</div>');
    }
    function feedback() {
      var f = K.h('div', 'cx-fb', 'Как результат?<span class="up">' + K.glyph('thumb', 18, '#5f6f67') + '</span><span class="down">' + K.glyph('thumb', 18, '#5f6f67', ' style="-webkit-transform:scaleY(-1)"') + '</span>');
      K.tap(f.querySelector('.up'), function () { K.hud('Спасибо'); }, { instant: true });
      K.tap(f.querySelector('.down'), function () { reportProblem(); }, { instant: true });
      return f;
    }
    function composer() {
      var c = { el: K.h('div', 'composer') };
      var row = K.h('div', 'row');
      var plus = K.h('div', 'plus', K.glyph('plus', 18, '#4b5d55'));
      var wrapF = K.h('div', 'fieldwrap');
      var ta = document.createElement('textarea'); ta.placeholder = 'Сообщение для Codex'; ta.rows = 1;
      var mic = K.h('div', 'mic', K.glyph('mic', 20, '#6b7a72'));
      var send = K.h('div', 'send', 'Отпр.');
      wrapF.appendChild(ta); wrapF.appendChild(mic); row.appendChild(plus); row.appendChild(wrapF); row.appendChild(send); c.el.appendChild(row);
      var hasPlus = C.on('codex.attachments'), hasMic = C.on('codex.voice');
      K.cls(c.el, 'has-plus', hasPlus); K.cls(plus, 'hidden', !hasPlus);
      K.cls(c.el, 'has-mic', hasMic); K.cls(mic, 'hidden', !hasMic);
      if (hasPlus || hasMic) ta.placeholder = 'Сообщение';
      function fit() { ta.style.height = '30px'; var h = Math.min(118, Math.max(30, ta.scrollHeight)); ta.style.height = h + 'px'; scroll.style.bottom = c.el.offsetHeight + 'px'; }
      ta.addEventListener('input', function () { fit(); c.refresh(); }, false);
      c.refresh = function () {
        var txt = !!ta.value.trim(), rc = runningCmd();
        send.className = 'send';
        if (!txt && rc) { send.classList.add('stop'); send.innerHTML = K.glyph('stop', 14, '#fff'); }
        else { send.textContent = 'Отпр.'; K.disable(send, !txt); }
      };
      c.focus = function (pre) { ta.value = pre || ''; fit(); c.refresh(); ta.focus(); };
      K.tap(send, function () {
        var rc = runningCmd();
        if (!ta.value.trim() && rc) { stopCmd(rc); return; }
        if (!ta.value.trim()) return;
        var v = ta.value.trim(); ta.value = ''; fit(); C.reply(t, v);
      }, { instant: true });
      K.tap(plus, function () {
        K.actGrid({ items: [
          { icon: K.tile('photo', 'orange', 57), title: 'Фото', action: function () { S.photoPicker(function () { attach('Снимок экрана.png'); }); } },
          { icon: K.tile('camera', 'graphite', 57), title: 'Камера', action: function () { S.cameraSim(function () { attach('Фото.jpg'); }); } }
        ] });
      }, { instant: true });
      K.tap(mic, function () {
        var h = K.hud('Говорите…', 'busy');
        setTimeout(function () { h.done('Распознано'); c.focus('Добавь ещё проверку пустого токена'); }, 1600);
      }, { instant: true });
      function attach(name) { t.items.push({ k: 'user', text: 'Посмотри на снимок — так выглядит ошибка.', att: name }); C.changed(t); }
      setTimeout(fit, 0);
      return c;
    }
    function updateBanner(state) {
      K.cls(banner, 'hidden', !state); K.cls(el, 'has-banner', !!state);
      if (state) { banner.className = 'banner warn'; banner.innerHTML = '<span class="lamp busy"></span>Связь с компьютером потеряна. Задача продолжает работу — переподключаюсь…'; }
    }
    function maybeDrop() {
      if (!M.scenario.codexDrop || t.state !== 'run' || drop) return;
      drop = setTimeout(function () {
        if (!K.inDoc(el)) return;
        updateBanner(true);
        setTimeout(function () { updateBanner(false); t.items.push({ k: 'gap', n: 3 }); t.items.push({ k: 'agent', md: 'Пока связи не было, я закончил анализ — продолжаю с того же места.' }); C.changed(t); }, 3500);
      }, 1500);
    }
    s.onShow = function () {
      title(); draw(); scroll.scrollTop = scroll.scrollHeight; maybeDrop();
      if (t.live && !t.started) { t.started = true; setTimeout(function () { runDeps(t); }, 600); }
    };
    s.onReturn = draw;
    C.listen(el, function (x) { if (x === t) draw(); });
    draw();
    return s;
  };

  function plural(n, a, b, c) { var m = n % 10, h = n % 100; if (m === 1 && h !== 11) return a; if (m >= 2 && m <= 4 && (h < 12 || h > 14)) return b; return c; }

  /* ---------- Command output ---------- */
  function output(it) {
    var s = K.screen('Вывод', { cls: 'cx-out' });
    function draw() { s.body.innerHTML = '<pre><span class="pr">$ </span>' + K.esc(it.cmd) + '\n' + K.esc(it.out.join('\n')) + '\n\n<span class="ex">' + (it.state === 'run' ? '● выполняется…' : 'код завершения ' + it.exit) + '</span></pre>'; }
    draw();
    s.right = { title: 'Копир.', action: function () { K.hud('Скопировано'); } };
    var iv = setInterval(function () { if (!K.inDoc(s.el)) { clearInterval(iv); return; } draw(); }, 700);
    return s;
  }

  /* ---------- Diff ---------- */
  S.codexDiff = function (t) {
    var s = K.screen('Изменения');
    function draw() {
      s.body.innerHTML = '';
      var sm = C.sum(t.diff);
      var g = K.group(s.body, t.diff.length + ' ' + plural(t.diff.length, 'файл', 'файла', 'файлов'), null, '+' + sm[0] + ' −' + sm[1]);
      t.diff.forEach(function (f) {
        var sp = splitPath(f.p);
        var c = K.cell(g, { titleHTML: badge(f.k) + K.esc(sp[1]) + (f.review && f.reviewed && C.on('codex.review') ? ' <span class="cx-rv">' + f.review.length + '</span>' : ''), sub: K.esc(sp[0] || '/'), value: plusMinus(f.a, f.d), action: function () { s.nav.push(S.codexFile(t, f)); } });
        c.classList.add('cx-row');
      });
      var ws = C.wsOf(t.ws);
      s.body.appendChild(K.h('div', 'note', 'Изменения лежат в ' + K.esc(ws.path) + (C.on('codex.worktree') ? ' · ветка codex/' + t.id : '') + '. Отправка в репозиторий — на компьютере.'));
    }
    if (C.on('codex.review')) s.right = { title: 'Ревью', action: function () {
      var h = K.hud('Codex проверяет…', 'busy');
      setTimeout(function () { var n = 0; t.diff.forEach(function (f) { if (f.review) { f.reviewed = true; n += f.review.length; } }); h.done(n ? 'Замечаний: ' + n : 'Замечаний нет'); draw(); }, 1600);
    } };
    t.diff.forEach(function (f) { if (t.items.some(function (i) { return i.k === 'review'; })) f.reviewed = true; });
    draw();
    s.onReturn = draw;
    return s;
  };
  S.codexFile = function (t, f) {
    var sp = splitPath(f.p);
    var s = K.screen(sp[1], { cls: 'paper cx-diff' });
    var idx = t.diff ? t.diff.indexOf(f) : -1;
    if (t.diff && idx >= 0 && idx < t.diff.length - 1) s.right = { title: 'Далее', action: function () { s.nav.replace(S.codexFile(t, t.diff[idx + 1])); } };
    var html = '<div class="dfh">' + badge(f.k) + '<span>' + K.esc(f.p) + '</span>' + plusMinus(f.a, f.d) + '</div>';
    f.hunks.forEach(function (h) {
      var o = h.o, n = h.n;
      html += '<div class="hk">@@ ' + K.esc(h.h) + '</div>';
      h.lines.forEach(function (l, i) {
        var k = l.charAt(0), txt = l.slice(1), cls = k === '+' ? 'add' : (k === '-' ? 'del' : 'ctx');
        var on = k === '+' ? '' : o++, nn = k === '-' ? '' : n++;
        html += '<div class="dl ' + cls + '"><span class="no">' + on + '</span><span class="no">' + nn + '</span><span class="sg">' + (k === ' ' ? '' : (k === '-' ? '−' : '+')) + '</span><code>' + (K.esc(txt) || ' ') + '</code></div>';
        if (f.review && f.reviewed && C.on('codex.review') && h === f.hunks[0]) f.review.forEach(function (r) { if (r.after === i) html += '<div class="cx-note"><b>Codex · ревью</b>' + K.esc(r.text) + '<div class="button small">Исправить</div></div>'; });
      });
    });
    s.body.innerHTML = html;
    Array.prototype.forEach.call(s.body.querySelectorAll('.cx-note .button'), function (b) { K.tap(b, function () { K.hud('Отправлено в задачу'); C.reply(t, 'Исправь замечание ревью в ' + f.p + '.'); }); });
    return s;
  };

  /* ---------- New task ---------- */
  function newTask(root) {
    var o = { ws: C.workspaces[0].name, plan: C.prefs.plan, att: null, goal: null, branch: 0 };
    var e = K.screen('Новая задача');
    var nav = new K.Nav();
    function draw() {
      var keepTa = e.body.querySelector('textarea'); var txt = keepTa ? keepTa.value : '';
      e.body.innerHTML = '';
      var g = K.group(e.body, null);
      var ws = C.wsOf(o.ws);
      K.cell(g, { icon: K.tile('folder', 'blue'), title: 'Проект', value: K.esc(ws.name), action: function () { nav.push(workspaces(o, draw)); } });
      if (C.on('codex.cloud')) K.cell(g, { icon: K.tile(C.where.charAt(0) === 'e' ? 'cloud' : 'devices', 'dark'), title: 'Где', value: K.esc(C.hostName(C.where)), action: function () { nav.push(connections(true, draw)); } });
      if (C.on('codex.model')) K.cell(g, { icon: K.tile('brain', 'purple'), title: 'Модель', value: K.esc(C.models[C.prefs.model].name.replace('GPT-', '')) + ' · ' + ['низк.', 'средн.', 'выс.'][C.prefs.effort], action: function () { nav.push(modelScreen(draw)); } });
      if (C.on('codex.worktree')) K.cell(g, { icon: K.tile('branch', 'teal'), title: 'Ветка', value: o.branch ? K.esc(ws.branch) : 'новая', action: function (c) { K.sheet({ title: 'Где вносить изменения', buttons: [{ title: 'Новая ветка в отдельном worktree', check: !o.branch, action: function () { o.branch = 0; draw(); } }, { title: 'Текущая ветка ' + ws.branch, check: !!o.branch, action: function () { o.branch = 1; draw(); } }] }); } });
      var gp = K.group(e.body, 'Что сделать');
      var cp = K.cell(gp, { title: '', cls: 'area' }); cp.innerHTML = '';
      var ta = document.createElement('textarea'); ta.placeholder = 'Опишите задачу: что изменить, как проверить результат'; ta.value = txt; cp.appendChild(ta);
      if (C.on('codex.attachments')) K.cell(gp, { icon: K.tile('photo', 'orange'), title: o.att ? o.att : 'Добавить снимок экрана', action: function () { S.photoPicker(function () { o.att = 'Снимок экрана.png'; draw(); }); } });
      if (C.on('codex.plan')) {
        var gpl = K.group(e.body, null, 'Codex сначала предложит план и подождёт вашего согласия.');
        var pc = K.cell(gpl, { title: 'Сначала план', cls: 'has-switch' }); pc.querySelector('.t').classList.add('plain');
        pc.appendChild(K.toggle(o.plan, function (v) { o.plan = v; }));
      }
      if (C.on('codex.goals')) {
        var gg = K.group(e.body, null);
        K.cell(gg, { icon: K.tile('flag', 'red'), title: 'Цель и бюджет', value: o.goal ? K.esc(o.goal) : 'нет', action: function () { K.alert({ title: 'Цель задачи', message: 'Codex остановится, когда цель достигнута или бюджет израсходован.', field: { value: o.goal || '', placeholder: 'Например, «тесты зелёные»' }, buttons: [{ title: 'Отмена', cancel: true }, { title: 'Готово', action: function (v) { o.goal = v || null; draw(); } }] }); } });
      }
      ta.addEventListener('input', function () { K.disable(e.layer.querySelector('.nb-right .bbtn'), !ta.value.trim()); }, false);
    }
    e.left = { title: 'Отмена', action: function () { nav.dismiss(); } };
    e.right = { title: 'Запустить', style: 'done', disabled: true, action: function () {
      var ta = e.body.querySelector('textarea'), v = ta.value.trim(); if (!v) return;
      var t = C.newTask({ title: v.split(/[.\n]/)[0].slice(0, 40), text: v, ws: o.ws, plan: o.plan, att: o.att, goal: o.goal });
      nav.dismiss(); root.nav.push(S.codexTask(t.id)); S.renderDrawer();
    } };
    draw();
    nav.push(e, false); K.present(nav);
    setTimeout(function () { var ta = e.body.querySelector('textarea'); if (ta) ta.focus(); }, 450);
  }
  function workspaces(o, done) {
    var s = K.screen('Проект');
    var g = K.group(s.body, 'Недавние на ' + C.hostName(C.where));
    C.workspaces.forEach(function (w) { K.cell(g, { icon: K.tile('folder', 'blue'), title: w.name, sub: K.esc(w.path) + ' · ' + K.esc(w.branch), check: w.name === o.ws, action: function () { o.ws = w.name; done(); s.nav.pop(); }, noArrow: true }); });
    var g2 = K.group(s.body, null);
    K.cell(g2, { title: 'Другой каталог…', action: function () { K.alert({ title: 'Путь на компьютере', field: { value: '~/src/' }, buttons: [{ title: 'Отмена', cancel: true }, { title: 'Выбрать', action: function (v) { if (!v) return; var n = v.replace(/\/$/, '').split('/').pop(); C.workspaces.push({ id: 'w' + Date.now(), name: n, path: v, branch: 'main' }); o.ws = n; done(); s.nav.pop(); } }] }); } });
    return s;
  }
  function modelScreen(done) {
    var s = K.screen('Модель');
    function draw() {
      s.body.innerHTML = '';
      var g = K.group(s.body, null);
      C.models.forEach(function (m, i) { K.cell(g, { title: m.name, sub: m.sub, check: i === C.prefs.model, noArrow: true, action: function () { C.prefs.model = i; draw(); done(); } }); });
      s.body.appendChild(K.h('div', 'group-head', 'Глубина рассуждения'));
      var w = K.h('div', 'seg-wrap'); w.style.marginTop = '0'; w.appendChild(K.seg(['Низкая', 'Средняя', 'Высокая'], C.prefs.effort, function (i) { C.prefs.effort = i; done(); }, true)); s.body.appendChild(w);
      var g2 = K.group(s.body, null, 'Быстрый режим отвечает раньше и расходует лимит быстрее.');
      var c = K.cell(g2, { title: 'Быстрый режим', cls: 'has-switch' }); c.querySelector('.t').classList.add('plain');
      c.appendChild(K.toggle(C.prefs.fast, function (v) { C.prefs.fast = v; done(); }));
    }
    draw();
    return s;
  }

  /* ---------- Connections (tier 2) ---------- */
  function connections(pick, done) {
    var s = K.screen(pick ? 'Где выполнять' : 'Подключения');
    function draw() {
      s.body.innerHTML = '';
      var g = K.group(s.body, 'Компьютеры');
      C.hosts.forEach(function (h) {
        var c = K.cell(g, { icon: K.tile('devices', h.online ? 'dark' : 'gray'), titleHTML: '<span class="lamp ' + (h.online ? 'ok' : '') + '"></span>' + K.esc(h.name), sub: h.online ? h.via : 'Не в сети · был ' + h.seen, check: C.where === h.id, action: function () {
          if (pick || !C.on('codex.desktop')) { if (!h.online) { K.alert({ title: h.name + ' не в сети', message: 'Включите компьютер и откройте на нём Codex. Задачи на нём продолжатся, когда он появится.', buttons: [{ title: 'OK' }] }); return; } C.where = h.id; draw(); if (done) done(); if (pick) s.nav.pop(); else C.changed(); return; }
          s.nav.push(hostDetail(h, draw));
        }, noArrow: pick || !C.on('codex.desktop') });
        if (!pick) K.swipeDelete(c, 'Отключить', function () { C.hosts.splice(C.hosts.indexOf(h), 1); if (C.where === h.id) C.where = C.hosts[0] ? C.hosts[0].id : C.envs[0].id; draw(); C.changed(); });
      });
      if (!pick) K.cell(g, { title: 'Добавить компьютер…', action: function () { addHost(draw); } }).classList.add('cx-add');
      var ge = K.group(s.body, 'Облако', pick ? null : 'Облачное окружение клонирует репозиторий и выполняет задачу без вашего компьютера.');
      C.envs.forEach(function (en) {
        K.cell(ge, { icon: K.tile('cloud', 'blue'), title: en.name, sub: K.esc(en.repo), check: C.where === en.id, noArrow: pick, action: function () { if (pick) { C.where = en.id; if (done) done(); s.nav.pop(); return; } s.nav.push(envDetail(en)); } });
      });
    }
    draw();
    s.onReturn = draw;
    return s;
  }
  function hostDetail(h, done) {
    var s = K.screen(h.name);
    var g = K.group(s.body, null);
    K.cell(g, { title: 'Подключение', value: K.esc(h.via) });
    K.cell(g, { title: 'Состояние', value: h.online ? 'в сети' : 'не в сети' });
    var g2 = K.group(s.body, null);
    K.cell(g2, { title: 'Использовать для новых задач', check: C.where === h.id, noArrow: true, action: function (c) { C.where = h.id; c.classList.add('checked'); done(); C.changed(); } });
    if (C.on('codex.desktop')) {
      var g3 = K.group(s.body, null, 'Снимок экрана по запросу. Управление мышью и клавиатурой с iPhone не поддерживается.');
      K.cell(g3, { icon: K.tile('devices', 'graphite'), title: 'Экран компьютера', action: function () { s.nav.push(desktop(h)); } });
    }
    return s;
  }
  function desktop(h) {
    var s = K.screen('Экран', { cls: 'paper' });
    function shot() {
      s.body.innerHTML = '<div class="cx-desk"><div class="mb"><i></i><i></i><i></i></div><div class="wn"><div class="tb">Terminal — codex</div><pre>$ codex resume\n› Ускорить сборку CSS\n  ✓ npm run css  1.6s</pre></div></div><div class="note" style="text-align:center">Снимок ' + K.clock(Date.now()) + ' · ' + K.esc(h.name) + '</div>';
    }
    s.right = { title: 'Обновить', action: function () { var hd = K.hud('Снимаю экран…', 'busy'); setTimeout(function () { shot(); hd.done('Обновлено'); }, 1100); } };
    shot();
    return s;
  }
  function envDetail(en) {
    var s = K.screen(en.name);
    var g = K.group(s.body, null);
    K.cell(g, { title: 'Репозиторий', sub: K.esc(en.repo) });
    K.cell(g, { title: 'Подготовка', sub: '<span class="lamp ok"></span>' + K.esc(en.setup) });
    if (C.on('codex.computers')) {
      var g2 = K.group(s.body, 'Компьютер');
      ['Стандартный · 4 ядра', 'Большой · 16 ядер'].forEach(function (m) { K.cell(g2, { title: m, check: m.indexOf(en.machine) === 0, noArrow: true, action: function () { en.machine = m.split(' ·')[0]; s.nav.replace(envDetail(en)); } }); });
    }
    var g3 = K.group(s.body, null);
    K.cell(g3, { title: 'Использовать для новых задач', check: C.where === en.id, noArrow: true, action: function (c) { C.where = en.id; c.classList.add('checked'); C.changed(); } });
    return s;
  }
  function addHost(done) {
    K.sheet({ title: 'Как подключить компьютер? На нём должен быть открыт Codex.', buttons: [
      { title: 'Сканировать QR-код', action: function () { S.cameraSim(function () { pairing('QR-код', done); }); } },
      { title: 'Ввести код', action: function () { K.alert({ title: 'Код сопряжения', message: 'Код показан в Codex на компьютере: Настройки › Мобильное устройство.', field: { value: '', placeholder: '8 символов' }, buttons: [{ title: 'Отмена', cancel: true }, { title: 'Подключить', action: function (v) { if (v) pairing('код', done); } }] }); } },
      { title: 'Вручную по SSH', action: function () { ssh(done); } }
    ] });
  }
  function pairing(how, done) {
    var h = K.hud('Сопряжение…', 'busy');
    setTimeout(function () { C.hosts.push({ id: 'h' + Date.now(), name: 'Mac mini', via: 'Сопряжение', online: true }); h.done('Подключено'); done(); C.changed(); }, 1500);
  }
  function ssh(done) {
    var e = K.screen('SSH');
    var nav = new K.Nav();
    var g = K.group(e.body, 'Компьютер');
    function field(title, ph, val, type) { var c = K.cell(g, { title: title, cls: 'field-cell' }); var i = K.h('input', 'field'); i.placeholder = ph; i.value = val || ''; if (type) i.type = type; c.appendChild(i); return i; }
    var host = field('Хост', '192.168.1.30'), port = field('Порт', '22', '22', 'number'), user = field('Логин', 'alex');
    var gk = K.group(e.body, 'Ключ', 'Добавьте открытый ключ в ~/.ssh/authorized_keys на компьютере. Закрытый ключ не покидает iPhone.');
    var key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK7q…x2Lw chatgptx@iphone';
    var kc = K.cell(gk, { title: 'Ключ iPhone', sub: '<span class="cx-mono">' + K.esc(key) + '</span>' });
    K.cell(gk, { title: 'Скопировать открытый ключ', action: function () { K.hud('Скопировано'); }, noArrow: true }).classList.add('cx-add');
    void kc; void port;
    e.left = { title: 'Отмена', action: function () { nav.dismiss(); } };
    e.right = { title: 'Подключить', style: 'done', action: function () {
      if (!host.value) { host.focus(); return; }
      K.alert({ title: 'Неизвестный ключ сервера', message: 'Первое подключение к ' + K.esc(host.value) + '. Сверьте отпечаток с выводом <b>ssh-keygen -lf</b> на компьютере.', list: [{ k: 'ED25519 ', v: 'SHA256:9f2c…a71e' }], buttons: [{ title: 'Отмена', cancel: true }, { title: 'Доверять', action: function () {
        var hd = K.hud('Подключаюсь…', 'busy');
        setTimeout(function () { C.hosts.push({ id: 'h' + Date.now(), name: host.value, via: 'SSH · ' + (user.value || 'alex') + '@' + host.value, online: true }); hd.done('Подключено'); nav.dismiss(); done(); C.changed(); }, 1400);
      } }] });
    } };
    nav.push(e, false); K.present(nav);
  }

  /* ---------- Settings (tier 3) ---------- */
  function settings() {
    var s = K.screen('Настройки', { backTitle: 'Codex' });
    function draw() {
      s.body.innerHTML = '';
      if (C.on('codex.profile')) {
        var p = K.h('div', 'cx-prof', '<span class="av">' + M.user.initials + '</span><b>' + K.esc(M.user.name) + '</b><div class="st"><span><b>14</b>задач за неделю</span><span><b class="a">+2 318</b>строк</span><span><b class="d">−611</b>строк</span></div>');
        s.body.appendChild(p);
      }
      var g = K.group(s.body, 'Работа');
      var pol = ['Спрашивать всегда', 'В папке проекта без вопросов', 'Полный доступ'];
      K.cell(g, { icon: K.tile('shield', 'green'), title: 'Разрешения', value: pol[C.prefs.policy].split(' ')[0] === 'В' ? 'В проекте' : pol[C.prefs.policy].replace('Спрашивать всегда', 'Всегда'), action: function () { s.nav.push(policy(pol, draw)); } });
      var sty = ['Обычный', 'Кратко', 'Подробно с пояснениями'];
      if (C.on('codex.personality')) K.cell(g, { icon: K.tile('text', 'gray'), title: 'Стиль ответов', value: sty[C.prefs.style], action: function (c) { K.sheet({ buttons: sty.map(function (x, i) { return { title: x, check: i === C.prefs.style, action: function () { C.prefs.style = i; draw(); } }; }) }); } });
      if (C.on('codex.local-lock')) {
        var gl = K.group(s.body, null, 'Код-пароль спрашивается при входе в раздел Codex. Обычные чаты он не закрывает.');
        var lc = K.cell(gl, { title: 'Блокировка паролем', cls: 'has-switch' }); lc.querySelector('.t').classList.add('plain');
        lc.appendChild(K.toggle(C.prefs.lock, function (v, sw) {
          if (!v) { C.prefs.lock = false; return; }
          lockPad('Придумайте код Codex', function (ok) { C.prefs.lock = ok; sw.set(ok); });
        }));
      }
      if (C.on('codex.feedback')) { var gf = K.group(s.body, null); K.cell(gf, { title: 'Сообщить о проблеме', action: reportProblem }); }
    }
    draw();
    return s;
  }
  function policy(pol, done) {
    var s = K.screen('Разрешения');
    function draw() {
      s.body.innerHTML = '';
      var g = K.group(s.body, 'Команды', ['Codex спрашивает перед каждой командой и изменением.', 'Чтение, правки и команды в папке проекта — без вопросов. Сеть и всё за пределами проекта — с разрешения.', 'Codex ничего не спрашивает. Используйте только на отдельной машине.'][C.prefs.policy]);
      pol.forEach(function (p, i) { K.cell(g, { title: p, check: i === C.prefs.policy, noArrow: true, action: function () { C.prefs.policy = i; draw(); done(); } }); });
    }
    draw();
    return s;
  }
  function lockPad(title, done) {
    var nav = new K.Nav();
    var p = S.pinPad({ title: title, msg: 'Четыре цифры', check: function () { return true; }, ok: function () { nav.dismiss(); K.hud('Codex закрыт кодом'); done(true); } });
    var scr = { title: 'Код Codex', el: p, left: { title: 'Отмена', action: function () { nav.dismiss(); done(false); } } };
    nav.push(scr, false); K.present(nav);
  }
  function reportProblem() {
    S.editor({ title: 'Проблема', text: '', note: 'К отчёту приложится идентификатор задачи. Код и файлы проекта не отправляются.', done: 'Отпр.', action: function (v) { if (v) K.hud('Отчёт отправлен'); } });
  }

  /* ---------- Files (tier 3) ---------- */
  var TREE = { '': ['src/', 'build/', 'tests/', 'package.json', 'README.md'], 'src/': ['auth/', 'routes/', 'settings/', 'index.js'], 'src/auth/': ['link.js', 'link.test.js', 'session.js'], 'build/': ['css.js', 'cache.js'], 'tests/': ['e2e.spec.js'], 'src/routes/': ['login.js'], 'src/settings/': ['profile.js'] };
  function files(ws, dir) {
    var s = K.screen(dir ? dir.replace(/\/$/, '').split('/').pop() : ws.name);
    var g = K.group(s.body, ws.path + '/' + dir);
    (TREE[dir] || ['index.js']).forEach(function (n) {
      var isDir = /\/$/.test(n);
      K.cell(g, { icon: K.tile(isDir ? 'folder' : 'file', isDir ? 'blue' : 'gray'), title: n.replace(/\/$/, ''), action: function () { s.nav.push(isDir ? files(ws, dir + n) : fileView(dir + n)); } });
    });
    return s;
  }
  function fileView(p) {
    var s = K.screen(p.split('/').pop(), { cls: 'cx-out light' });
    s.body.innerHTML = '<pre>// ' + K.esc(p) + '\n\nexport function verifyLink(token) {\n  const data = jwt.verify(token, SECRET, {\n    algorithms: ["HS256"],\n    clockTolerance: 30\n  });\n  return findUser(data.sub);\n}\n</pre>';
    s.right = { title: 'В задачу', action: function () { K.hud('Файл упомянут'); } };
    return s;
  }

  /* ---------- Lock gate on entering Codex ---------- */
  S.codexEnter = function (open) {
    if (!C.prefs.lock || !C.on('codex.local-lock')) return open();
    var nav = new K.Nav();
    var p = S.pinPad({ title: 'Код Codex', msg: '', check: function (v) { return v === M.prefs.pin; }, ok: function () { nav.dismiss(); open(); } });
    nav.push({ title: 'Codex', el: p, left: { title: 'Отмена', action: function () { nav.dismiss(); } } }, false); K.present(nav);
  };
})();
