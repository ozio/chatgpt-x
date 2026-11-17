// Standard functional shims only. No browser identity, DOM, RNG or transport edits.
(function (g, internalState) {
  'use strict';
  if (g.__OR6Compatibility && g.__OR6Compatibility.version === 'stock-compat-1') return 'installed';
  var installed = { textEncoder: false, performanceNow: false, coarseClock: false };
  if (typeof g.TextEncoder !== 'function') {
    var getState = internalState.getterFor('OR6TextEncoder');
    var text = function (value, optional) {
      if (optional && value === undefined) return '';
      if (typeof value === 'symbol' || (typeof g.Symbol === 'function' && value instanceof g.Symbol)) throw new TypeError('Symbol cannot be encoded');
      return String(value);
    };
    var length = function (s) {
      var n = 0, i, c, d;
      for (i = 0; i < s.length; i++) {
        c = s.charCodeAt(i);
        if (c < 128) n++;
        else if (c < 2048) n += 2;
        else if (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length && (d = s.charCodeAt(i + 1)) >= 0xDC00 && d <= 0xDFFF) { n += 4; i++; }
        else n += 3;
      }
      return n;
    };
    var write = function (s, target) {
      var i = 0, j = 0, c, d, units, size;
      while (i < s.length) {
        c = s.charCodeAt(i); units = 1;
        if (c >= 0xD800 && c <= 0xDBFF) {
          d = i + 1 < s.length ? s.charCodeAt(i + 1) : 0;
          if (d >= 0xDC00 && d <= 0xDFFF) { c = 0x10000 + ((c - 0xD800) << 10) + d - 0xDC00; units = 2; }
          else c = 0xFFFD;
        } else if (c >= 0xDC00 && c <= 0xDFFF) c = 0xFFFD;
        size = c < 128 ? 1 : c < 2048 ? 2 : c < 65536 ? 3 : 4;
        if (j + size > target.length) break;
        if (size === 1) target[j++] = c;
        else if (size === 2) { target[j++] = 0xC0 | (c >> 6); target[j++] = 0x80 | (c & 63); }
        else if (size === 3) { target[j++] = 0xE0 | (c >> 12); target[j++] = 0x80 | ((c >> 6) & 63); target[j++] = 0x80 | (c & 63); }
        else { target[j++] = 0xF0 | (c >> 18); target[j++] = 0x80 | ((c >> 12) & 63); target[j++] = 0x80 | ((c >> 6) & 63); target[j++] = 0x80 | (c & 63); }
        i += units;
      }
      return { read: i, written: j };
    };
    var Encoder = function Encoder() { if (!(this instanceof Encoder)) throw new TypeError('TextEncoder requires new'); internalState.set(this, { type: 'OR6TextEncoder' }); };
    Object.defineProperty(Encoder.prototype, 'encoding', { configurable: true, enumerable: true, get: function () {
      getState(this); return 'utf-8';
    } });
    Encoder.prototype.encode = function (value) {
      getState(this);
      var s = text(value, true), out = new g.Uint8Array(length(s)); write(s, out); return out;
    };
    Encoder.prototype.encodeInto = function (value, destination) {
      getState(this);
      if (arguments.length < 2 || Object.prototype.toString.call(destination) !== '[object Uint8Array]') throw new TypeError('Invalid encodeInto arguments');
      return write(text(value, false), destination);
    };
    if (g.Symbol && g.Symbol.toStringTag) Object.defineProperty(Encoder.prototype, g.Symbol.toStringTag, { configurable: true, value: 'TextEncoder' });
    g.TextEncoder = Encoder; installed.textEncoder = true;
  }
  if (!g.performance) g.performance = {};
  if (typeof g.performance.now !== 'function') {
    var clock = typeof g.performance.webkitNow === 'function' ? function () { return g.performance.webkitNow(); } : null;
    var origin = Date.now(), last = 0;
    if (!clock) { installed.coarseClock = true; clock = function () { return Date.now() - origin; }; }
    g.performance.now = function () { var n = clock(); if (n > last) last = n; return last; };
    installed.performanceNow = true;
  }
  // Diagnostic metadata is about this real implementation, not a device profile.
  g.__OR6Compatibility = { schema: 1, version: 'stock-compat-1', installed: installed };
  return 'installed';
})(window, __or6State);
