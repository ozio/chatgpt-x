(function (nonce) {
  'use strict';
  function own() {
    return window === window.top && location.protocol === 'https:' &&
      location.hostname === 'chatgpt.com' && (!location.port || location.port === '443');
  }
  if (!own() || typeof nonce !== 'string' || !/^[a-f0-9]{32}$/.test(nonce)) return 'refused';
  if (window.__OR6ChatBridge) {
    return typeof window.__OR6ChatBridge.resume === 'function' ? window.__OR6ChatBridge.resume(nonce) : 'already_installed';
  }
  var original = window.fetch, wrapper, reader = null, active = true, cfg = null;
  var queue = [], queued = 0, bytes = 0, typed = false, sent = false;
  var bridgeBegan = typeof performance !== 'undefined' && performance.now ? performance.now() : 0;
  var state = {nonce: nonce, phase: 'idle', issue: '', status: 0, clickAttempted: false,
    requestSeen: false, userMessageId: null, backendRequests: 0, streamEnded: false};
  function uuid(s) { return typeof s === 'string' && /^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i.test(s); }
  function fail(code, status) {
    if (!active || state.issue) return;
    state.issue = code; state.status = status || 0; state.phase = 'failed';
    if (reader) { try { reader.cancel(); } catch (_) {} }
  }
  function issue(status) { return status === 401 ? 'not_authenticated' : status === 403 ? 'service_challenge' : status === 429 ? 'rate_limited' : 'upstream_error'; }
  function pathOK() {
    if (!own() || !cfg) return false;
    return cfg.conversationId ? location.pathname === '/c/' + cfg.conversationId : location.pathname === '/';
  }
  function urlOf(input) { try { return new URL(typeof input === 'string' ? input : input.url, location.href); } catch (_) { return null; } }
  function same(u) { return u && u.protocol === 'https:' && u.hostname === 'chatgpt.com' && (!u.port || u.port === '443') && !u.username && !u.password && !u.hash; }
  function bodyIdentity(init) {
    if (!init || typeof init.body !== 'string' || init.body.length > 262144) return null;
    try {
      var b = JSON.parse(init.body), m = b.messages, p, text;
      if (b.action !== 'next' || !Array.isArray(m) || m.length !== 1 || !uuid(m[0].id) ||
          !m[0].author || m[0].author.role !== 'user' || !m[0].content || !Array.isArray(m[0].content.parts)) return null;
      p = m[0].content.parts;
      if (p.length !== 1 || typeof p[0] !== 'string') return null;
      // Text-only native Send must never inherit an attachment left in the
      // website's composer. Preparation/security metadata otherwise stays native
      // to the ordinary website handler.
      var holders = [b, m[0].metadata || {}], keys = ['attachments', 'file_references'];
      for (var hi = 0; hi < holders.length; hi++) for (var ki = 0; ki < keys.length; ki++) {
        var av = holders[hi][keys[ki]];
        if (av !== undefined && av !== null && (!Array.isArray(av) || av.length)) return null;
      }
      text = p[0];
      if (text !== cfg.text) return null;
      if (cfg.conversationId) {
        if (b.conversation_id !== cfg.conversationId || b.parent_message_id !== cfg.parentMessageId) return null;
      } else if (b.conversation_id !== undefined && b.conversation_id !== null) return null;
      return m[0].id;
    } catch (_) { return null; }
  }
  function enqueue(value) {
    if (!active || state.issue) return false;
    if (!value || typeof value.length !== 'number' || bytes + value.length > 8388608) { fail('size_limit'); return false; }
    bytes += value.length;
    for (var off = 0; off < value.length; off += 16384) {
      var length = Math.min(16384, value.length - off), text = '';
      if (queued + length > 524288) { fail('size_limit'); return false; }
      for (var i = 0; i < length; i++) text += String.fromCharCode(value[off + i]);
      queue.push({data: btoa(text), size: length}); queued += length;
    }
    return true;
  }
  function observe(response) {
    if (!active) return;
    state.status = response.status;
    if (response.status !== 200) { fail(issue(response.status), response.status); return; }
    var content = response.headers && response.headers.get('content-type');
    if (!content || content.toLowerCase().indexOf('text/event-stream') !== 0) { fail('unknown_wire_shape'); return; }
    var copy;
    try { copy = response.clone(); } catch (_) { fail('unknown_wire_shape'); return; }
    if (!copy.body || typeof copy.body.getReader !== 'function') { fail('capability_unavailable'); return; }
    reader = copy.body.getReader(); state.phase = 'streaming';
    function read() {
      reader.read().then(function (part) {
        if (!active || state.issue) return;
        if (part.done) { state.streamEnded = true; return; }
        if (enqueue(part.value)) read();
      }, function () { fail('network_unavailable'); });
    }
    read();
  }
  wrapper = function (input, init) {
    var u = urlOf(input), method = String((init && init.method) || (input && input.method) || 'GET').toUpperCase();
    var backend = same(u) && u.pathname.indexOf('/backend-api/') === 0;
    if (backend) state.backendRequests++;
    if (same(u) && u.pathname === '/backend-api/f/conversation') {
      if (method !== 'POST' || u.search) { fail('invalid_request'); return Promise.reject(new Error('ChatGPT X route gate')); }
      if (!active || !cfg || !own() || !state.clickAttempted || sent || state.issue) {
        fail('duplicate_operation'); return Promise.reject(new Error('ChatGPT X single send gate'));
      }
      var id = bodyIdentity(init);
      if (!id) { fail('invalid_request'); return Promise.reject(new Error('ChatGPT X body gate')); }
      sent = true; state.requestSeen = true; state.userMessageId = id;
      return original.call(window, input, init).then(function (response) { observe(response); return response; }, function (error) { fail('network_unavailable'); throw error; });
    }
    return original.call(window, input, init).then(function (response) {
      if (backend && (response.status === 403 || response.status === 429)) fail(issue(response.status), response.status);
      return response;
    });
  };
  if (typeof original !== 'function') return 'unsupported';
  window.fetch = wrapper;
  function authorize() {
    state.phase = 'authorizing';
    // This is the website's own cookie session. The token stays inside this
    // closure and is never returned to native UI, diagnostics, or fixtures.
    state.backendRequests++;
    original.call(window, '/api/auth/session', {credentials: 'include', cache: 'no-store'}).then(function (response) {
      if (response.status !== 200) throw {safe: issue(response.status), status: response.status};
      return response.json();
    }).then(function (session) {
      if (!active || !own()) throw {safe: 'stale_context'};
      if (!session || typeof session.accessToken !== 'string' || session.accessToken.length > 32768) throw {safe: 'not_authenticated'};
      state.backendRequests++;
      return original.call(window, '/backend-api/me', {credentials: 'include', cache: 'no-store', headers: {Authorization: 'Bearer ' + session.accessToken}});
    }).then(function (response) {
      if (response.status !== 200) throw {safe: issue(response.status), status: response.status};
      return response.json();
    }).then(function (me) {
      if (!active || !pathOK()) throw {safe: 'stale_context'};
      if (!me || typeof me.id !== 'string' || !me.id.length || me.id.length > 512) throw {safe: 'unknown_wire_shape'};
      state.owner = me.id; state.phase = 'owner_ready';
    }).catch(function (error) { fail(error && error.safe || 'network_unavailable', error && error.status); });
  }
  function visible(e) { return e && e.getClientRects().length && !e.closest('[inert]') && getComputedStyle(e).visibility !== 'hidden'; }
  function fields() {
    return Array.prototype.filter.call(document.querySelectorAll('main [contenteditable="true"],main textarea'), function (e) { return visible(e) && (e.isContentEditable || e.tagName === 'TEXTAREA'); });
  }
  function textOf(root) {
    if (root.tagName === 'TEXTAREA') return root.value;
    var supported = true, inline = {SPAN:1,A:1,MARK:1,CODE:1,EM:1,STRONG:1,B:1,I:1,S:1,DEL:1,U:1};
    function read(node) {
      if (node.nodeType === 3) return node.nodeValue || '';
      if (node.nodeType !== 1) { supported = false; return ''; }
      if (node.tagName === 'SVG' || node.getAttribute('aria-hidden') === 'true') return '';
      if (node.tagName === 'BR') return node.classList.contains('ProseMirror-trailingBreak') ? '' : '\n';
      if (!inline[node.tagName] && node.tagName !== 'P' && node.tagName !== 'DIV') { supported = false; return ''; }
      return Array.prototype.map.call(node.childNodes, read).join('');
    }
    var children = Array.prototype.slice.call(root.childNodes);
    var blocks = children.length && children.every(function (n) { return n.nodeType === 1 && (n.tagName === 'P' || n.tagName === 'DIV'); });
    var text = children.map(read).join(blocks ? '\n' : '');
    return supported && text.length <= 16000 ? text : null;
  }
  var sendSelector = 'main button[type="submit"],button[data-testid="send-button"],button#composer-submit-button';
  function button() {
    // Existing-conversation layouts may portal the normal composer button
    // outside main. Keep exact site IDs and require one visible enabled target.
    var all = document.querySelectorAll(sendSelector);
    var buttons = Array.prototype.filter.call(all, function (b) { return visible(b) && !b.disabled && b.getAttribute('aria-disabled') !== 'true'; });
    return buttons.length === 1 ? buttons[0] : null;
  }
  var api = {
    begin: function (value) {
      if (!active || cfg || !own() || !value || typeof value.text !== 'string' || !value.text.trim() || value.text.length > 16000 ||
          (value.conversationId !== null && !uuid(value.conversationId)) || !uuid(value.parentMessageId)) return 'refused';
      cfg = value; if (!pathOK()) { fail('stale_context'); return 'refused'; }
      authorize(); return 'started';
    },
    approve: function () {
      if (!active || state.phase !== 'owner_ready' || !pathOK()) return 'refused';
      delete state.owner; var f = fields();
      if (f.length !== 1) { fail('conflict'); return 'refused'; }
      var existing = textOf(f[0]);
      if (existing === cfg.text) { typed = true; state.phase = 'typing'; return 'typed'; }
      if (existing !== '') { fail('conflict'); return 'refused'; }
      var e = f[0]; e.focus();
      try {
        if (e.tagName === 'TEXTAREA') {
          var setter = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set;
          setter.call(e, cfg.text); e.dispatchEvent(new Event('input', {bubbles: true}));
        } else if (!document.execCommand('insertText', false, cfg.text)) { fail('capability_unavailable'); return 'refused'; }
      } catch (_) { fail('capability_unavailable'); return 'refused'; }
      typed = true; state.phase = 'typing'; return 'typed';
    },
    ready: function () {
      if (!active || !typed || !pathOK()) return false;
      var f = fields(); return f.length === 1 && textOf(f[0]) === cfg.text && !!button();
    },
    click: function () {
      if (!api.ready() || state.clickAttempted || state.issue) return 'refused';
      var b = button(); state.clickAttempted = true; state.phase = 'dispatching';
      // Normal site's click handler performs preparation/security and Send.
      b.click(); return 'clicked';
    },
    take: function () {
      if (!own()) { fail('stale_context'); }
      var out = {}, k; for (k in state) if (Object.prototype.hasOwnProperty.call(state, k)) out[k] = state[k];
      var f = state.phase === 'owner_ready' || state.phase === 'typing' ? fields() : [];
      var currentText = f.length === 1 ? textOf(f[0]) : null;
      out.composerReady = f.length === 1 && (currentText === '' || currentText === cfg.text);
      out.composerConflict = f.length === 1 && currentText !== '' && currentText !== cfg.text;
      out.composerCount = f.length;
      out.composerLength = currentText === null ? 0 : currentText.length;
      out.typingMatches = !!cfg && currentText === cfg.text;
      var candidates = Array.prototype.filter.call(document.querySelectorAll(sendSelector), visible);
      out.sendCandidates = candidates.length;
      out.sendEnabled = candidates.filter(function (e) { return !e.disabled && e.getAttribute('aria-disabled') !== 'true'; }).length;
      out.globalSubmitCandidates = Array.prototype.filter.call(document.querySelectorAll('button#composer-submit-button'), visible).length;
      if (typeof performance !== 'undefined') {
        if (performance.now) out.bridgeAgeMs = Math.max(0, performance.now() - bridgeBegan);
        var nt = performance.timing;
        if (nt && nt.navigationStart > 0) {
          if (nt.domContentLoadedEventEnd >= nt.navigationStart) out.navigationDOMMs = nt.domContentLoadedEventEnd - nt.navigationStart;
          if (nt.loadEventEnd >= nt.navigationStart) out.navigationLoadMs = nt.loadEventEnd - nt.navigationStart;
        }
        if (performance.getEntriesByType) {
          var resources = performance.getEntriesByType('resource');
          out.resourceCount = resources.length;
          out.resourceTransferBytes = resources.reduce(function (n, r) { return n + (typeof r.transferSize === 'number' && r.transferSize >= 0 ? r.transferSize : 0); }, 0);
        }
      }
      out.documentVisible = document.visibilityState !== 'hidden';
      out.documentFocused = typeof document.hasFocus === 'function' && document.hasFocus();
      var selection = typeof window.getSelection === 'function' ? window.getSelection() : null;
      out.selectionInside = !!(f.length === 1 && selection && selection.anchorNode && typeof f[0].contains === 'function' && f[0].contains(selection.anchorNode));
      out.ready = state.phase === 'typing' && api.ready(); out.frames = [];
      for (var i = 0; i < 4 && queue.length; i++) { var item = queue.shift(); queued -= item.size; out.frames.push(item.data); }
      // End is observable only after the final queued byte was delivered.
      out.streamEnded = state.streamEnded && queue.length === 0;
      return JSON.stringify(out);
    },
    park: function () {
      if (!own() || !active || !state.streamEnded || state.issue) return 'refused';
      active = false; queue.length = 0; queued = 0; cfg = null;
      if (reader) { try { reader.cancel(); } catch (_) {} reader = null; }
      delete state.owner; state.phase = 'parked';
      // Leave the single-Send gate installed while the ordinary site settles.
      // An unsolicited retry from the old handler must not create a new POST.
      return 'parked';
    },
    resume: function (nextNonce) {
      if (!own() || active || state.phase !== 'parked' || window.fetch !== wrapper ||
          typeof nextNonce !== 'string' || !/^[a-f0-9]{32}$/.test(nextNonce) || nextNonce === nonce) return 'refused';
      nonce = nextNonce; cfg = null; queue = []; queued = 0; bytes = 0; typed = false; sent = false;
      state = {nonce:nonce, phase:'idle', issue:'', status:0, clickAttempted:false,
        requestSeen:false, userMessageId:null, backendRequests:0, streamEnded:false};
      bridgeBegan = typeof performance !== 'undefined' && performance.now ? performance.now() : 0;
      active = true; return 'installed';
    },
    detach: function () {
      active = false; queue.length = 0; queued = 0; cfg = null;
      if (window.fetch === wrapper) window.fetch = original;
      if (reader) { try { reader.cancel(); } catch (_) {} }
      delete state.owner; if (window.__OR6ChatBridge === api) window.__OR6ChatBridge = null;
      return 'detached';
    }
  };
  window.__OR6ChatBridge = api; return 'installed';
})
