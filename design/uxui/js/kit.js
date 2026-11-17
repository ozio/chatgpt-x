/* ChatGPT X UI kit runtime — ES5 only (MobileSafari 6). */
(function () {
  'use strict';
  var K = window.K = {};
  K.touch = 'ontouchstart' in window;
  K.pad = false;

  /* ---------- DOM helpers ---------- */
  K.h = function (tag, cls, html) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (html != null) e.innerHTML = html;
    return e;
  };
  K.frag = function (html) { var d = document.createElement('div'); d.innerHTML = html; return d.firstChild; };
  K.esc = function (s) {
    return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  };
  K.cls = function (el, c, on) { if (on) el.classList.add(c); else el.classList.remove(c); };
  K.later = function (ms, fn) { return setTimeout(fn, ms); };
  K.raf = window.requestAnimationFrame || window.webkitRequestAnimationFrame || function (f) { return setTimeout(f, 16); };
  K.reflow = function (el) { return el.offsetWidth; };
  K.inDoc = function (el) { return document.documentElement.contains(el); };
  K.closest = function (el, cls) { while (el && el !== document) { if (el.classList && el.classList.contains(cls)) return el; el = el.parentNode; } return null; };

  K.bytes = function (b) {
    if (b >= 1e9) return (b / 1e9).toFixed(2).replace('.', ',') + ' ГБ';
    if (b >= 1e6) return (b / 1e6).toFixed(1).replace('.', ',') + ' МБ';
    if (b >= 1e3) return Math.round(b / 1e3) + ' КБ';
    return b + ' Б';
  };
  K.ago = function (t) {
    var s = Math.max(0, Math.round((Date.now() - t) / 1000));
    if (s < 10) return 'только что';
    if (s < 60) return s + ' с назад';
    var m = Math.round(s / 60);
    if (m < 60) return m + ' мин назад';
    var h = Math.round(m / 60);
    if (h < 24) return h + ' ч назад';
    return Math.round(h / 24) + ' дн. назад';
  };
  K.clock = function (t) {
    var d = new Date(t), h = d.getHours(), m = d.getMinutes();
    return h + ':' + (m < 10 ? '0' : '') + m;
  };

  /* ---------- Tap engine: immediate response, scroll-aware, no 300 ms delay ---------- */
  var active = null, lastTouch = 0;
  function findTap(t) {
    while (t && t !== document) { if (t._tap || t._hold) return t; t = t.parentNode; }
    return null;
  }
  function isField(t) { return t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.tagName === 'SELECT'); }
  function down(x, y, target) {
    if (isField(target)) return;
    var el = findTap(target);
    if (!el || el._disabled) return;
    // a swiped cell: any tap elsewhere closes the delete button
    if (K._swiped && K._swiped !== el && !K.closest(target, 'delete-btn')) { K.unswipe(); }
    active = { el: el, x: x, y: y, dx: 0, dy: 0, moved: false };
    if (el._instant) el.classList.add('pressed');
    else active.timer = setTimeout(function () { if (active && active.el === el && !active.moved) el.classList.add('pressed'); }, 75);
    if (el._hold) {
      active.hold = setTimeout(function () {
        if (!active || active.el !== el || active.moved) return;
        var pt = { x: active.x, y: active.y }; clearTimeout(active.timer); active = null; el.classList.remove('pressed'); el._hold(el, pt);
      }, 480);
    }
  }
  function move(x, y) {
    if (!active) return;
    var a = active;
    a.dx = x - a.x; a.dy = y - a.y;
    if (a.el._swipe && a.dx < -28 && Math.abs(a.dy) < 18) {
      clearTimeout(a.timer); clearTimeout(a.hold); a.el.classList.remove('pressed'); active = null; a.el._swipe(a.el); return;
    }
    if (a.el._drag) a.el._drag(a.dx, a.dy);
    if (!a.el._allowMove && (Math.abs(a.dx) > 8 || Math.abs(a.dy) > 8)) {
      a.moved = true; clearTimeout(a.timer); clearTimeout(a.hold); a.el.classList.remove('pressed'); active = null;
    }
  }
  function up(e) {
    if (!active) return;
    var a = active; active = null;
    clearTimeout(a.timer); clearTimeout(a.hold);
    if (!a.el._tap) return;
    if (e && e.cancelable) e.preventDefault();
    a.el.classList.add('pressed');
    var keep = a.el._keep;
    setTimeout(function () {
      if (keep) a.el.classList.add('selected');
      a.el.classList.remove('pressed');
    }, keep ? 40 : 110);
    a.el._tap(a.el, a);
  }
  function cancel() { if (active) { clearTimeout(active.timer); clearTimeout(active.hold); active.el.classList.remove('pressed'); active = null; } }

  document.addEventListener('touchstart', function (e) { lastTouch = Date.now(); var t = e.touches[0]; down(t.clientX, t.clientY, e.target); }, false);
  document.addEventListener('touchmove', function (e) { var t = e.touches[0]; move(t.clientX, t.clientY); }, false);
  document.addEventListener('touchend', function (e) { lastTouch = Date.now(); up(e); }, false);
  document.addEventListener('touchcancel', cancel, false);
  var mouseIsDown = false;
  document.addEventListener('mousedown', function (e) { if (Date.now() - lastTouch < 800) return; mouseIsDown = true; down(e.clientX, e.clientY, e.target); }, false);
  document.addEventListener('mousemove', function (e) { if (mouseIsDown) move(e.clientX, e.clientY); }, false);
  document.addEventListener('mouseup', function (e) { if (!mouseIsDown) return; mouseIsDown = false; up(e); }, false);

  K.tap = function (el, fn, opts) {
    el._tap = fn;
    el.classList.add('tappable');
    if (opts) {
      if (opts.keep) el._keep = true;
      if (opts.instant) el._instant = true;
      if (opts.move) el._allowMove = true;
    }
    return el;
  };
  /* long press (UILongPressGestureRecognizer, ~0.5 s) */
  K.hold = function (el, fn) { el._hold = fn; el.classList.add('tappable'); return el; };
  K.disable = function (el, off) { el._disabled = !!off; K.cls(el, 'disabled', !!off); };

  /* swipe-to-delete on a cell */
  K.swipeDelete = function (cell, label, onDelete) {
    var btn = K.h('div', 'delete-btn', K.esc(label || 'Удалить'));
    cell.appendChild(btn);
    cell._swipe = function () { K.unswipe(); cell.classList.add('swiped'); K._swiped = cell; };
    K.tap(btn, function () { K.unswipe(); onDelete(cell); }, { instant: true });
  };
  K.unswipe = function () { if (K._swiped) { K._swiped.classList.remove('swiped'); K._swiped = null; } };
  K.collapse = function (el, done) {
    el.style.height = el.offsetHeight + 'px';
    el.classList.add('collapsing');
    K.reflow(el);
    el.style.height = '0px'; el.style.paddingTop = '0px'; el.style.paddingBottom = '0px'; el.style.opacity = '0'; el.style.borderTopWidth = '0';
    setTimeout(function () { if (el.parentNode) el.parentNode.removeChild(el); if (done) done(); }, 320);
  };

  /* ---------- SVG helpers ---------- */
  K.spinnerSVG = function (color) {
    color = color || '#6b5d50';
    var s = '<svg viewBox="0 0 40 40">';
    for (var i = 0; i < 12; i++) {
      s += '<rect x="18" y="3" width="4" height="10" rx="2" fill="' + color + '" opacity="' + (0.15 + 0.85 * ((12 - i) % 12) / 12).toFixed(2) + '" transform="rotate(' + (i * -30) + ' 20 20)"/>';
    }
    return s + '</svg>';
  };
  K.spinner = function (cls, color) { return K.h('span', 'spinner ' + (cls || ''), K.spinnerSVG(color)); };
  K.checkSVG = '<svg viewBox="0 0 60 60" width="60" height="60"><path d="M10 31 L24 45 L50 15" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/></svg>';
  K.chev = function () { return '<span class="chev"></span>'; };

  /* ---------- Bar buttons ---------- */
  K.bbtn = function (spec) {
    var cls = 'bbtn' + (spec.style ? ' ' + spec.style : '') + (spec.icon ? ' icon' : '') + (spec.back ? ' back' : '');
    var b = K.h('div', cls, spec.icon ? spec.icon : '<span>' + K.esc(spec.title) + '</span>');
    K.tap(b, function () { if (spec.action) spec.action(b); }, { instant: true });
    if (spec.disabled) K.disable(b, true);
    return b;
  };

  /* ---------- Navigation controller ---------- */
  var DUR = 350, EASE = 'cubic-bezier(.42,0,.58,1)';
  function Nav(opts) {
    opts = opts || {};
    this.el = K.h('div', 'nav');
    this.bar = K.h('div', 'navbar');
    this.pages = K.h('div', 'pages');
    this.el.appendChild(this.bar);
    this.el.appendChild(this.pages);
    if (opts.bottom != null) this.el.style.bottom = opts.bottom + 'px';
    this.stack = [];
    this.busy = false;
    this.el._nav = this;
  }
  K.Nav = Nav;
  Nav.prototype.top = function () { return this.stack[this.stack.length - 1]; };
  Nav.prototype.makeLayer = function (s, idx) {
    var self = this;
    var layer = K.h('div', 'nb-layer');
    var l = K.h('div', 'nb-left'), t = K.h('div', 'nb-title', K.esc(s.title || '')), r = K.h('div', 'nb-right');
    if (s.left) l.appendChild(K.bbtn(s.left));
    else if (idx > 0 && !s.noBack) {
      var prev = this.stack[idx - 1];
      var bt = prev.backTitle || prev.title || 'Назад';
      if (bt.length > 11) bt = 'Назад';
      l.appendChild(K.bbtn({ title: bt, back: true, action: function () { self.pop(); } }));
    }
    if (s.right) r.appendChild(K.bbtn(s.right));
    if (s.titleView) { t.innerHTML = ''; t.className += ' tv'; t.appendChild(s.titleView); }
    layer.appendChild(l); layer.appendChild(t); layer.appendChild(r);
    s.titleEl = t;
    return layer;
  };
  Nav.prototype.refreshBar = function (s) {
    var idx = this.stack.indexOf(s);
    if (idx < 0) return;
    var nl = this.makeLayer(s, idx);
    if (s.layer && s.layer.parentNode) { nl.style.cssText = s.layer.style.cssText; this.bar.replaceChild(nl, s.layer); }
    s.layer = nl;
  };
  Nav.prototype.setTitle = function (s, title) { s.title = title; if (s.titleEl) s.titleEl.textContent = title; };
  function tf(el, x, op, anim) {
    el.style.webkitTransition = anim ? '-webkit-transform ' + DUR + 'ms ' + EASE + ', opacity ' + DUR + 'ms ' + EASE : 'none';
    el.style.webkitTransform = 'translate3d(' + x + ',0,0)';
    if (op != null) el.style.opacity = op;
  }
  Nav.prototype.push = function (s, anim) {
    if (this.busy) return;
    var self = this, prev = this.top();
    s.nav = this;
    var page = K.h('div', 'page');
    page.appendChild(s.el);
    s.page = page;
    s.layer = this.makeLayer(s, this.stack.length);
    this.stack.push(s);
    this.pages.appendChild(page);
    this.bar.appendChild(s.layer);
    if (!prev || anim === false) {
      if (prev) { prev.page.style.visibility = 'hidden'; prev.layer.style.visibility = 'hidden'; if (prev.onHide) prev.onHide(); }
      if (s.onShow) s.onShow();
      return s;
    }
    this.busy = true;
    if (prev.onHide) prev.onHide();
    page.classList.add('shadowed');
    tf(page, '100%'); tf(s.layer, '45%', 0);
    K.reflow(page);
    tf(page, '0', null, true); tf(s.layer, '0', 1, true);
    tf(prev.page, '-100%', null, true); tf(prev.layer, '-45%', 0, true);
    setTimeout(function () {
      page.classList.remove('shadowed');
      prev.page.style.visibility = 'hidden'; prev.layer.style.visibility = 'hidden';
      self.busy = false;
      if (s.onShow) s.onShow();
    }, DUR + 20);
    return s;
  };
  Nav.prototype.pop = function (anim) {
    if (this.busy || this.stack.length < 2) return;
    var self = this, s = this.stack.pop(), prev = this.top();
    prev.page.style.visibility = ''; prev.layer.style.visibility = '';
    if (s.onHide) s.onHide();
    var finish = function () {
      if (s.page.parentNode) self.pages.removeChild(s.page);
      if (s.layer.parentNode) self.bar.removeChild(s.layer);
      if (s.destroy) s.destroy();
      self.busy = false;
      if (prev.onReturn) prev.onReturn();
      if (prev.onShow) prev.onShow();
      K.deselect(prev.el);
    };
    if (anim === false) { tf(prev.page, '0'); tf(prev.layer, '0', 1); finish(); return; }
    this.busy = true;
    s.page.classList.add('shadowed');
    tf(prev.page, '-100%'); tf(prev.layer, '-45%', 0);
    K.reflow(prev.page);
    tf(prev.page, '0', null, true); tf(prev.layer, '0', 1, true);
    tf(s.page, '100%', null, true); tf(s.layer, '45%', 0, true);
    setTimeout(finish, DUR + 20);
  };
  Nav.prototype.popToRoot = function (anim) {
    while (this.stack.length > 2) {
      var s = this.stack.splice(this.stack.length - 2, 1)[0];
      if (s.page.parentNode) this.pages.removeChild(s.page);
      if (s.layer.parentNode) this.bar.removeChild(s.layer);
      if (s.destroy) s.destroy();
    }
    if (this.stack.length === 2) { this.refreshBar(this.top()); this.pop(anim); }
  };
  Nav.prototype.setRoot = function (s) {
    while (this.stack.length) {
      var o = this.stack.pop();
      if (o.page.parentNode) this.pages.removeChild(o.page);
      if (o.layer.parentNode) this.bar.removeChild(o.layer);
      if (o.onHide) o.onHide();
      if (o.destroy) o.destroy();
    }
    this.busy = false;
    return this.push(s, false);
  };
  /* Replace the top screen without a back step (used inside multi-step forms). */
  Nav.prototype.replace = function (s) {
    if (this.busy) return;
    var self = this, old = this.stack.pop();
    s.nav = this;
    var page = K.h('div', 'page'); page.appendChild(s.el); s.page = page;
    s.layer = this.makeLayer(s, this.stack.length);
    this.stack.push(s);
    this.pages.appendChild(page); this.bar.appendChild(s.layer);
    this.busy = true;
    tf(page, '100%'); tf(s.layer, '45%', 0); K.reflow(page);
    tf(page, '0', null, true); tf(s.layer, '0', 1, true);
    tf(old.page, '-100%', null, true); tf(old.layer, '-45%', 0, true);
    if (old.onHide) old.onHide();
    setTimeout(function () {
      if (old.page.parentNode) self.pages.removeChild(old.page);
      if (old.layer.parentNode) self.bar.removeChild(old.layer);
      if (old.destroy) old.destroy();
      self.busy = false;
      if (s.onShow) s.onShow();
    }, DUR + 20);
  };

  /* Selected rows fade back after returning (UITableView deselect-on-appear). */
  K.deselect = function (root) {
    var sel = root.querySelectorAll('.cell.selected');
    for (var i = 0; i < sel.length; i++) {
      if (sel[i]._sticky) continue;
      sel[i].classList.remove('selected');
    }
  };

  /* Generic screen with a scrolling grouped-table body. */
  K.screen = function (title, opts) {
    opts = opts || {};
    var s = { title: title, backTitle: opts.backTitle, left: opts.left, right: opts.right, subs: [] };
    s.el = K.h('div', 'screen ' + (opts.cls || 'linen'));
    s.el.style.position = 'absolute'; s.el.style.left = s.el.style.top = s.el.style.right = s.el.style.bottom = '0';
    if (opts.toolbar) s.el.appendChild(opts.toolbar);
    s.scroll = K.h('div', 'scroll');
    s.body = K.h('div', 'inner');
    s.scroll.appendChild(s.body);
    s.el.appendChild(s.scroll);
    return s;
  };

  /* ---------- Grouped table building ---------- */
  K.group = function (parent, head, foot, headRight) {
    if (head) parent.appendChild(K.h('div', 'group-head', K.esc(head) + (headRight ? '<small>' + headRight + '</small>' : '')));
    var g = K.h('div', 'group' + (head ? ' has-head' : ''));
    if (head) g.style.marginTop = '0';
    var cells = K.h('div', 'cells');
    g.appendChild(cells);
    parent.appendChild(g);
    if (foot) parent.appendChild(K.h('div', 'group-foot', foot));
    return cells;
  };
  K.cell = function (parent, o) {
    var c = K.h('div', 'cell' + (o.cls ? ' ' + o.cls : '') + (o.icon ? ' with-icon' : '') + (o.action && !o.noArrow ? ' arrow' : '') + (o.noArrow ? ' noarrow' : ''));
    var html = '';
    if (o.icon) html += '<span class="cicon">' + o.icon + '</span>';
    html += '<div class="t' + (o.plain ? ' plain' : '') + '">' + (o.titleHTML || K.esc(o.title)) + '</div>';
    if (o.sub) html += '<div class="s">' + o.sub + '</div>';
    if (o.value != null) html += '<div class="v">' + o.value + '</div>';
    if (o.action && !o.noArrow) html += K.chev();
    if (o.check != null) html += '<span class="check"></span>';
    c.innerHTML = html;
    if (o.check) c.classList.add('checked');
    if (o.action) K.tap(c, o.action, { keep: !o.noKeep && !o.noArrow });
    if (o.value != null && o.action == null) c.classList.add('noarrow');
    parent.appendChild(c);
    return c;
  };

  /* ---------- Switch ---------- */
  K.toggle = function (on, onChange) {
    var el = K.h('div', 'switch' + (on ? ' on' : ''), '<div class="track"><div class="on-side">ON</div><div class="off-side">OFF</div><div class="knob"></div></div>');
    el.value = !!on;
    el.set = function (v) { el.value = !!v; K.cls(el, 'on', el.value); };
    K.tap(el, function (e, a) {
      var nv = !el.value;
      if (a && Math.abs(a.dx) > 10) nv = a.dx > 0;
      if (nv === el.value) return;
      el.set(nv);
      if (onChange) setTimeout(function () { onChange(nv, el); }, 180);
    }, { instant: true, move: true });
    return el;
  };

  /* ---------- Segmented control ---------- */
  K.seg = function (items, sel, fn, light) {
    var el = K.h('div', 'seg' + (light ? ' light' : ''));
    el.value = sel;
    items.forEach(function (label, i) {
      var d = K.h('div', i === sel ? 'sel' : '', K.esc(label));
      K.tap(d, function () {
        if (el.value === i) return;
        el.set(i);
        fn(i);
      }, { instant: true });
      el.appendChild(d);
    });
    el.set = function (i) {
      el.value = i;
      for (var k = 0; k < el.childNodes.length; k++) K.cls(el.childNodes[k], 'sel', k === i);
    };
    return el;
  };

  /* ---------- Progress ---------- */
  K.progress = function (cls) {
    var el = K.h('div', 'progress ' + (cls || ''), '<i></i>');
    el.set = function (f) { el.firstChild.style.width = Math.max(0, Math.min(1, f)) * 100 + '%'; };
    el.indet = function (b) { K.cls(el, 'indet', b); };
    return el;
  };

  /* ---------- Overlay layer ---------- */
  K.overlay = function () { return document.getElementById('overlay'); };
  K.main = function () { return document.getElementById('main'); };

  var alertQueue = [], alertOpen = false;
  /* opts: title, message, list:[{icon,title,sub}], field:{placeholder}, buttons:[{title, cancel, red, action}] */
  K.alert = function (opts) {
    if (alertOpen) { alertQueue.push(opts); return; }
    alertOpen = true;
    var ov = K.overlay();
    var dim = K.h('div', 'dim');
    var a = K.h('div', 'alert');
    var html = '';
    if (opts.title) html += '<div class="a-title">' + K.esc(opts.title) + '</div>';
    if (opts.message) html += '<div class="a-msg">' + opts.message + '</div>';
    a.innerHTML = html;
    if (opts.list && opts.list.length) {
      var list = K.h('div', 'a-list');
      opts.list.forEach(function (it) {
        list.appendChild(K.h('div', 'ai', (it.k ? '<b>' + K.esc(it.k) + '</b>' : '') + K.esc(it.v)));
      });
      a.appendChild(list);
    }
    var field = null;
    if (opts.field) {
      field = K.h('input', 'a-field');
      field.placeholder = opts.field.placeholder || '';
      if (opts.field.value) field.value = opts.field.value;
      a.appendChild(field);
    }
    if (opts.note) a.appendChild(K.h('div', 'a-msg a-note', opts.note));
    var btns = opts.buttons || [{ title: 'OK' }];
    var two = btns.length === 2 && btns[0].title.length <= 12 && btns[1].title.length <= 12;
    var row = K.h('div', 'a-btns ' + (two ? 'two' : 'stack'));
    btns.forEach(function (b) {
      var be = K.h('div', 'a-btn' + (b.cancel ? ' cancel' : '') + (b.red ? ' red' : ''), K.esc(b.title));
      K.tap(be, function () {
        close();
        if (b.action) setTimeout(function () { b.action(field ? field.value : undefined); }, 60);
      }, { instant: true });
      row.appendChild(be);
    });
    a.appendChild(row);
    ov.appendChild(dim); ov.appendChild(a);
    // centre vertically using measured height (no flexbox on iOS 6)
    a.style.marginTop = -Math.round(a.offsetHeight / 2) - (field ? 60 : 0) + 'px';
    K.reflow(a);
    dim.classList.add('show'); a.classList.add('show');
    if (field) setTimeout(function () { field.focus(); }, 300);
    function close() {
      a.classList.add('hide'); dim.classList.remove('show');
      setTimeout(function () {
        if (a.parentNode) ov.removeChild(a);
        if (dim.parentNode) ov.removeChild(dim);
        alertOpen = false;
        if (alertQueue.length) K.alert(alertQueue.shift());
      }, 220);
    }
    return { close: close, el: a };
  };

  /* Action sheet; on iPad with an anchor it becomes a popover. */
  K.sheet = function (opts) {
        var ov = K.overlay();
    var dim = K.h('div', 'dim plain');
    var sh = K.h('div', 'sheet');
    if (opts.title) sh.appendChild(K.h('div', 's-title', opts.title));
    function close(cb) {
      sh.classList.remove('show'); dim.classList.remove('show');
      setTimeout(function () { if (sh.parentNode) ov.removeChild(sh); if (dim.parentNode) ov.removeChild(dim); if (cb) cb(); }, 330);
    }
    (opts.buttons || []).forEach(function (b) {
      var be = K.h('div', 's-btn' + (b.red ? ' red' : ''), (b.check ? '<span class="ck">✓</span>' : '') + K.esc(b.title));
      K.tap(be, function () { close(); if (b.action) setTimeout(b.action, 120); }, { instant: true });
      sh.appendChild(be);
    });
    var cancel = K.h('div', 's-btn cancel', K.esc(opts.cancel || 'Отмена'));
    K.tap(cancel, function () { close(opts.onCancel); }, { instant: true });
    sh.appendChild(cancel);
    K.tap(dim, function () { close(opts.onCancel); });
    ov.appendChild(dim); ov.appendChild(sh);
    K.reflow(sh);
    dim.classList.add('show'); sh.classList.add('show');
    return { close: close };
  };

  /* Edit menu (UIMenuController): black callout above (or below) an element. */
  K.callout = function (anchor, items, point) {
    var ov = K.overlay();
    var catcher = K.h('div', 'dim clear');
    var c = K.h('div', 'callout');
    items.forEach(function (it) {
      var b = K.h('span', 'ci', K.esc(it.title));
      K.tap(b, function () { close(); if (it.action) setTimeout(it.action, 60); }, { instant: true });
      c.appendChild(b);
    });
    var tip = K.h('span', 'tip');
    c.appendChild(tip);
    ov.appendChild(catcher); ov.appendChild(c);
    var r = anchor.getBoundingClientRect(), o = ov.getBoundingClientRect();
    var W = ov.offsetWidth, w = c.offsetWidth;
    var cx = point ? point.x - o.left : r.left - o.left + r.width / 2;
    var left = Math.max(6, Math.min(W - w - 6, cx - w / 2));
    var ay = point ? point.y - o.top - 22 : r.top - o.top;
    var by = point ? point.y - o.top + 22 : r.bottom - o.top;
    var top = ay - 48, up = false;
    if (top < 70) { top = Math.min(by + 10, ov.offsetHeight - 120); up = true; }
    c.style.left = left + 'px'; c.style.top = top + 'px';
    tip.className = 'tip ' + (up ? 'up' : 'down');
    tip.style.left = Math.max(14, Math.min(w - 14, cx - left)) + 'px';
    K.reflow(c); c.classList.add('show');
    function close() { c.classList.remove('show'); setTimeout(function () { if (c.parentNode) ov.removeChild(c); if (catcher.parentNode) ov.removeChild(catcher); }, 160); }
    K.tap(catcher, close, { instant: true });
    return { close: close };
  };

  /* Activity grid (UIActivityViewController look): items {icon, title, on, action}. */
  K.actGrid = function (opts) {
    var ov = K.overlay();
    var dim = K.h('div', 'dim plain');
    var g = K.h('div', 'actgrid');
    if (opts.title) g.appendChild(K.h('div', 'ag-title', K.esc(opts.title)));
    function close(cb) { g.classList.remove('show'); dim.classList.remove('show'); setTimeout(function () { if (g.parentNode) ov.removeChild(g); if (dim.parentNode) ov.removeChild(dim); if (cb) cb(); }, 330); }
    opts.items.forEach(function (it) {
      var e = K.h('div', 'ag-item' + (it.on ? ' on' : ''), it.icon + '<div>' + K.esc(it.title) + '</div>');
      K.tap(e, function () { close(); if (it.action) setTimeout(it.action, 200); }, { instant: true });
      g.appendChild(e);
    });
    var cancel = K.h('div', 's-btn cancel', 'Отмена');
    K.tap(cancel, function () { close(); }, { instant: true });
    g.appendChild(K.h('div', 'sheet-in'));
    g.lastChild.appendChild(cancel);
    g.lastChild.className = 'sheet';
    g.lastChild.style.cssText = 'position:static;background:none;border:0;box-shadow:none;padding:0;-webkit-transform:none';
    K.tap(dim, function () { close(); });
    ov.appendChild(dim); ov.appendChild(g);
    K.reflow(g); dim.classList.add('show'); g.classList.add('show');
    return { close: close };
  };

  /* HUD: transient confirmation, or a busy HUD that later resolves. */
  K.hud = function (text, kind, ms) {
    var ov = K.overlay();
    var hd = K.h('div', 'hud');
    var ic = K.h('div', 'hud-ic', kind === 'busy' ? '<span class="spinner large" style="margin-top:12px">' + K.spinnerSVG('#fff') + '</span>' : (kind === 'none' ? '' : K.checkSVG));
    var tx = K.h('div', '', K.esc(text));
    hd.appendChild(ic); hd.appendChild(tx);
    ov.appendChild(hd);
    K.reflow(hd);
    hd.classList.add('show');
    function hide() { hd.classList.remove('show'); setTimeout(function () { if (hd.parentNode) ov.removeChild(hd); }, 220); }
    if (kind !== 'busy') setTimeout(hide, ms || 1100);
    return {
      done: function (t2) { ic.innerHTML = K.checkSVG; tx.textContent = t2 || text; setTimeout(hide, 900); },
      hide: hide
    };
  };

  /* Modal presentation: full-screen slide-up (or fade) on iPhone. */
  K.present = function (nav, opts) {
    opts = opts || {};
    var main = K.main();
    var box = K.h('div', 'modal' + (opts.fade ? ' fade' : ''));
    box.appendChild(nav.el || nav);
    main.appendChild(box);
    K.reflow(box);
    box.classList.add('show');
    var target = nav.el ? nav : { el: nav };
    target.dismiss = function (cb) {
      box.classList.remove('show');
      setTimeout(function () {
        if (box.parentNode) main.removeChild(box);
        if (target.stack) target.stack.forEach(function (s) { if (s.destroy) s.destroy(); });
        if (opts.onDismiss) opts.onDismiss();
        if (cb) cb();
      }, 420);
    };
    return target;
  };
})();
