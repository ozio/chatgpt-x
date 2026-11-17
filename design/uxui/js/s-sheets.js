/* Sheets and modal flows used by the chat: model, sources, sharing, dictation,
   voice, media pickers, scanner, lightbox, sign-in. */
(function () {
  'use strict';
  var S = window.S;
  var on = M.on;

  /* ---------- Model picker ---------- */
  S.modelPicker = function (done) {
    var b = M.models.map(function (m, i) { return { title: m.name, check: i === M.prefs.model, action: function () { M.prefs.model = i; M.emit('prefs'); done(); } }; });
    if (M.any('tools.reasoning_effort', 'tools.model_version', 'tools.model_auto_switch')) b.push({ title: 'Настройки модели…', action: function () { S.modelSettings(done); } });
    K.sheet({ title: 'Модель для разговора: «' + M.models[M.prefs.model].name + '» — ' + M.models[M.prefs.model].sub.toLowerCase() + '. Список берётся из вашего аккаунта.', buttons: b });
  };
  S.modelSettings = function (done) {
    var s = K.screen('Модель');
    if (on('tools.reasoning_effort')) {
      s.body.appendChild(K.h('div', 'group-head', 'Глубина рассуждения'));
      var w = K.h('div', 'seg-wrap'); w.appendChild(K.seg(['Лёгкая', 'Обычная', 'Глубокая'], M.prefs.effort, function (i) { M.prefs.effort = i; }, true)); s.body.appendChild(w);
      s.body.appendChild(K.h('div', 'group-foot', 'Глубже — точнее, но дольше. Применяется к режиму «Думать».'));
    }
    if (on('tools.model_version')) {
      var g = K.group(s.body, 'Версия');
      ['Текущая', 'Предыдущая'].forEach(function (v, i) { var c = K.cell(g, { title: v, plain: true, check: M.prefs.version === i, action: function () { M.prefs.version = i; var all = g.querySelectorAll('.cell'); for (var k = 0; k < all.length; k++) K.cls(all[k], 'checked', all[k] === c); }, noArrow: true }); });
    }
    if (on('tools.model_auto_switch')) {
      var g2 = K.group(s.body, null, 'Для сложных вопросов ChatGPT может сам перейти к более глубокому рассуждению.');
      var c2 = K.cell(g2, { title: 'Авто-переключение', cls: 'has-switch' }); c2.appendChild(K.toggle(M.prefs.autoSwitch, function (v) { M.prefs.autoSwitch = v; }));
    }
    S.modalScreen(s, 'Готово', { onDone: function () { M.emit('prefs'); if (done) done(); } });
  };

  /* ---------- Sources ---------- */
  S.sources = function (list) {
    var s = K.screen('Источники');
    var g = K.group(s.body, list.length + ' ' + (list.length < 5 ? 'источника' : 'источников'), 'Ссылки открываются в Safari.');
    list.forEach(function (x, i) {
      K.cell(g, { titleHTML: '<span style="font-weight:normal;color:#6b7a72;margin-right:6px">' + (i + 1) + '</span>' + K.esc(x.title), sub: K.esc(x.host), action: function () {
        K.alert({ title: 'Открыть в Safari?', message: K.esc(x.host), buttons: [{ title: 'Отмена', cancel: true }, { title: 'Открыть' }] });
      } }).classList.add('big');
    });
    S.modalScreen(s, 'Готово');
  };

  /* ---------- Share a conversation ---------- */
  S.shareChat = function (chat) {
    if (!chat) return;
    K.alert({ title: 'Поделиться ссылкой', message: 'Любой, у кого есть ссылка, сможет прочитать этот разговор. Новые сообщения после создания ссылки в неё не попадут. Ваше имя не показывается.', buttons: [{ title: 'Отмена', cancel: true }, { title: 'Создать', action: function () {
      var h = K.hud('Создаю ссылку…', 'busy');
      setTimeout(function () {
        h.hide();
        if (!M.sharedLinks.some(function (l) { return l.chat === chat.id; })) M.sharedLinks.unshift({ chat: chat.id, title: chat.title, t: Date.now() });
        K.actGrid({ title: 'chatgpt.com/share/6f2e…a91c', items: [
          { icon: K.tile('mail', 'blue', 57), title: 'Почта', action: function () { K.hud('Открываю «Почту»'); } },
          { icon: K.tile('compose', 'green', 57), title: 'Сообщение', action: function () { K.hud('Открываю «Сообщения»'); } },
          { icon: K.tile('link', 'gray', 57), title: 'Скопировать', action: function () { K.hud('Ссылка скопирована'); } }
        ] });
      }, 900);
    } }] });
  };

  /* ---------- Read aloud mini player ---------- */
  S.player = function (host, m, onClose) {
    var speeds = ['1×', '1,25×', '1,5×', '0,75×'], sp = 0, playing = true, t = 0;
    var bar = K.h('div', 'banner warn with-pill', '');
    bar.style.background = '-webkit-linear-gradient(top, #e7f6ee, #c6e6d5)';
    bar.style.borderBottomColor = '#7fae95'; bar.style.color = '#1d3d2e'; bar.style.paddingLeft = '44px'; bar.style.paddingRight = '118px';
    host.appendChild(bar);
    host.classList.add('has-banner');
    function draw() {
      bar.innerHTML = '<span style="position:absolute;left:10px;top:4px" class="pp">' + K.glyph(playing ? 'pause' : 'play', 24, '#1f7d52') + '</span>' +
        (playing ? 'Читаю вслух · 0:' + (t < 10 ? '0' : '') + t : 'Пауза · 0:' + (t < 10 ? '0' : '') + t) +
        '<span class="pill" style="right:46px">' + speeds[sp] + '</span><span class="pill" style="right:8px;min-width:32px">✕</span>';
      var ps = bar.querySelectorAll('.pill');
      K.tap(bar.querySelector('.pp'), function () { playing = !playing; draw(); }, { instant: true });
      K.tap(ps[0], function () { sp = (sp + 1) % speeds.length; draw(); }, { instant: true });
      K.tap(ps[1], close, { instant: true });
    }
    var iv = setInterval(function () { if (playing) { t++; if (t > 42) close(); else draw(); } }, 1000);
    function close() { clearInterval(iv); if (bar.parentNode) bar.parentNode.removeChild(bar); if (!host.querySelector('.banner:not(.hidden)')) host.classList.remove('has-banner'); onClose(); }
    draw();
    return { close: close };
  };

  /* ---------- Writing editor ---------- */
  S.writingEditor = function (text) {
    var s = K.screen('Редактор', { cls: 'paper' });
    s.el.innerHTML = '';
    var ta = document.createElement('textarea');
    ta.value = text.replace(/\*\*/g, '');
    ta.style.cssText = 'position:absolute;left:0;top:0;right:0;bottom:44px;width:100%;border:0;outline:none;padding:12px;font-size:16px;line-height:22px;resize:none';
    var tb = K.h('div', 'toolbar bottom');
    tb.style.textAlign = 'center';
    ['Короче', 'Проще', 'Официальнее', 'Исправить ошибки'].forEach(function (x) { var b = K.bbtn({ title: x, action: function () { var h = K.hud('Переписываю…', 'busy'); setTimeout(function () { h.done('Готово'); }, 1200); } }); b.style.marginRight = '4px'; b.style.minWidth = '0'; tb.appendChild(b); });
    s.el.appendChild(ta); s.el.appendChild(tb);
    S.modalScreen(s, 'Готово', { cancel: true });
  };

  /* ---------- Memory citations ---------- */
  S.memoryCitations = function () {
    var s = K.screen('Что учтено');
    var g = K.group(s.body, 'В этом ответе', 'Можно отметить, если факт устарел или не должен упоминаться.');
    [['Воспоминание', 'Пользуется iPhone 5 с iOS 6'], ['Инструкции', 'Отвечай по-русски, коротко и по делу'], ['Прошлый чат', 'Python: прочитать CSV']].forEach(function (x) {
      K.cell(g, { title: x[1], sub: x[0], action: function () {
        if (!on('memory.citation_feedback')) return;
        K.sheet({ title: x[1], buttons: [{ title: 'Это было полезно' }, { title: 'Исправить…' }, { title: 'Больше не упоминать', red: true, action: function () { K.hud('Не будет упоминаться'); } }] });
      } });
    });
    S.modalScreen(s, 'Готово');
  };

  /* ---------- @mentions ---------- */
  S.mentions = function (pick) {
    var b = M.apps.filter(function (a) { return a.on; }).map(function (a) { return { title: a.name, action: function () { pick(a.name); } }; });
    if (on('library.browse')) b.push({ title: 'Библиотека', action: function () { pick('Библиотека'); } });
    K.sheet({ title: 'Упомянуть приложение или источник', buttons: b });
  };

  /* ---------- Dictation (audio.dictation 9; cancel/retry 8; streaming 7) ---------- */
  S.dictation = function (comp, ta, put) {
    var row = comp.row, sec = 0, live = on('audio.dictation_streaming') && M.prefs.streamingDictation;
    var phrase = ['Подскажи', 'как', 'приготовить', 'сырники', 'без', 'муки'], said = 0;
    var r = K.h('div', 'rec');
    function recording() {
      sec = 0; said = 0;
      r.className = 'rec';
      r.innerHTML = '<span class="rdot"></span><span class="time">0:00</span>' + (live ? '<div class="live">Говорите…</div>' : '<div class="wave"></div>') +
        (on('audio.dictation_cancel') ? '<span class="pill cancel">Отмена</span>' : '') + '<span class="pill go">Готово</span>';
      var wave = r.querySelector('.wave'), liveEl = r.querySelector('.live');
      if (wave) for (var i = 0; i < 18; i++) wave.appendChild(K.h('i', ''));
      clearInterval(r._iv);
      r._iv = setInterval(function () {
        sec++;
        var s2 = Math.floor(sec / 4);
        r.querySelector('.time').textContent = '0:' + (s2 < 10 ? '0' : '') + s2;
        if (wave) { var bars = wave.childNodes; for (var j = 0; j < bars.length; j++) bars[j].style.height = (3 + Math.round(Math.random() * 20)) + 'px'; }
        if (liveEl && sec % 3 === 0 && said < phrase.length) { said++; liveEl.textContent = phrase.slice(0, said).join(' ') + '…'; }
      }, 250);
      var pills = r.querySelectorAll('.pill');
      if (pills.length === 2) K.tap(pills[0], close, { instant: true });
      K.tap(pills[pills.length - 1], recognise, { instant: true });
    }
    function busy() { r.className = 'rec busy'; r.innerHTML = '<span class="busytext"><span class="spinner small">' + K.spinnerSVG('#3f5249') + '</span>Распознаю…</span>'; }
    function recognise() {
      clearInterval(r._iv); busy();
      setTimeout(function () {
        if (M.scenario.dictationFail && on('audio.dictation_retry')) {
          M.setScenario('dictationFail', false);
          r.innerHTML = '<span class="busytext" style="color:#a3261a">Не распознано. Запись сохранена.</span><span class="pill cancel">Отмена</span><span class="pill go">Повторить</span>';
          var p2 = r.querySelectorAll('.pill');
          K.tap(p2[0], close, { instant: true });
          K.tap(p2[1], function () { busy(); setTimeout(function () { close(); put(phrase.join(' ')); }, 1200); }, { instant: true });
          return;
        }
        close(); put(phrase.join(' '));
      }, 1100);
    }
    function close() { clearInterval(r._iv); if (r.parentNode) r.parentNode.removeChild(r); row.style.display = ''; }
    row.style.display = 'none';
    row.parentNode.appendChild(r);
    recording();
  };

  /* ---------- Voice: turn-based conversation (record → answer → spoken) ---------- */
  S.voice = function (scr) {
    var v = K.h('div', 'vscreen');
    var state = 'listen', muted = false, quiet = false, showText = on('voice.transcript') ? M.prefs.transcript : false, turn = 0;
    v.innerHTML = '<div class="vtop"></div><div class="orb"></div><div class="vstate"></div><div class="vhint"></div><div class="vtrans"></div><div class="vbtns"></div>';
    var top = v.querySelector('.vtop');
    if (on('voice.transcript')) { var tb = K.bbtn({ title: 'Текст', action: function () { showText = !showText; draw(); } }); tb.style.left = '6px'; top.appendChild(tb); }
    if (M.any('voice.choose_voice', 'voice.language', 'voice.choose_model')) { var sb = K.bbtn({ icon: K.barGlyph('sliders'), action: function () { S.voiceSettings(); } }); sb.style.right = '6px'; top.appendChild(sb); }
    var lines = [];
    function draw() {
      v.className = 'vscreen ' + (M.scenario.voiceNet ? 'net' : state) + (muted ? ' muted' : '');
      var st = { listen: muted ? 'Микрофон выключен' : 'Слушаю', send: 'Отправляю…', thinking: 'Думаю…', speaking: 'Говорю' }[state];
      var hint = { listen: muted ? 'Включите микрофон, чтобы продолжить' : 'Говорите. Когда закончите — коснитесь шара.', send: '', thinking: '', speaking: 'Коснитесь шара, чтобы перебить' }[state];
      if (M.scenario.voiceNet) { st = 'Плохая связь'; hint = 'Переподключаюсь… Ваша последняя фраза сохранена и будет отправлена один раз.'; }
      v.querySelector('.vstate').textContent = st;
      v.querySelector('.vhint').textContent = hint;
      var tr = v.querySelector('.vtrans');
      tr.innerHTML = showText ? lines.map(function (l) { return '<p><b>' + l[0] + ':</b> ' + K.esc(l[1]) + '</p>'; }).join('') : '';
      if (on('voice.usage_limits') && turn >= 3) tr.innerHTML = '<div class="vlimit"><b>Лимит голосового режима исчерпан</b><br>Сбросится завтра в 03:00. Можно продолжить текстом в этом же чате.</div>';
      tr.scrollTop = 1e5;
      var bt = v.querySelector('.vbtns');
      bt.innerHTML = '';
      function vb(glyph, label, cls, fn) { var b = K.h('div', 'vb ' + cls, '<div class="c">' + K.glyph(glyph, 26, cls.indexOf('on') >= 0 ? '#1d3d2e' : '#fff') + '</div>' + label); K.tap(b, fn, { instant: true }); bt.appendChild(b); }
      if (on('voice.mute')) {
        vb('mic', muted ? 'Микр. выкл.' : 'Микрофон', muted ? 'on' : '', function () { muted = !muted; draw(); });
        vb(quiet ? 'speakerOff' : 'speaker', quiet ? 'Звук выкл.' : 'Звук', quiet ? 'on' : '', function () { quiet = !quiet; draw(); });
      }
      vb('plus', 'Завершить', 'red', end);
      bt.lastChild.querySelector('svg').style.webkitTransform = 'rotate(45deg)';
    }
    var timer = null;
    function cycle() {
      clearTimeout(timer);
      if (state === 'send') timer = setTimeout(function () { lines.push(['Вы', ['Какая погода завтра в Казани?', 'А что надеть?', 'Спасибо!'][turn % 3]]); state = 'thinking'; draw(); cycle(); }, 900);
      else if (state === 'thinking') timer = setTimeout(function () { state = 'speaking'; lines.push(['ChatGPT', ['Завтра около нуля и мокрый снег.', 'Тёплую куртку и непромокаемую обувь.', 'Пожалуйста! Хорошего дня.'][turn % 3]]); turn++; draw(); cycle(); }, 1400);
      else if (state === 'speaking') timer = setTimeout(function () { state = 'listen'; draw(); }, 3200);
    }
    K.tap(v.querySelector('.orb'), function () {
      if (M.scenario.voiceNet) return;
      if (state === 'listen' && !muted) { state = 'send'; draw(); cycle(); }
      else if (state === 'speaking' && on('voice.interrupt')) { clearTimeout(timer); state = 'listen'; draw(); }
    }, { instant: true });
    M.on_('scenario', function () { if (K.inDoc(v)) draw(); });
    var nav = K.present(v, { fade: true });
    document.getElementById('app').classList.add('dark');
    function end() {
      clearTimeout(timer);
      if (!(on('preferences.appearance') && M.prefs.theme === 1)) document.getElementById('app').classList.remove('dark');
      nav.dismiss();
      if (lines.length && scr && scr.appendVoice) { scr.appendVoice(lines); K.hud('Разговор сохранён в чате', 'none', 1300); }
    }
    draw();
  };
  S.voiceSettings = function () {
    var s = K.screen('Голос');
    if (on('voice.choose_voice')) {
      var g = K.group(s.body, 'Голос', 'Коснитесь, чтобы прослушать.');
      ['Сосна', 'Река', 'Янтарь', 'Ветер'].forEach(function (n) { var c = K.cell(g, { title: n, plain: true, check: M.prefs.voice === n, noArrow: true, action: function () { M.prefs.voice = n; var a = g.querySelectorAll('.cell'); for (var i = 0; i < a.length; i++) K.cls(a[i], 'checked', a[i] === c); K.hud('▶ «Привет! Я ' + n + '»', 'none', 1000); } }); });
    }
    if (on('voice.choose_model')) {
      var g2 = K.group(s.body, 'Режим', 'На iPhone 5 разговор идёт по очереди: запись, ответ, озвучивание.');
      ['Обычный', 'Расширенный'].forEach(function (n, i) { var c = K.cell(g2, { title: n, plain: true, check: M.prefs.voiceMode === i, noArrow: true, action: function () { M.prefs.voiceMode = i; var a = g2.querySelectorAll('.cell'); for (var k = 0; k < a.length; k++) K.cls(a[k], 'checked', a[k] === c); } }); });
    }
    if (on('voice.language')) { var g3 = K.group(s.body, 'Язык речи'); ['Определять автоматически', 'Русский', 'English'].forEach(function (n, i) { var c = K.cell(g3, { title: n, plain: true, check: M.prefs.voiceLang === i, noArrow: true, action: function () { M.prefs.voiceLang = i; var a = g3.querySelectorAll('.cell'); for (var k = 0; k < a.length; k++) K.cls(a[k], 'checked', a[k] === c); } }); }); }
    S.modalScreen(s, 'Готово');
  };

  /* ---------- Media pickers (UIImagePickerController look) ---------- */
  S.cameraSim = function (done) {
    var s = K.screen('', { cls: 'scanner' });
    s.el.innerHTML = '<div class="vf" style="top:0;bottom:96px"><div class="docshape" style="left:30px;right:30px;top:60px;bottom:60px;background:-webkit-linear-gradient(top,#9cbfae,#3f6b55)"></div></div><div class="shutter"></div><div class="sbtn l">Отмена</div>';
    var nav = K.present(s.el);
    K.tap(s.el.querySelector('.shutter'), function () { nav.dismiss(); setTimeout(done, 300); }, { instant: true });
    K.tap(s.el.querySelector('.sbtn'), function () { nav.dismiss(); }, { instant: true });
  };
  S.photoPicker = function (done) {
    var s = K.screen('Фотоплёнка', { cls: 'paper' });
    var arts = ['forest', 'sea', 'mountains', 'city', 'robot', 'coffee', 'forest', 'sea', 'mountains'], sel = [];
    var g = K.h('div', 'grid');
    g.style.paddingTop = '4px';
    arts.forEach(function (a, i) {
      var it = K.h('div', 'gi', '<div class="art ' + a + '"></div>');
      it.style.position = 'relative';
      K.tap(it, function () { var k = sel.indexOf(i); if (k >= 0) sel.splice(k, 1); else sel.push(i); it.style.boxShadow = k >= 0 ? '' : '0 0 0 3px #2fae6c'; s.nav.setTitle(s, sel.length ? 'Выбрано: ' + sel.length : 'Фотоплёнка'); }, { instant: true });
      g.appendChild(it);
    });
    s.body.appendChild(g);
    S.modalScreen(s, 'Готово', { cancel: true, onDone: function () { done(sel.map(function (i) { return arts[i]; })); } });
  };
  S.filePicker = function (done) {
    var s = K.screen('Файл');
    var g = K.group(s.body, 'Недавние', 'iOS 6 не даёт доступа к файлам других приложений: используйте «Открыть в…» из Почты или Safari, iTunes File Sharing или подключённый Google Drive.');
    [['Договор аренды.pdf', 'pdf', 820e3], ['Отчёт.docx', 'doc', 210e3], ['Фото чека.jpg', 'image', 1.2e6]].forEach(function (f) {
      K.cell(g, { title: f[0], sub: K.bytes(f[2]), icon: K.tile('file', 'blue', 29), action: function () { s.nav.dismiss(function () { done({ name: f[0], kind: f[1] }); }); } });
    });
    if (on('library.mounted_sources')) { var g2 = K.group(s.body, 'Подключено'); K.cell(g2, { title: 'Google Drive', icon: K.tile('cloud', 'yellow', 29), action: function () { K.hud('Открываю Google Drive', 'none'); } }); }
    S.modalScreen(s, null, { cancel: true });
  };
  S.libraryPicker = function (done) {
    var s = K.screen('Из библиотеки');
    var g = K.group(s.body, 'Файлы', 'Выбранный файл будет приложен к сообщению.');
    M.library.forEach(function (f) { K.cell(g, { title: f.name, sub: K.bytes(f.size), icon: K.tile(f.kind === 'image' ? 'photo' : 'file', f.kind === 'image' ? 'purple' : 'blue', 29), action: function () { s.nav.dismiss(function () { done(f); }); } }); });
    S.modalScreen(s, null, { cancel: true });
  };
  S.recordAudio = function (done) {
    K.alert({ title: 'Запись аудио', message: '<span class="lamp err"></span>Идёт запись · 0:07<br><span style="font-size:13px;opacity:.75">Это вложение-аудио, а не диктовка: ChatGPT получит сам звук.</span>', buttons: [{ title: 'Отмена', cancel: true }, { title: 'Готово', action: done }] });
  };

  /* ---------- Scanner (media.document_scan, page edit, PDF, discard) ---------- */
  S.scanner = function (done) {
    var pages = 0, sel = -1;
    var s = K.h('div', 'scanner');
    var nav = new K.Nav();
    var scr = { title: 'Сканирование', el: s, left: { title: 'Отмена', action: function () { cancel(); } }, right: { title: 'Сохранить', style: 'done', action: function () { save(); } } };
    s.innerHTML = '<div class="vf" style="top:0"><div class="docshape"></div><div class="frame"></div></div><div class="strip"></div><div class="shutter"></div><div class="sbtn l"></div><div class="sbtn r"></div>';
    nav.push(scr, false);
    nav.bar.classList.add('dark');
    var pres = K.present(nav);
    function strip() {
      var st = s.querySelector('.strip'); st.innerHTML = '';
      for (var i = 0; i < pages; i++) (function (i) { var p = K.h('span', 'pg' + (i === sel ? ' sel' : ''), '<b>' + (i + 1) + '</b>'); K.tap(p, function () { sel = i; strip(); pageMenu(i); }, { instant: true }); st.appendChild(p); })(i);
      s.querySelector('.sbtn.l').textContent = pages ? pages + ' стр.' : '';
    }
    function pageMenu(i) {
      if (!on('media.scan_page_edit')) return;
      K.sheet({ title: 'Страница ' + (i + 1), buttons: [{ title: 'Переснять' }, { title: 'Повернуть' }, { title: 'Переместить в начало' }, { title: 'Удалить страницу', red: true, action: function () { pages--; sel = -1; strip(); } }] });
    }
    K.tap(s.querySelector('.shutter'), function () { pages++; strip(); }, { instant: true });
    function cancel() {
      if (pages && on('media.scan_discard')) K.alert({ title: 'Удалить скан?', message: 'Отснятые страницы (' + pages + ') будут потеряны.', buttons: [{ title: 'Остаться', cancel: true }, { title: 'Удалить', red: true, action: function () { pres.dismiss(); } }] });
      else pres.dismiss();
    }
    function save() {
      if (!pages) { K.hud('Снимите хотя бы одну страницу', 'none'); return; }
      var h = K.hud('Собираю PDF…', 'busy');
      setTimeout(function () { h.done('PDF готов'); pres.dismiss(); setTimeout(function () { done(pages); }, 400); }, 1200);
    }
    strip();
  };

  /* ---------- Lightbox: view and edit an image ---------- */
  S.lightbox = function (img) {
    var lb = K.h('div', 'lightbox');
    var nav = new K.Nav();
    var tool = null;
    var scr = { title: '', el: lb, left: { title: 'Готово', action: function () { pres.dismiss(); } }, right: on('images.save_share') ? { icon: K.barGlyph('share'), action: function () { K.sheet({ buttons: [{ title: 'Сохранить в «Фото»', action: function () { K.hud('Сохранено'); } }, { title: 'Отправить по почте' }, { title: 'Скопировать' }] }); } } : null };
    lb.innerHTML = '<div class="cap">' + K.esc(img.prompt || '') + '</div><div class="art ' + img.art + '"><div class="notes"></div></div><div class="hint"></div><div class="toolbar bottom"></div>';
    nav.push(scr, false);
    nav.bar.classList.add('dark');
    var pres = K.present(nav, { fade: true });
    var tb = lb.querySelector('.toolbar'), hint = lb.querySelector('.hint'), notes = lb.querySelector('.notes'), n = 0;
    function tbtn(glyph, fid, label, fn) {
      if (!on(fid)) return;
      var b = K.h('span', 'tb', K.glyph(glyph, 22, '#fff')); b.setAttribute('aria-label', label);
      K.tap(b, function () { var a = tb.querySelectorAll('.tb'); for (var i = 0; i < a.length; i++) a[i].classList.remove('on'); fn(b); }, { instant: true });
      tb.appendChild(b);
    }
    tbtn('edit', 'images.edit_general', 'Изменить запросом', function () { K.alert({ title: 'Что изменить?', field: { placeholder: 'Например: сделай закат' }, buttons: [{ title: 'Отмена', cancel: true }, { title: 'Изменить', action: function () { var h = K.hud('Создаю вариант…', 'busy'); setTimeout(function () { h.done('Готово'); }, 1500); } }] }); });
    tbtn('pin', 'images.edit_precise_notes', 'Примечания', function (b) { b.classList.add('on'); tool = 'note'; hint.textContent = 'Коснитесь места на изображении, чтобы оставить примечание.'; });
    tbtn('eraser', 'images.remove_area', 'Убрать область', function (b) { b.classList.add('on'); tool = 'erase'; hint.textContent = 'Закрасьте пальцем то, что нужно убрать.'; });
    tbtn('expand', 'images.resize', 'Размер', function () { K.sheet({ title: 'Формат', buttons: [{ title: 'Квадрат 1:1', check: true }, { title: 'Портрет 2:3' }, { title: 'Пейзаж 3:2' }] }); });
    tbtn('brush', 'images.sketch', 'Эскиз', function () { S.sketch(); });
    var art = lb.querySelector('.art');
    K.tap(art, function (e, a) {
      if (tool !== 'note') return;
      var r = art.getBoundingClientRect();
      n++; var i = K.h('i', '', n); i.style.left = Math.round((a.x - r.left)) + 'px'; i.style.top = Math.round((a.y - r.top)) + 'px';
      notes.appendChild(i);
      hint.textContent = n + ' примечани' + (n === 1 ? 'е' : 'я') + ' · «Готово» отправит их вместе с запросом';
    }, { instant: true });
  };
  S.sketch = function () {
    var s = K.screen('Эскиз', { cls: 'paper' });
    s.el.innerHTML = '<div style="position:absolute;left:10px;right:10px;top:10px;bottom:54px;background:#fff;border:1px solid #c7d2cc;border-radius:6px"><svg width="100%" height="100%"><path d="M60 300 C 90 200, 160 180, 200 260 S 260 340, 250 220" fill="none" stroke="#2fae6c" stroke-width="5" stroke-linecap="round"/><circle cx="140" cy="140" r="40" fill="none" stroke="#e07a0c" stroke-width="5"/></svg></div>';
    var tb = K.h('div', 'toolbar bottom'); tb.style.textAlign = 'center';
    ['Перо', 'Ластик', 'Цвет', 'Фигуры'].forEach(function (x) { var b = K.bbtn({ title: x }); b.style.margin = '0 3px'; tb.appendChild(b); });
    s.el.appendChild(tb);
    S.modalScreen(s, 'Создать', { cancel: true, onDone: function () { K.hud('Отправлено в чат'); } });
  };

  /* ---------- Shared link opened from Safari/Mail (chat.shared_view, integration.url_routes) ---------- */
  S.sharedLink = function () {
    if (!on('chat.shared_view')) { K.alert({ title: 'Ссылка на разговор', message: 'Эта версия ChatGPT X пока не открывает общие разговоры. Ссылку можно открыть в Safari.', buttons: [{ title: 'OK' }] }); return; }
    var c = { id: 'shared', title: 'Как выбрать велосипед', msgs: [
      { role: 'user', md: 'Какой велосипед выбрать для города?', state: 'done' },
      { role: 'assistant', md: 'Для города подойдёт **гибрид** или **городской велосипед**:\n\n- рама с низкой посадкой — удобно в одежде\n- планетарная втулка — меньше обслуживания\n- крылья и багажник — сразу в комплекте', state: 'done' }] };
    M.chats.push(c);
    var s = S.chatScreen('shared', { readOnly: true });
    M.chats.pop();
    var ft = K.h('div', 'composer', '<div class="button green small" style="margin:0 4px">Продолжить в своём чате</div>');
    s.el.appendChild(ft);
    s.el.querySelector('.scroll').style.bottom = '46px';
    var nav = S.modalScreen(s, 'Закрыть');
    K.tap(ft.firstChild, function () { nav.dismiss(function () { var nc = { id: M.uid(), title: c.title, t: Date.now(), msgs: c.msgs.map(function (m) { return { id: M.uid(), role: m.role, md: m.md, state: 'done' }; }) }; M.chats.unshift(nc); S.openChat(nc.id); }); }, { instant: true });
  };

  /* ---------- Welcome and sign-in through the ChatGPT web page ---------- */
  S.welcome = function () {
    var w = K.h('div', 'welcome linen-dark');
    w.style.zIndex = 55;
    w.innerHTML = '<div class="wl-logo"><img src="img/icon-114.png" alt=""></div><h1>ChatGPT X</h1><div class="wl-btns"><div class="button green">Войти</div>' + (on('account.signup') ? '<div class="button dark">Создать аккаунт</div>' : '') + '</div>' +
      '<div class="wl-foot">Неофициальное приложение. Не связано с OpenAI.</div>';
    K.main().appendChild(w);
    var bs = w.querySelectorAll('.button');
    K.tap(bs[0], function () { S.signIn({ done: finish }); });
    if (bs[1]) K.tap(bs[1], function () { S.signIn({ signup: true, done: finish }); });
    function finish() {
      try { localStorage.removeItem('rc-signedout'); } catch (x) {}
      M.signedIn = true;
      S.front().setRoot(S.chatScreen(null));
      w.style.webkitTransition = 'opacity .4s'; w.style.opacity = 0;
      setTimeout(function () { if (w.parentNode) w.parentNode.removeChild(w); }, 450);
    }
  };
  S.signIn = function (o) {
    var wv = K.h('div', 'webview');
    var nav = new K.Nav();
    var scr = { title: o.signup ? 'Регистрация' : 'Вход', el: wv, left: { title: 'Отмена', action: function () { cancelled(); } } };
    nav.push(scr, false);
    var pres = K.present(nav);
    wv.innerHTML = '<div class="addr">' + K.glyph('lock', 11, '#2f7a55') + 'auth.openai.com</div><div class="wprog" style="width:10%"></div><div class="wpage"></div><div class="web-schematic">схема веб-страницы</div>';
    var page = wv.querySelector('.wpage'), prog = wv.querySelector('.wprog');
    function load(fn, ms) { prog.style.opacity = 1; prog.style.width = '30%'; page.style.opacity = .3; setTimeout(function () { prog.style.width = '100%'; setTimeout(function () { prog.style.opacity = 0; page.style.opacity = 1; fn(); }, 250); }, ms || 700); }
    function step1(err) {
      page.innerHTML = '<div class="wf-title">' + (o.signup ? 'Создайте аккаунт' : (o.reauth ? 'Войдите снова' : 'С возвращением')) + '</div>' + (err ? '<div class="werr">' + err + '</div>' : '') +
        '<input class="wf" type="email" placeholder="Email" value="' + (o.reauth ? M.user.email : '') + '"><div class="wbtn">Продолжить</div><div class="wsep">ИЛИ</div>' +
        '<div class="wbtn alt">Продолжить с Google</div>' + (on('account.login.phone') ? '<div class="wbtn alt">Продолжить по телефону</div>' : '') +
        '<div class="wnote">Это страница сервиса внутри приложения (WebView).<br>После входа вы вернётесь в ChatGPT X.</div>';
      var b = page.querySelectorAll('.wbtn');
      K.tap(b[0], function () { load(step2); });
      K.tap(b[1], function () { load(function () { page.innerHTML = '<div class="wf-title">Google</div><div class="wnote" style="margin-top:0">Выбор аккаунта Google…</div>'; setTimeout(function () { load(stepMfa); }, 900); }); });
      if (b[2]) K.tap(b[2], function () { load(function () { page.innerHTML = '<div class="wf-title">Телефон</div><input class="wf" placeholder="+7 900 000-00-00"><div class="wbtn">Получить код</div>'; K.tap(page.querySelector('.wbtn'), function () { load(stepMfa); }); }); });
    }
    function step2() {
      page.innerHTML = '<div class="wf-title">Введите пароль</div><input class="wf" type="password" value="••••••••••"><div class="wbtn">Продолжить</div>' + (on('account.login.email_code') ? '<div class="wbtn alt">Войти по коду из письма</div>' : '') + (on('account.login.password_reset') ? '<div class="wnote">Забыли пароль?</div>' : '');
      var b = page.querySelectorAll('.wbtn');
      K.tap(b[0], function () { load(stepMfa); });
      if (b[1]) K.tap(b[1], function () { load(stepMfa); });
    }
    function stepMfa() {
      page.innerHTML = '<div class="wf-title">Код подтверждения</div><div class="wnote" style="margin:-8px 0 12px">Откройте приложение-аутентификатор</div><div class="code6"><span>4</span><span>8</span><span>1</span><span>9</span><span>0</span><span>2</span></div><div class="wbtn">Подтвердить</div>' + (on('account.mfa.recovery_code') ? '<div class="wbtn alt">Использовать резервный код</div>' : '') + (on('account.mfa.push_approval') ? '<div class="wbtn alt">Через другое устройство</div>' : '');
      K.tap(page.querySelector('.wbtn'), function () { load(success, 900); });
    }
    function success() {
      page.innerHTML = '<div style="text-align:center;padding-top:80px"><span class="spinner large">' + K.spinnerSVG('#555') + '</span><div class="wnote">Проверяю аккаунт и сохраняю сессию в Связке ключей…</div></div>';
      setTimeout(function () { pres.dismiss(function () { K.hud('Вы вошли'); if (o.done) o.done(); }); }, 1200);
    }
    function cancelled() {
      pres.dismiss(function () {
        if (!on('account.login.cancel_retry')) return;
        K.alert({ title: 'Вход прерван', message: 'Ничего не изменено. Можно начать заново — с того же шага.', buttons: [{ title: 'Позже', cancel: true }, { title: 'Ещё раз', action: function () { S.signIn(o); } }] });
      });
    }
    load(function () { step1(); }, 900);
  };

  /* ---------- Locked chats ---------- */
  S.pinPad = function (opts) {
    var p = K.h('div', 'pin linen-dark');
    var entered = '', fails = 0;
    p.innerHTML = '<div class="ptitle">' + K.esc(opts.title) + '</div><div class="pboxes"><span></span><span></span><span></span><span></span></div><div class="pmsg">' + (opts.msg || '') + '</div><div class="keypad"></div>';
    var kp = p.querySelector('.keypad');
    var keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    keys.forEach(function (k, i) {
      var b = K.h('div', 'k' + (k ? '' : ' blank'), k);
      b.style.left = (i % 3) * 33.33 + '%'; b.style.top = Math.floor(i / 3) * 54 + 'px';
      if (k) K.tap(b, function () { press(k); }, { instant: true });
      kp.appendChild(b);
    });
    function draw() { var bx = p.querySelectorAll('.pboxes span'); for (var i = 0; i < 4; i++) bx[i].textContent = i < entered.length ? '●' : ''; }
    function press(k) {
      if (p._locked) return;
      if (k === '⌫') { entered = entered.slice(0, -1); draw(); return; }
      entered += k; draw();
      if (entered.length === 4) setTimeout(function () {
        if (opts.check(entered)) { opts.ok(); return; }
        fails++;
        p.classList.add('shake'); setTimeout(function () { p.classList.remove('shake'); }, 450);
        entered = ''; draw();
        var m = p.querySelector('.pmsg');
        m.className = 'pmsg err';
        if (fails >= 3 && on('privacy.locked_retry_limits')) { p._locked = true; var left = 30; m.textContent = 'Слишком много попыток. Повторите через ' + left + ' с'; var iv = setInterval(function () { left--; m.textContent = 'Слишком много попыток. Повторите через ' + left + ' с'; if (!left) { clearInterval(iv); p._locked = false; m.textContent = ''; } }, 1000); }
        else m.textContent = 'Неверный PIN. Подсказка в прототипе: 1234';
      }, 150);
    }
    return p;
  };
  S.lockChat = function (c, done) {
    K.alert({ title: 'Закрыть чат PIN-кодом?', message: 'Чат пропадёт из списка и поиска. Пока он закрыт, из него не пополняется память.', buttons: [{ title: 'Отмена', cancel: true }, { title: 'Закрыть', action: function () { c.locked = true; c.pinned = false; K.hud('Чат закрыт'); done(); } }] });
  };

  /* ---------- Prototype controls (also reachable by triple-tapping the status bar) ---------- */
  S.prototypeScreen = function (modal) {
    var s = K.screen('Прототип');
    s.body.appendChild(K.h('div', 'group-head', 'Этап реализации'));
    var w = K.h('div', 'seg-wrap'); w.style.marginTop = '0';
    w.appendChild(K.seg(M.STAGES.map(function (x) { return x === 10 ? '10' : '≥' + x; }), M.STAGES.indexOf(M.stage), function (i) { S.setStage(M.STAGES[i]); }, true));
    s.body.appendChild(w);
    var cnt = window.FEATURES.included.filter(function (f) { return f.u >= M.stage; }).length;
    s.body.appendChild(K.h('div', 'group-foot', 'Функции с пользой ' + M.stage + '/10 и выше: ' + cnt + ' из ' + window.FEATURES.included.length + '.'));
    if (window.C) {
      s.body.appendChild(K.h('div', 'group-head', 'Codex'));
      var cw = K.h('div', 'seg-wrap'); cw.style.marginTop = '0';
      cw.appendChild(K.seg(['Выкл.', '9–10', '≥8', 'Все'], C.tier, function (i) { C.setTier(i); }, true));
      s.body.appendChild(cw);
      s.body.appendChild(K.h('div', 'group-foot', 'Функций Codex на уровне: ' + window.CODEX_FEATURES.list.filter(function (f) { return f.tier <= C.tier; }).length * (C.tier ? 1 : 0) + ' из 38.'));
    }
    var sc = K.group(s.body, 'Сценарии');
    [['offline', 'Нет сети'], ['slowPrep', 'Долгая подготовка отправки'], ['uncertain', 'Отправка не подтвердится'], ['cutoff', 'Ответ оборвётся'], ['renewFail', 'Сессия не обновится при запуске'], ['uploadLimit', 'Лимит загрузок'], ['dictationFail', 'Сбой распознавания'], ['voiceNet', 'Плохая связь в голосе'], ['codexDrop', 'Codex: обрыв связи в задаче']].forEach(function (x) {
      var c = K.cell(sc, { title: x[1], cls: 'has-switch' }); c.querySelector('.t').classList.add('plain');
      c.appendChild(K.toggle(M.scenario[x[0]], function (v) { M.setScenario(x[0], v); }));
    });
    var a = K.group(s.body, 'Действия');
    K.cell(a, { title: 'Открыть ссылку на общий чат', action: function () { if (s.nav.dismiss) s.nav.dismiss(function () { S.sharedLink(); }); else S.sharedLink(); } });
    if (window.C) K.cell(a, { title: 'Codex: пройти проверку iPhone заново', action: function () { try { localStorage.removeItem('rc-cx-verified'); } catch (e) {} location.replace(location.pathname + '?stage=' + M.stage + '&open=codex'); } });
    K.cell(a, { title: 'Перезапустить приложение', action: function () { location.reload(); } });
    K.cell(a, { title: M.signedIn ? 'Начать с экрана входа' : 'Войти сразу', action: function () { S.command(M.signedIn ? 'signout' : 'signin'); } });
    if (modal) return S.modalScreen(s, 'Готово');
    return s;
  };
})();
