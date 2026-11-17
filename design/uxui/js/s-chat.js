/* Chat screen: messages, streaming, composer. Every optional control asks
   M.on('<feature id>') so a stage shows exactly its functions. */
(function () {
  'use strict';
  var S = window.S = window.S || {};
  var on = M.on;

  /* ---------- Markdown (subset) ---------- */
  function inline(s) {
    s = K.esc(s);
    s = s.replace(/`([^`]+)`/g, '<code>$1</code>');
    s = s.replace(/\*\*([^*]+)\*\*/g, '<b>$1</b>');
    s = s.replace(/(^|[^*])\*([^*]+)\*/g, '$1<i>$2</i>');
    s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a>$1</a>');
    return s;
  }
  function hl(code, lang) {
    var e = K.esc(code);
    e = e.replace(/(\/\/[^\n]*|#[^\n]*)/g, '<span class="cm">$1</span>');
    e = e.replace(/(&quot;[^&\n]*?&quot;|@&quot;[^&\n]*?&quot;)/g, '<span class="st">$1</span>');
    e = e.replace(/\b(import|with|as|for|in|if|else|return|def|print|open|float|sum|len|list|NSString|alloc|initWithFormat|release)\b/g, '<span class="kw">$1</span>');
    return e;
  }
  S.md = function (src) {
    var lines = src.split('\n'), out = '', i = 0, para = [];
    function flush() { if (para.length) { out += '<p>' + inline(para.join(' ')) + '</p>'; para = []; } }
    while (i < lines.length) {
      var l = lines[i];
      if (/^```/.test(l)) {
        flush();
        var lang = l.slice(3).trim() || 'код', code = [];
        i++;
        while (i < lines.length && !/^```/.test(lines[i])) { code.push(lines[i]); i++; }
        i++;
        out += '<div class="code" data-code="' + K.esc(code.join('\n')) + '"><div class="ch">' + K.esc(lang) + (on('chat.copy_code') ? '<span class="cc">Копировать</span>' : '') + '</div><pre>' + hl(code.join('\n'), lang) + '</pre></div>';
        continue;
      }
      if (/^#{2,3} /.test(l)) { flush(); var lv = l.indexOf(' '); out += '<h' + lv + '>' + inline(l.slice(lv + 1)) + '</h' + lv + '>'; i++; continue; }
      if (/^> /.test(l)) { flush(); out += '<blockquote>' + inline(l.slice(2)) + '</blockquote>'; i++; continue; }
      if (/^(- |\d+\. )/.test(l)) {
        flush();
        var ordered = /^\d/.test(l), items = '';
        while (i < lines.length && /^(- |\d+\. )/.test(lines[i])) { items += '<li>' + inline(lines[i].replace(/^(- |\d+\. )/, '')) + '</li>'; i++; }
        out += ordered ? '<ol>' + items + '</ol>' : '<ul>' + items + '</ul>';
        continue;
      }
      if (/^\|/.test(l)) {
        flush();
        var rows = [];
        while (i < lines.length && /^\|/.test(lines[i])) { rows.push(lines[i]); i++; }
        var t = '<table>';
        rows.forEach(function (r, k) {
          if (/^\|[-| ]+\|$/.test(r)) return;
          var cells = r.replace(/^\||\|$/g, '').split('|');
          t += '<tr>' + cells.map(function (c) { return (k === 0 ? '<th>' : '<td>') + inline(c.trim()) + (k === 0 ? '</th>' : '</td>'); }).join('') + '</tr>';
        });
        out += t + '</table>';
        continue;
      }
      if (!l.trim()) { flush(); i++; continue; }
      para.push(l); i++;
    }
    flush();
    return out;
  };
  /* Stage 10 has no renderer: show the text with Markdown markers removed. */
  S.plain = function (src) {
    return K.esc(src.replace(/```[a-z]*\n?/g, '').replace(/\*\*/g, '').replace(/`/g, '').replace(/^#{2,3} /gm, '').replace(/^- /gm, '• ').replace(/^> /gm, '').replace(/^\|[-| ]+\|$/gm, '').replace(/\|/g, '  '));
  };
  function body(md) { return on('chat.rich_text') ? '<div class="md">' + S.md(md) + '</div>' : '<div class="md plain">' + S.plain(md) + '</div>'; }

  /* ---------- Chat screen ---------- */
  S.chatScreen = function (chatId, opts) {
    opts = opts || {};
    var chat = chatId ? M.chat(chatId) : null;
    var temp = false, mode = null, tray = [], streaming = null, player = null;
    var s = { title: '', backTitle: 'Чат', tray: tray };
    var el = s.el = K.h('div', 'chat linen');
    el.style.position = 'absolute';
    var sizeCls = ['xsmall', 'small', '', 'large', 'xlarge'];
    function applySize() { sizeCls.forEach(function (c) { if (c) el.classList.remove(c); }); if (on('accessibility.large_text') && sizeCls[M.prefs.textSize]) el.classList.add(sizeCls[M.prefs.textSize]); }
    applySize();
    var banner = K.h('div', 'banner hidden');
    var scroll = K.h('div', 'scroll'), inner = K.h('div', 'inner');
    scroll.appendChild(inner);
    el.appendChild(scroll); el.appendChild(banner);
    var composer = S.composer(s);
    el.appendChild(composer.el);

    /* ----- navbar ----- */
    s.left = (opts.readOnly || opts.pushed) ? null : { icon: K.barGlyph('menu'), action: function () { S.toggleDrawer(); } };
    s.right = opts.readOnly ? null : { icon: K.barGlyph('compose'), action: function () { S.openChat(null); } };
    var tv = K.h('div', 'tv-inner');
    s.titleView = tv;
    function title() {
      var name = chat ? chat.title : (temp ? 'Временный чат' : 'Новый чат');
      if (opts.readOnly) name = chat.title;
      var st = '', solo = false, c = M.conn;
      if (opts.readOnly) st = 'Общий разговор · только чтение';
      else if (c.state === 'offline' || M.scenario.offline) st = '<span class="lamp err"></span>Нет сети';
      else if (c.state === 'preparing') st = '<span class="lamp busy"></span>Подготовка отправки… ' + c.left + ' с';
      else if (c.state === 'ready' && on('tools.model_picker')) st = M.models[M.prefs.model].name + '<span class="caret">' + K.glyph('down', 10, '#fff') + '</span>';
      else if (c.state === 'ready') st = '<span class="lamp ok"></span>Готов к отправке';
      else solo = true;
      tv.innerHTML = '<span class="tt">' + K.esc(name) + '</span>' + (solo ? '' : '<span class="st">' + st + '</span>');
      K.cls(tv, 'solo', solo);
    }
    s.onTitleTap = function () {
      if (opts.readOnly || M.conn.state !== 'ready' || !on('tools.model_picker')) return;
      S.modelPicker(function () { title(); });
    };
    function navTint() {
      if (!s.nav) return;
      K.cls(s.nav.bar, 'temp', temp);
      K.cls(document.getElementById('app'), 'temp', temp);
    }
    s.onShow = function () {
      title(); navTint();
      if (!opts.readOnly) M.prepare();
      setTimeout(scrollEnd, 60);
    };
    K.tap(tv, function () { s.onTitleTap(); }, { instant: true });
    s.onHide = function () { K.cls(document.getElementById('app'), 'temp', false); };
    M.on_('conn', function () { if (K.inDoc(el)) { title(); composer.refresh(); updateBanner(); } });
    M.on_('prefs', function () { if (K.inDoc(el)) { applySize(); title(); } });

    /* ----- banners: session and network ----- */
    function updateBanner() {
      var html = null, cls = '';
      if (M.scenario.offline) { cls = 'err'; html = '<span class="lamp err"></span>Нет подключения к интернету. Черновик сохранён.'; }
      else if (M.session.state === 'expired') { cls = 'warn with-pill'; html = '<span class="lamp warn"></span>Сессия истекла. Черновик и чаты на месте.<span class="pill go">Войти</span>'; }
      K.cls(banner, 'hidden', !html);
      K.cls(el, 'has-banner', !!html);
      if (html) {
        banner.className = 'banner ' + cls; banner.innerHTML = html;
        var p = banner.querySelector('.pill');
        if (p) K.tap(p, function () { S.signIn({ reauth: true, done: function () { M.session.state = 'active'; M.session.renewed = Date.now(); M.emit('session'); } }); }, { instant: true });
      }
    }
    M.on_('session scenario', function () { if (K.inDoc(el)) updateBanner(); });
    updateBanner();

    /* ----- message list ----- */
    function scrollEnd() { scroll.scrollTop = 1e6; }
    function renderAll() {
      inner.innerHTML = '';
      if (!chat || !chat.msgs.length) { inner.appendChild(emptyState()); return; }
      chat.msgs.forEach(function (m) { inner.appendChild(renderMsg(m)); });
      setTimeout(scrollEnd, 0);
    }
    function emptyState() {
      var e = K.h('div', 'empty-chat' + (temp ? ' temp' : ''));
      e.innerHTML = '<div class="logo"><img src="img/icon-114.png" alt=""></div><h2>' + (temp ? 'Временный чат' : 'Чем могу помочь?') + '</h2>' +
        '<p>' + (temp ? 'Этот чат не попадёт в историю и память. Копия может храниться на серверах до 30 дней.' : (opts.project ? 'Новый чат в проекте «' + K.esc(M.project(opts.project).name) + '». Учитываются его файлы и инструкции.' : 'Спросите что угодно. Ответ появится по мере написания.')) + '</p>';
      if (on('chat.temporary') && !opts.project) {
        var cells = K.group(e, null, null);
        var c = K.cell(cells, { titleHTML: '<span style="display:inline-block;vertical-align:-4px;margin-right:6px">' + K.glyph('ghost', 20, '#4b5d55') + '</span>Временный чат', cls: 'has-switch' });
        var sw = K.toggle(temp, function (v) { temp = v; renderAll(); title(); navTint(); });
        c.appendChild(sw);
      }
      return e;
    }
    function meta(m) {
      if (m.role !== 'user') return '';
      var map = {
        queued: '<span class="lamp busy"></span>Ждёт соединения — отправится один раз',
        sending: '<span class="lamp busy"></span>Отправляется…',
        failed: 'Не отправлено' + (on('chat.retry') ? ' · коснитесь «!»' : ' · текст возвращён в поле ввода'),
        uncertain: '<span class="lamp warn"></span>Отправка не подтверждена' + (on('chat.retry') ? ' · коснитесь «?»' : ''),
        stopped: 'Ответ остановлен'
      };
      return map[m.state] ? '<div class="meta">' + map[m.state] + '</div>' : '';
    }
    function renderMsg(m) {
      var w = K.h('div', 'msg ' + (m.role === 'user' ? 'user' : 'asst'));
      m._el = w;
      if (m.role === 'user') {
        var att = '';
        if (m.att && m.att.length) att = '<div class="attach-row">' + m.att.map(function (a) { return '<span class="thumb">' + (a.art ? '<div class="art ' + a.art + '"></div>' : '<div style="padding-top:14px;text-align:center;font-size:9px;font-weight:bold;color:#4b5d55;background:#fff;height:74px;overflow:hidden">' + K.glyph(a.kind === 'audio' ? 'voice' : 'file', 26, '#4b5d55', ' style="margin:0 auto 4px"') + K.esc(a.name.length > 14 ? a.name.slice(0, 13) + '…' : a.name) + '</div>') + '</span>'; }).join('') + '</div>';
        var pager = (m.versions && m.versions.length > 1) ? '<div class="pager">‹<b>' + (m.vi + 1) + ' / ' + m.versions.length + '</b>›</div>' : '';
        w.innerHTML = att + (m.md ? '<div class="bubble">' + K.esc(m.md) + '</div>' : '') + (pager ? '<div class="meta">' + pager + '</div>' : '') + meta(m);
        if (m.state === 'failed' || m.state === 'uncertain') {
          var b = K.h('span', 'err-badge' + (m.state === 'uncertain' ? ' unk' : ''), m.state === 'uncertain' ? '?' : '!');
          var bb = w.querySelector('.bubble');
          if (bb) bb.parentNode.insertBefore(b, bb); else w.appendChild(b);
          if (on('chat.retry')) K.tap(b, function () { recover(m); }, { instant: true });
        }
        var bub = w.querySelector('.bubble');
        if (bub && on('chat.copy_text')) K.hold(bub, function (e, pt) {
          var items = [{ title: 'Скопировать', action: function () { K.hud('Скопировано'); } }];
          if (on('chat.edit_message') && m.state !== 'queued' && m.state !== 'sending' && !streaming) items.push({ title: 'Изменить', action: function () { editMessage(m); } });
          bub.classList.add('held');
          K.callout(bub, items, pt);
          setTimeout(function () { bub.classList.remove('held'); }, 600);
        });
        return w;
      }
      var card = K.h('div', 'card');
      w.appendChild(card);
      m._card = card;
      fillCard(m);
      if (on('chat.copy_text')) K.hold(card, function (e, pt) {
        if (m.state === 'stream' || m.state === 'thinking') return;
        var items = [{ title: 'Скопировать', action: function () { K.hud('Скопировано'); } }];
        if (on('chat.select_text')) items.push({ title: 'Выделить', action: function () { selectText(m); } });
        card.classList.add('held');
        K.callout(card, items, pt);
        setTimeout(function () { card.classList.remove('held'); }, 600);
      });
      return w;
    }
    function curMd(m) { return m.versions ? m.versions[m.vi] : m.md; }
    function fillCard(m) {
      var card = m._card, html = '<div class="who"><img src="img/icon-58.png" alt="">ChatGPT</div>';
      if (on('tools.reasoning_status') && (m.think || m.state === 'thinking')) {
        var running = m.state === 'thinking';
        html += '<div class="think' + (m._thinkOpen ? ' open' : '') + '">' + (running ? '<span class="lamp busy"></span>' : '') +
          (running ? 'Думаю' : 'Думал ' + (m.thinkSec || 2) + ' с') + (m.searched ? ' · искал в интернете' : '') +
          '<span class="tw">' + K.glyph('down', 10, '#6b7a72', ' style="-webkit-transform:rotate(-90deg)"') + '</span><ol>' +
          (m.think || []).slice(0, running ? m._steps || 0 : 99).map(function (x) { return '<li>' + K.esc(x) + '</li>'; }).join('') + '</ol></div>';
      }
      if (m.state === 'thinking' && !on('tools.reasoning_status')) html += '<div class="waiting-dots"><span></span><span></span><span></span></div>';
      var md = curMd(m) || '';
      if (m.state === 'stream') html += body(m._shown || '').replace(/(<\/(p|li|td|pre|h2|h3|blockquote)>)(?![\s\S]*<\/(p|li|td|pre|h2|h3|blockquote)>)/, '<span class="cursor"></span>$1');
      else if (md) html += body(md);
      if (m.state === 'stream' && !m._shown) html += '<span class="cursor"></span>';
      card.innerHTML = html;
      if (m.state !== 'thinking' && m.state !== 'stream' && m.parts) m.parts.forEach(function (p) { card.appendChild(S.part(p, m, s)); });
      if (m.state === 'cut') {
        if (on('chat.continue')) {
          var cr = K.h('div', 'continue-row', '<span class="pill go">Продолжить ответ</span>');
          K.tap(cr.firstChild, function () { continueAnswer(m); }, { instant: true });
          card.appendChild(cr);
        } else card.appendChild(K.h('div', 'cut-note', 'Ответ не завершён'));
      }
      var th = card.querySelector('.think');
      if (th) K.tap(th, function () { m._thinkOpen = !m._thinkOpen; th.classList.toggle('open'); }, { instant: true });
      var ccs = card.querySelectorAll('.code .cc');
      for (var i = 0; i < ccs.length; i++) K.tap(ccs[i], function () { K.hud('Код скопирован'); }, { instant: true });
      if ((m.state === 'done' || m.state === 'cut') && !opts.readOnly) card.appendChild(actions(m));
    }
    function actions(m) {
      var row = K.h('div', 'actions');
      var any = false;
      function ab(glyph, fid, fn, label) {
        if (!on(fid)) return;
        any = true;
        var b = K.h('span', 'ab', K.glyph(glyph, 18, '#5d6f66'));
        b.setAttribute('aria-label', label);
        K.tap(b, fn, { instant: true });
        row.appendChild(b);
      }
      if (on('chat.regenerate')) {
        ab('copy', 'chat.regenerate', function () { K.hud('Скопировано'); }, 'Скопировать');
        ab('regen', 'chat.regenerate', function () { regenerate(m); }, 'Другой вариант');
      }
      ab('speaker', 'audio.read_aloud', function () { readAloud(m); }, 'Прочитать вслух');
      ab('share', 'chat.share_link', function () { S.shareChat(chat); }, 'Поделиться');
      if (M.any('chat.branch', 'chat.report', 'tools.writing_editor', 'memory.citations')) ab('more', 'chat.branch', function () { moreActions(m); }, 'Ещё');
      if (m.sources && on('chat.sources')) {
        any = true;
        var src = K.h('span', 'src', '<span class="fav" style="background:#6ea9ef"></span><span class="fav" style="background:#f3b95f"></span> Источники ' + m.sources.length);
        K.tap(src, function () { S.sources(m.sources); }, { instant: true });
        row.appendChild(src);
      }
      if (m.versions && m.versions.length > 1) {
        var pg = K.h('span', 'pager', '‹<b>' + (m.vi + 1) + ' / ' + m.versions.length + '</b>›');
        K.tap(pg, function () { m.vi = (m.vi + 1) % m.versions.length; fillCard(m); }, { instant: true });
        row.appendChild(pg);
      }
      return any ? row : K.h('span', '');
    }

    /* ----- send pipeline (simulated) ----- */
    function ensureChat(text) {
      if (chat) return;
      chat = { id: M.uid(), title: text.length > 34 ? text.slice(0, 32) + '…' : text, t: Date.now(), msgs: [], temp: temp, project: opts.project };
      if (!temp) { M.chats.unshift(chat); M.emit('history'); }
      title();
    }
    s.send = function (text, att, sendMode) {
      ensureChat(text || 'Вложение');
      if (inner.querySelector('.empty-chat')) inner.innerHTML = '';
      var um = { id: M.uid(), role: 'user', md: text, att: att, state: 'queued', t: Date.now(), mode: sendMode };
      chat.msgs.push(um); chat.t = Date.now();
      inner.appendChild(renderMsg(um)); scrollEnd();
      M.emit('history');
      dispatch(um);
    };
    function rerender(m) { var old = m._el; var n = renderMsg(m); if (old && old.parentNode) old.parentNode.replaceChild(n, old); }
    function dispatch(um) {
      if (M.scenario.offline) { um.state = 'failed'; rerender(um); if (!on('chat.retry')) composer.setText(um.md); return; }
      function go() {
        um.state = 'sending'; rerender(um);
        setTimeout(function () {
          if (M.scenario.uncertain) { M.setScenario('uncertain', false); um.state = 'uncertain'; rerender(um); return; }
          um.state = 'sent'; rerender(um);
          answer(um);
        }, 700);
      }
      if (M.conn.state === 'ready') go();
      else {
        M.prepare();
        var wait = function () { if (M.conn.state === 'ready') go(); else if (M.conn.state === 'offline') { um.state = 'failed'; rerender(um); } else setTimeout(wait, 300); };
        wait();
      }
    }
    function answer(um, preset) {
      var r = preset || M.replyFor(um.md || '', um.mode);
      var am = { id: M.uid(), role: 'assistant', md: r.md, parts: r.parts, sources: r.sources, searched: r.searched, think: r.think, thinkSec: r.thinkSec, state: 'thinking', t: Date.now() };
      chat.msgs.push(am);
      inner.appendChild(renderMsg(am)); scrollEnd();
      streaming = am; composer.refresh();
      var steps = 0;
      var tt = setInterval(function () { am._steps = ++steps; if (on('tools.reasoning_status')) fillCard(am); }, 600);
      setTimeout(function () { clearInterval(tt); stream(am, r.md, 0); }, on('tools.reasoning_status') && r.think ? 1600 : 900);
    }
    function stream(am, full, from, appendTo) {
      am.state = 'stream';
      var words = full.slice(from).split(/(\s+)/), k = 0, base = appendTo || '';
      var cutAt = M.scenario.cutoff ? Math.floor(words.length * 0.55) : -1;
      am._shown = base + full.slice(0, from);
      function tick() {
        if (streaming !== am) return;
        if (k >= words.length || k === cutAt) {
          clearInterval(am._timer);
          if (k === cutAt) { M.setScenario('cutoff', false); am.state = 'cut'; am.md = am._shown; }
          else { am.state = 'done'; if (am.versions) am.versions[am.vi] = base + full; else am.md = base + full; }
          streaming = null; composer.refresh();
          fillCard(am); scrollEnd();
          am.parts && am.parts.forEach(function (p) { if (p.making || (p.type === 'research' && !p.done)) S.animatePart(p, am, function () { fillCard(am); }); });
          if (on('integration.local_completion_notifications') && M.prefs.notifyDone && document.hidden) { /* local notification in the real app */ }
          return;
        }
        am._shown += words[k] + (words[k + 1] || ''); k += 2;
        fillCard(am);
        if (scroll.scrollHeight - scroll.scrollTop - scroll.offsetHeight < 140) scrollEnd();
      }
      clearInterval(am._timer);
      am._timer = setInterval(tick, 55);
      if (!full) tick();
    }
    s.stop = function () {
      if (!streaming) return;
      var am = streaming; streaming = null; clearInterval(am._timer);
      am.state = 'done'; am.md = am._shown || '';
      var um = chat.msgs[chat.msgs.indexOf(am) - 1];
      if (um) { um.state = 'stopped'; rerender(um); }
      fillCard(am); composer.refresh();
    };
    s.isStreaming = function () { return !!streaming; };
    /* voice turns land in the conversation as ordinary messages */
    s.appendVoice = function (lines) {
      if (!lines.length) return;
      ensureChat(lines[0][1]);
      if (inner.querySelector('.empty-chat')) inner.innerHTML = '';
      lines.forEach(function (l) {
        var m = { id: M.uid(), role: l[0] === 'Вы' ? 'user' : 'assistant', md: l[1], state: 'done', t: Date.now(), voice: true };
        chat.msgs.push(m); inner.appendChild(renderMsg(m));
      });
      M.emit('history'); scrollEnd();
    };
    function recover(m) {
      if (m.state === 'failed') {
        K.sheet({ title: 'Сообщение не отправлено. Сервер его не получил — повтор безопасен.', buttons: [
          { title: 'Отправить ещё раз', action: function () { m.state = 'queued'; rerender(m); dispatch(m); } },
          { title: 'Удалить сообщение', red: true, action: function () { chat.msgs.splice(chat.msgs.indexOf(m), 1); K.collapse(m._el); } }
        ] });
      } else {
        K.sheet({ title: 'Связь прервалась после нажатия «Отправить». Сообщение могло дойти — ChatGPT X не отправит его повторно сам.', buttons: [
          { title: 'Проверить в истории', action: function () {
            var h = K.hud('Проверяю…', 'busy');
            setTimeout(function () { h.done('Сообщение дошло'); m.state = 'sent'; rerender(m); answer(m); }, 1400);
          } }
        ] });
      }
    }
    function regenerate(m) {
      if (streaming) return;
      if (!m.versions) { m.versions = [m.md]; m.vi = 0; }
      m.versions.push(''); m.vi = m.versions.length - 1;
      m.state = 'thinking'; streaming = m; composer.refresh(); fillCard(m);
      setTimeout(function () { stream(m, M.alternate, 0); }, 900);
    }
    function continueAnswer(m) {
      if (streaming) return;
      streaming = m; composer.refresh();
      var base = m.md;
      stream(m, M.continuation, 0, base);
    }
    function editMessage(m) {
      S.editor({ title: 'Изменить', text: m.md, done: 'Отпр.', note: 'Ответы после этого сообщения уйдут в предыдущую ветку — к ней можно вернуться стрелками ‹ ›.', action: function (t) {
        if (!t || t === m.md) return;
        if (!m.versions) { m.versions = [m.md]; m.vi = 0; }
        m.versions.push(t); m.vi = m.versions.length - 1; m.md = t;
        var idx = chat.msgs.indexOf(m);
        chat.msgs.splice(idx + 1).forEach(function (x) { if (x._el && x._el.parentNode) x._el.parentNode.removeChild(x._el); });
        m.state = 'queued'; rerender(m); dispatch(m);
      } });
    }
    function selectText(m) {
      var s2 = K.screen('Выделение', { cls: 'paper' });
      s2.body.innerHTML = '<div class="md" style="padding:14px 14px 30px;-webkit-user-select:text;user-select:text">' + (on('chat.rich_text') ? S.md(curMd(m)) : S.plain(curMd(m))) + '</div>' +
        '<div class="note" style="text-align:center">Выделите фрагмент: удерживайте палец на слове и двигайте маркеры.</div>';
      S.modalScreen(s2, 'Готово');
    }
    function readAloud(m) {
      if (player) player.close();
      player = S.player(el, m, function () { player = null; });
    }
    function moreActions(m) {
      var b = [];
      if (on('chat.branch')) b.push({ title: 'Новая ветка отсюда', action: function () { K.hud('Создан новый чат'); var nc = { id: M.uid(), title: 'Ветка · ' + chat.title, t: Date.now(), msgs: chat.msgs.slice(0, chat.msgs.indexOf(m) + 1).map(function (x) { return { id: M.uid(), role: x.role, md: curMd(x), parts: x.parts, state: 'done' }; }) }; M.chats.unshift(nc); M.emit('history'); setTimeout(function () { S.openChat(nc.id); }, 700); } });
      if (on('tools.writing_editor')) b.push({ title: 'Открыть в редакторе', action: function () { S.writingEditor(curMd(m)); } });
      if (on('tools.work_handoff')) b.push({ title: 'Продолжить в «Работе»', action: function () { composer.setMode('work'); K.hud('Режим «Работа»', 'none'); } });
      if (on('memory.citations')) b.push({ title: 'Что учтено из памяти', action: function () { S.memoryCitations(); } });
      if (on('chat.report')) b.push({ title: 'Пожаловаться на ответ', red: true, action: function () {
        K.alert({ title: 'Пожаловаться?', message: 'Вместе с жалобой будет передан этот разговор, чтобы его могли проверить.', buttons: [{ title: 'Отмена', cancel: true }, { title: 'Отправить', action: function () { K.hud('Жалоба отправлена'); } }] });
      } });
      K.sheet({ buttons: b });
    }
    /* clarifications reply */
    s.answerClarify = function (text) { var p = text; s.send(p); };
    s.chat = function () { return chat; };
    s.mode = function (m) { if (m !== undefined) mode = m; return mode; };
    s.renderAll = renderAll;
    s.temp = function () { return temp; };
    s.readOnly = !!opts.readOnly;
    if (opts.readOnly) composer.el.style.display = 'none';
    if (opts.readOnly) scroll.style.bottom = '0';
    renderAll();
    return s;
  };

  /* ---------- Composer ---------- */
  S.composer = function (s) {
    var c = { el: K.h('div', 'composer') };
    var chips = K.h('div', 'chips hidden'), trayEl = K.h('div', 'tray hidden'), note = K.h('div', 'tray-note hidden');
    var row = K.h('div', 'row');
    var plus = K.h('div', 'plus', K.glyph('plus', 18, '#4b5d55'));
    var wrap = K.h('div', 'fieldwrap');
    var ta = document.createElement('textarea');
    ta.placeholder = 'Сообщение';
    ta.rows = 1;
    var mic = K.h('div', 'mic', K.glyph('mic', 20, '#6b7a72'));
    var expand = K.h('div', 'expand', K.glyph('expand', 16, '#6b7a72'));
    var send = K.h('div', 'send', 'Отпр.');
    wrap.appendChild(ta); wrap.appendChild(mic); wrap.appendChild(expand);
    row.appendChild(plus); row.appendChild(wrap); row.appendChild(send);
    c.el.appendChild(note); c.el.appendChild(trayEl); c.el.appendChild(chips); c.el.appendChild(row);

    var hasPlus = M.any('media.camera_photo', 'media.photo_picker', 'media.file_upload', 'search.web');
    K.cls(c.el, 'has-plus', hasPlus); K.cls(plus, 'hidden', !hasPlus);
    K.cls(c.el, 'has-mic', on('audio.dictation')); K.cls(mic, 'hidden', !on('audio.dictation'));
    if (!on('compose.fullscreen')) expand.style.display = 'none';

    function fit() {
      ta.style.height = '30px';
      var h = Math.min(118, Math.max(30, ta.scrollHeight));
      ta.style.height = h + 'px';
      K.cls(c.el, 'tall', h > 60);
      var sc = s.el.querySelector('.scroll');
      if (sc) sc.style.bottom = c.el.offsetHeight + 'px';
    }
    c.setText = function (t) { ta.value = t; fit(); c.refresh(); };
    ta.addEventListener('input', function () {
      fit(); c.refresh();
      if (on('compose.mentions') && /(^|\s)@$/.test(ta.value)) S.mentions(function (name) { ta.value = ta.value.replace(/@$/, '@' + name + ' '); fit(); ta.focus(); });
    }, false);
    c.refresh = function () {
      var hasText = !!ta.value.trim() || s.tray.length > 0;
      var st = s.isStreaming && s.isStreaming();
      send.className = 'send';
      if (st && on('chat.stop')) { send.classList.add('stop'); send.innerHTML = K.glyph('stop', 14, '#fff'); send.setAttribute('aria-label', 'Остановить'); }
      else if (!hasText && on('voice.conversation') && !st) { send.classList.add('voice'); send.innerHTML = K.glyph('voice', 20, '#fff'); send.setAttribute('aria-label', 'Голосовой разговор'); }
      else {
        send.innerHTML = 'Отпр.' + (M.conn.state === 'preparing' ? '<span class="lamp busy"></span>' : '');
        K.cls(send, 'disabled', !hasText || st);
      }
      fit();
    };
    K.tap(send, function () {
      if (send.classList.contains('stop')) { s.stop(); return; }
      if (send.classList.contains('voice')) { S.voice(s); return; }
      if (send.classList.contains('disabled')) return;
      var text = ta.value.trim(), att = s.tray.slice(), md = s.mode();
      ta.value = ''; s.tray.length = 0; renderTray(); s.mode(null); renderChips();
      s.send(text, att, md);
      c.refresh();
    }, { instant: true });
    K.tap(mic, function () { S.dictation(c, ta, function (t) { ta.value = (ta.value ? ta.value + ' ' : '') + t; c.refresh(); }); }, { instant: true });
    K.tap(expand, function () { S.editor({ title: 'Сообщение', text: ta.value, done: 'Готово', action: function (t) { ta.value = t; c.refresh(); } }); }, { instant: true });
    K.tap(plus, function () { plusMenu(); }, { instant: true });
    c.row = row; c.ta = ta;

    /* modes and attachments */
    var MODES = { web: ['globe', 'Поиск', ''], image: ['photo', 'Изображение', 'purple'], research: ['research', 'Исследование', 'orange'], study: ['book', 'Учёба', 'green'], work: ['bag', 'Работа', 'green'] };
    function renderChips() {
      var md = s.mode();
      K.cls(chips, 'hidden', !md);
      chips.innerHTML = '';
      if (!md) { fit(); return; }
      var ch = K.h('span', 'chip ' + MODES[md][2], K.glyph(MODES[md][0], 14, '#fff') + MODES[md][1] + '<i>✕</i>');
      K.tap(ch, function () { s.mode(null); renderChips(); }, { instant: true });
      chips.appendChild(ch);
      fit();
    }
    function renderTray() {
      K.cls(trayEl, 'hidden', !s.tray.length);
      trayEl.innerHTML = '';
      s.tray.forEach(function (a, i) {
        var t = K.h('div', 'ti' + (a.err ? ' err' : ''), a.art ? '<div class="art ' + a.art + '"></div>' : '<div class="doc">' + K.glyph(a.kind === 'audio' ? 'voice' : 'file', 22, '#4b5d55') + K.esc(a.name.length > 9 ? a.name.slice(0, 8) + '…' : a.name) + '</div>');
        if (a.up < 1) { var u = K.h('div', 'up'); var p = K.progress(); p.set(a.up); u.appendChild(p); t.appendChild(u); a._p = p; }
        var x = K.h('div', 'x', '✕');
        K.tap(x, function () { s.tray.splice(i, 1); renderTray(); c.refresh(); }, { instant: true });
        t.appendChild(x);
        if (a.kind === 'audio' && on('media.audio_attachment_playback')) K.tap(t, function () { K.hud('▶ 0:07', 'none', 900); });
        trayEl.appendChild(t);
      });
      fit();
    }
    function addAttachment(a) {
      if (M.scenario.uploadLimit && on('media.attachment_constraints')) {
        note.textContent = 'Лимит загрузок на сегодня исчерпан — обновится в 18:40. Текст можно отправить без вложения.';
        K.cls(note, 'hidden', false); fit();
        setTimeout(function () { K.cls(note, 'hidden', true); fit(); }, 5000);
        return;
      }
      function put() {
        a.up = 0; s.tray.push(a); renderTray(); c.refresh();
        var iv = setInterval(function () { a.up = Math.min(1, a.up + 0.25); if (a._p) a._p.set(a.up); if (a.up >= 1) { clearInterval(iv); renderTray(); } }, 350);
      }
      if (s.tray.length >= 4 && on('media.attachment_remove_replace')) {
        K.alert({ title: 'Заменить вложение?', message: 'К сообщению можно приложить до 4 файлов. Заменить последний — «' + K.esc(s.tray[3].name) + '»?', buttons: [{ title: 'Отмена', cancel: true }, { title: 'Заменить', action: function () { s.tray.pop(); put(); } }] });
        return;
      }
      put();
    }
    c.addAttachment = addAttachment;
    c.setMode = function (md) { s.mode(md); renderChips(); };
    function setMode(m) { s.mode(m); renderChips(); ta.focus(); }
    function plusMenu() {
      var it = [], md = s.mode();
      if (on('media.camera_photo')) it.push({ icon: K.tile('camera', 'graphite', 57), title: 'Камера', action: function () { S.cameraSim(function () { addAttachment({ name: 'Фото.jpg', art: 'forest', kind: 'image' }); }); } });
      if (on('media.photo_picker')) it.push({ icon: K.tile('photo', 'orange', 57), title: 'Фото', action: function () { S.photoPicker(function (arts) { arts.forEach(function (a) { addAttachment({ name: 'Фото.jpg', art: a, kind: 'image' }); }); }); } });
      if (on('media.file_upload')) it.push({ icon: K.tile('file', 'blue', 57), title: 'Файл', action: function () { S.filePicker(function (f) { addAttachment(f); }); } });
      if (on('library.attach')) it.push({ icon: K.tile('library', 'teal', 57), title: 'Из библиотеки', action: function () { S.libraryPicker(function (f) { addAttachment({ name: f.name, kind: f.kind, art: f.art }); }); } });
      if (on('search.web')) it.push({ icon: K.tile('globe', 'blue', 57), title: 'Поиск в интернете', on: md === 'web', action: function () { setMode(md === 'web' ? null : 'web'); } });
      if (on('images.create')) it.push({ icon: K.tile('photo', 'purple', 57), title: 'Создать изображение', on: md === 'image', action: function () { setMode(md === 'image' ? null : 'image'); } });
      if (on('tools.deep_research')) it.push({ icon: K.tile('research', 'orange', 57), title: 'Исследование', on: md === 'research', action: function () { setMode(md === 'research' ? null : 'research'); } });
      if (on('tools.study')) it.push({ icon: K.tile('book', 'green', 57), title: 'Учёба', on: md === 'study', action: function () { setMode(md === 'study' ? null : 'study'); } });
      if (on('media.document_scan')) it.push({ icon: K.tile('scan', 'gray', 57), title: 'Скан', action: function () { S.scanner(function (n) { addAttachment({ name: 'Скан (' + n + ' стр.).pdf', kind: 'pdf' }); }); } });
      if (on('media.record_audio_attachment')) it.push({ icon: K.tile('voice', 'red', 57), title: 'Аудио', action: function () { S.recordAudio(function () { addAttachment({ name: 'Запись 0:07', kind: 'audio' }); }); } });
      if (on('tools.work_mode')) it.push({ icon: K.tile('bag', 'dark', 57), title: 'Работа', on: md === 'work', action: function () { setMode(md === 'work' ? null : 'work'); } });
      K.actGrid({ items: it });
    }
    c.refresh();
    return c;
  };

  /* ---------- Rich parts ---------- */
  var PH = { image: ['photo', 'purple', 'Изображение', 'images.create'], chart: ['chart', 'teal', 'График', 'tools.data_analysis'], research: ['research', 'orange', 'Отчёт исследования', 'tools.deep_research'], email: ['mail', 'blue', 'Черновик письма', 'tools.email_draft'], clarify: ['sliders', 'green', 'Уточняющие вопросы', 'compose.clarifications'], file: ['file', 'blue', 'Файл', 'media.download_file'], approve: ['apps', 'purple', 'Действие приложения', 'tools.action_approval'] };
  S.part = function (p, m, scr) {
    var ph = PH[p.type];
    if (ph && !on(ph[3])) {
      /* graceful fallback: the account's history may hold content this stage cannot show yet */
      return K.h('div', 'part ph', K.tile(ph[0], ph[1], 29) + '<b>' + ph[2] + '</b>Этот элемент ответа пока не показывается на iPhone — он сохранён в разговоре.');
    }
    var w = K.h('div', 'part');
    if (p.type === 'image') {
      w.innerHTML = '<div class="imgcard"><div class="art ' + p.art + '"></div>' + (p.making ? '<div class="making">Создаю изображение…<div class="progress"><i style="width:' + Math.round((p.prog || 0) * 100) + '%"></i></div></div>' : '<div class="bar">' + (on('images.save_share') ? '<span class="pill">Сохранить</span><span class="pill">Отправить</span>' : '') + '</div>') + '</div>';
      if (!p.making) {
        var pills = w.querySelectorAll('.pill');
        if (pills[0]) K.tap(pills[0], function () { K.hud('Сохранено в «Фото»'); }, { instant: true });
        if (pills[1]) K.tap(pills[1], function () { K.sheet({ buttons: [{ title: 'Отправить по почте' }, { title: 'Отправить сообщением' }, { title: 'Скопировать' }] }); }, { instant: true });
        if (on('images.gallery')) K.tap(w.querySelector('.art'), function () { S.lightbox({ art: p.art, prompt: 'Изображение из разговора' }); });
      }
    } else if (p.type === 'chart') {
      var max = 0; p.data.forEach(function (d) { max = Math.max(max, d[1]); });
      var bars = '', lbl = '';
      p.data.forEach(function (d, i) { var x = 18 + i * 74; bars += '<div class="b" style="left:' + x + 'px;height:' + Math.round(d[1] / max * 100) + 'px"><span>' + String(d[1]).replace('.', ',') + '</span></div>'; lbl += '<span style="left:' + x + 'px">' + d[0] + '</span>'; });
      w.innerHTML = '<div class="chart"><div class="ct">' + K.esc(p.title) + '</div><div class="bars">' + bars + '</div><div class="lbl">' + lbl + '</div></div><div class="showcode">Показать код анализа ›</div>';
      var sc = w.querySelector('.showcode');
      K.tap(sc, function () { sc.outerHTML = '<div class="md">' + S.md('```python\nimport matplotlib.pyplot as plt\nplt.bar(["Янв","Фев","Мар"], [1.2, 1.5, 1.9])\nplt.title("Выручка, млн ₽")\n```') + '</div>'; }, { instant: true });
    } else if (p.type === 'research') {
      var steps = ['Составил план исследования', 'Нашёл ' + (p.sources || 0) + ' источников', 'Сравнил данные и проверил даты', 'Пишу отчёт'];
      var shown = p.done ? 4 : (p.step || 0);
      w.innerHTML = '<div class="research"><div class="rh">' + K.tile('research', 'orange', 29) + '<b>' + K.esc(p.title) + '</b><span>' + (p.done ? 'Готово · ' + p.min + ' мин · ' + p.sources + ' источника · ' + p.pages + ' стр.' : 'Исследование идёт — можно закрыть приложение, отчёт появится в этом чате') + '</span></div>' +
        (p.done ? '' : '<div class="progress"><i style="width:' + Math.round(shown / 4 * 100) + '%"></i></div>') +
        '<div class="steps">' + steps.slice(0, Math.max(1, shown)).map(function (x, i) { return '<div><span class="lamp ' + (p.done || i < shown - 1 ? 'ok' : 'busy') + '"></span>' + x + '</div>'; }).join('') + '</div>' +
        (p.done ? '<div class="rf"><span class="pill go">Открыть отчёт</span>' + (on('tools.research_export') ? '<span class="pill">Сохранить PDF</span>' : '') + '</div>' : '') + '</div>';
      var ps = w.querySelectorAll('.pill');
      if (ps[0]) K.tap(ps[0], function () { var s2 = K.screen('Отчёт', { cls: 'paper' }); s2.body.innerHTML = '<div class="md" style="padding:14px">' + S.md('## ' + p.title + '\n\n### Кратко\nРынок растёт третий год подряд: спрос смещается к городским моделям с батареей 500–700 Вт·ч.\n\n### Ключевые цифры\n- Продажи 2025 г. — около 190 тыс. шт.\n- Средняя цена — 95 тыс. ₽\n- Доля онлайн-продаж — 58 %\n\n### Источники\n1. Отраслевой обзор, 2026\n2. Данные маркетплейсов\n3. Интервью дилеров') + '</div>'; S.modalScreen(s2, 'Готово'); }, { instant: true });
      if (ps[1]) K.tap(ps[1], function () { K.hud('PDF сохранён в «Библиотеку»'); }, { instant: true });
    } else if (p.type === 'email') {
      w.innerHTML = '<div class="mailcard"><div class="mf"><label>Кому:</label><input value="' + K.esc(p.to) + '" placeholder="адрес"></div><div class="mf"><label>Копия:</label><input value="' + K.esc(p.cc) + '"></div><div class="mf"><label>Тема:</label><input value="' + K.esc(p.subject) + '"></div><textarea>' + K.esc(p.body) + '</textarea><div class="mb"><span class="pill">Скопировать</span>' + (on('tools.email_send') ? '<span class="pill go">Отправить…</span>' : '') + '</div></div>';
      var mp = w.querySelectorAll('.pill');
      K.tap(mp[0], function () { K.hud('Письмо скопировано'); }, { instant: true });
      if (mp[1]) K.tap(mp[1], function () { K.sheet({ title: 'Как отправить письмо?', buttons: [{ title: 'Открыть в «Почте»', action: function () { K.hud('Открываю «Почту»'); } }, { title: 'Через подключённую почту', action: function () { S.approval('Почта', 'Отправить письмо', [{ k: 'Кому', v: p.to || '—' }, { k: 'Тема', v: p.subject }], function () { K.hud('Письмо отправлено'); }); } }] }); }, { instant: true });
    } else if (p.type === 'clarify') {
      var qi = p.qi || 0, q = p.qs[qi], sel = p.sel || (p.sel = []);
      w.innerHTML = '<div class="clarify' + (p.answered ? ' answered' : '') + '"><div class="cq">' + K.esc(q.q) + '<small>' + (qi + 1) + ' из ' + p.qs.length + '</small></div>' +
        q.opts.map(function (o, i) { return '<div class="opt' + (sel[qi] && sel[qi].indexOf(i) >= 0 ? ' checked' : '') + '" data-i="' + i + '">' + K.esc(o) + '<span class="check"></span></div>'; }).join('') +
        '<div class="own"><input placeholder="Свой вариант"></div><div class="cf"><span class="pill">Пропустить</span> <span class="pill go">' + (qi < p.qs.length - 1 ? 'Далее' : 'Ответить') + '</span></div></div>';
      if (!p.answered) {
        var opts = w.querySelectorAll('.opt');
        for (var i = 0; i < opts.length; i++) (function (o) {
          K.tap(o, function () {
            var n = +o.getAttribute('data-i'); sel[qi] = sel[qi] || [];
            if (q.multi) { var k = sel[qi].indexOf(n); if (k >= 0) sel[qi].splice(k, 1); else sel[qi].push(n); }
            else sel[qi] = [n];
            var all = w.querySelectorAll('.opt'); for (var j = 0; j < all.length; j++) K.cls(all[j], 'checked', sel[qi].indexOf(+all[j].getAttribute('data-i')) >= 0);
          }, { instant: true });
        })(opts[i]);
        var cps = w.querySelectorAll('.cf .pill');
        var next = function () {
          var own = w.querySelector('.own input').value;
          if (own) { sel[qi] = sel[qi] || []; p.own = (p.own || []); p.own[qi] = own; }
          if (qi < p.qs.length - 1) { p.qi = qi + 1; var n2 = S.part(p, m, scr); w.parentNode.replaceChild(n2, w); return; }
          p.answered = true;
          var txt = p.qs.map(function (qq, k) { return qq.q + ' ' + ((sel[k] || []).map(function (n) { return qq.opts[n]; }).concat(p.own && p.own[k] ? [p.own[k]] : []).join(', ') || 'без разницы'); }).join('\n');
          var n3 = S.part(p, m, scr); w.parentNode.replaceChild(n3, w);
          scr.send(txt);
        };
        K.tap(cps[0], next, { instant: true }); K.tap(cps[1], next, { instant: true });
      }
    } else if (p.type === 'file') {
      if (p.expired && !on('media.file_expiry')) { w.innerHTML = '<div class="filecard expired">' + K.tile('file', 'gray', 29) + '<b>' + K.esc(p.name) + '</b><span>Недоступен</span></div>'; return w; }
      w.innerHTML = '<div class="filecard' + (p.expired ? ' expired' : '') + '">' + K.tile('file', p.expired ? 'gray' : 'blue', 29) + '<b>' + K.esc(p.name) + '</b><span class="sub">' + (p.expired ? 'Срок хранения истёк — загрузите файл заново' : (p.done ? 'Сохранён · ' : '') + K.bytes(p.size)) + '</span><span class="pill' + (p.expired ? '' : (p.done ? '' : ' go')) + '">' + (p.expired ? 'Загрузить' : (p.done ? 'Открыть в…' : 'Скачать')) + '</span></div>';
      var fp = w.querySelector('.pill'), fc = w.firstChild;
      K.tap(fp, function () {
        if (p.expired) { S.filePicker(function () { p.expired = false; p.size = 820e3; p.done = true; var n = S.part(p, m, scr); w.parentNode.replaceChild(n, w); K.hud('Файл загружен'); }); return; }
        if (p.done) { K.sheet({ title: p.name, buttons: [{ title: 'Открыть в «Pages»' }, { title: 'Отправить по почте' }] }); return; }
        fp.style.display = 'none';
        var pr = K.progress(); fc.appendChild(pr); var f = 0;
        var iv = setInterval(function () {
          f += 0.2; pr.set(f);
          if (M.scenario.offline) { clearInterval(iv); fc.removeChild(pr); fp.style.display = ''; fp.textContent = 'Повторить'; fc.querySelector('span').textContent = 'Нет сети — загрузка прервана'; return; }
          if (f >= 1) { clearInterval(iv); p.done = true; var n = S.part(p, m, scr); w.parentNode.replaceChild(n, w); }
        }, 300);
      }, { instant: true });
    } else if (p.type === 'approve') {
      w.innerHTML = '<div class="research"><div class="rh">' + K.tile('apps', 'purple', 29) + '<b>«' + K.esc(p.app) + '» хочет ' + K.esc(p.action) + '</b><span>' + (p.state === 'ok' ? 'Разрешено — событие создано' : (p.state === 'no' ? 'Отклонено — ничего не изменено' : 'Ничего не произойдёт без вашего разрешения')) + '</span></div><div class="steps">' + p.params.map(function (x) { return '<div><span style="color:#6b7a72;display:inline-block;min-width:76px">' + K.esc(x.k) + '</span>' + K.esc(x.v) + '</div>'; }).join('') + '</div>' + (p.state ? '' : '<div class="rf"><span class="pill go">Разрешить</span><span class="pill">Отклонить</span></div>') + '</div>';
      var ap = w.querySelectorAll('.rf .pill');
      if (ap.length) {
        K.tap(ap[0], function () { p.state = 'ok'; var n = S.part(p, m, scr); w.parentNode.replaceChild(n, w); K.hud('Событие создано'); }, { instant: true });
        K.tap(ap[1], function () { p.state = 'no'; var n = S.part(p, m, scr); w.parentNode.replaceChild(n, w); }, { instant: true });
      }
    }
    return w;
  };
  /* progress animations for parts that keep working after the text */
  S.animatePart = function (p, m, redraw) {
    if (p.type === 'image') {
      p.prog = 0;
      var iv = setInterval(function () { p.prog += 0.2; if (p.prog >= 1) { clearInterval(iv); p.making = false; M.images.unshift({ art: p.art, prompt: 'Новое изображение' }); } redraw(); }, 700);
    } else if (p.type === 'research') {
      p.step = 1; p.sources = 0;
      var iv2 = setInterval(function () { p.step++; p.sources += 11; if (p.step > 4) { clearInterval(iv2); p.done = true; p.min = 4; p.pages = 8; } redraw(); }, 1800);
    }
  };
})();
