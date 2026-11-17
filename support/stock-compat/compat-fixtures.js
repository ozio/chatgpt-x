// ES5, account-free semantic fixtures. No collector, proof search or VM.
(function (g) {
  'use strict';
  var state = { phase: 'idle', checks: 0, failures: 0, firstFailure: '', asyncSettled: false, coreReady: false };
  var timeout;
  function check(value, code) { state.checks++; if (!value) { state.failures++; if (!state.firstFailure) state.firstFailure = code; } }
  function equal(a, b) { return JSON.stringify(a) === JSON.stringify(b); }
  function run(code, fn) { try { fn(); } catch (e) { check(false, code); } }
  function throws(fn) { try { fn(); return false; } catch (e) { return true; } }
  function finish() { if (state.phase !== 'running') return; clearTimeout(timeout); state.phase = 'complete'; }
  g.__OR6CompatFixtures = {
    start: function () {
      if (state.phase !== 'idle') return 'conflict';
      state.phase = 'running';
      run('identity', function () {
        check(!!g.__OR6Compatibility && g.__OR6Compatibility.identityPreserved === true, 'identity');
        check(g.__OR6Compatibility.nativeFacilitiesPreserved === true, 'identity');
      });
      run('map', function () {
        var a = {}, b = Object.freeze({}), m = new Map();
        m.set(a, 1); m.set(b, 2); m.set(NaN, 3); m.set(NaN, 4); m.set(-0, 5);
        check(m.size === 4 && m.get(a) === 1 && m.get(b) === 2 && m.get(NaN) === 4 && m.get(0) === 5, 'map');
        var seen = []; m.forEach(function (v, k) { seen.push(v); if (k === a) { m.delete(b); m.set('late', 6); } });
        check(equal(seen, [1, 4, 5, 6]), 'map');
        check(m.delete(a) && !m.delete(a) && !m.has(a), 'map'); m.clear(); check(m.size === 0, 'map');
      });
      run('set', function () {
        var object = {}, set = new Set([NaN, NaN, -0, 0, object, object, '1', 1]);
        check(set.size === 5 && set.has(NaN) && set.has(0) && set.has(object), 'set');
        check(Array.from(set).length === 5, 'set'); check(set.delete(object) && !set.has(object), 'set');
        set.clear(); check(set.size === 0, 'set');
      });
      run('iterator', function () {
        check(typeof Symbol === 'function' && !!Symbol.iterator, 'iterator');
        check(equal(Array.from('\uD83D\uDE00x'), ['\uD83D\uDE00', 'x']), 'iterator');
        check(equal(Array.from({ 0: 3, length: 1 }, function (x) { return x + this.add; }, { add: 2 }), [5]), 'iterator');
        var iterable = {}, closed = false; iterable[Symbol.iterator] = function () { return { next: function () { return { value: 1, done: false }; }, 'return': function () { closed = true; return {}; } }; };
        check(throws(function () { Array.from(iterable, function () { throw Error('fixture'); }); }) && closed, 'iterator');
        check(equal(Object.entries({ x: 1, y: 2 }), [['x', 1], ['y', 2]]), 'iterator');
        check(Math.imul(0xFFFFFFFF, 5) === -5 && Math.imul(0x7FFFFFFF, 2) === -2 && Math.imul(NaN, 1) === 0, 'iterator');
        // The reviewed Object/JSON wrappers must provide real Symbol semantics,
        // not merely change existing natives without a behavioral reason.
        var key = Symbol('fixture-key'), object = { plain: 1 }; object[key] = 7;
        check(equal(Object.keys(object), ['plain']) && equal(Object.getOwnPropertyNames(object), ['plain']), 'iterator');
        check(Object.getOwnPropertySymbols(object)[0] === key && object.propertyIsEnumerable(key), 'iterator');
        check(Object.getOwnPropertyDescriptor(object, key).value === 7, 'iterator');
        var descriptor = {}; descriptor[key] = { value: 8, enumerable: true };
        var created = Object.create(null, descriptor); check(created[key] === 8, 'iterator');
        Object.defineProperties(created, { plain: { value: 2 } }); check(created.plain === 2, 'iterator');
        check(JSON.stringify(object) === '{"plain":1}' && JSON.stringify([key, undefined]) === '[null,null]', 'iterator');
        var quotedSurrogate = String.fromCharCode(34, 92) + 'ud800' + String.fromCharCode(34);
        check(JSON.stringify(String.fromCharCode(0xD800)) === quotedSurrogate, 'iterator');
        var tagged = {}; tagged[Symbol.toStringTag] = 'Fixture';
        check(Object.prototype.toString.call(tagged) === '[object Fixture]', 'iterator');
      });
      run('url', function () {
        var p = new URLSearchParams('?a=one+two&a=three&u=%F0%9F%98%80&empty=');
        check(equal(p.getAll('a'), ['one two', 'three']) && p.get('u') === '\uD83D\uDE00' && p.get('empty') === '', 'url');
        p.set('a', 'a b+'); p.append('z', '&='); p.delete('empty');
        check(p.toString() === 'a=a+b%2B&u=%F0%9F%98%80&z=%26%3D', 'url');
        check(equal(Array.from(p.keys()), ['a', 'u', 'z']), 'url');
      });
      run('utf8', function () {
        var encoder = new TextEncoder();
        check(encoder.encoding === 'utf-8', 'utf8');
        check(equal(Array.from(encoder.encode('A\u00E9\u4E2D\uD83D\uDE00\uD800X\uDFFF')), [65,195,169,228,184,173,240,159,152,128,239,191,189,88,239,191,189]), 'utf8');
        check(encoder.encode().length === 0 && equal(Array.from(encoder.encode(null)), [110,117,108,108]), 'utf8');
        var small = new Uint8Array(3), full = new Uint8Array(5), r = encoder.encodeInto('\uD83D\uDE00x', small);
        check(r.read === 0 && r.written === 0, 'utf8');
        r = encoder.encodeInto('\uD83D\uDE00x', full); check(r.read === 3 && r.written === 5 && equal(Array.from(full), [240,159,152,128,120]), 'utf8');
        check(throws(function () { encoder.encodeInto('x', []); }), 'utf8');
      });
      run('reflect', function () {
        check(typeof Reflect === 'object', 'reflect');
        function add(a, b) { return this.x + a + b; }
        check(Reflect.apply(add, { x: 1 }, [2, 3]) === 6, 'reflect');
        check(throws(function () { Reflect.apply(add, null, 1); }), 'reflect');
        function Target(x) { this.x = x; } function NewTarget() {}
        var instance = Reflect.construct(Target, [7], NewTarget);
        check(instance.x === 7 && Object.getPrototypeOf(instance) === NewTarget.prototype, 'reflect');
        var proto = { inherited: 2 }, object = Object.create(proto), symbol = Symbol('reflect');
        Object.defineProperty(object, 'hidden', { value: 3, configurable: false }); object.visible = 4; object[symbol] = 5;
        var names = Reflect.ownKeys(object);
        check(names.indexOf('hidden') >= 0 && names.indexOf('visible') >= 0 && names.indexOf(symbol) >= 0 && names.indexOf('inherited') < 0, 'reflect');
        check(Reflect.has(object, 'inherited') && !Reflect.has(object, 'absent'), 'reflect');
        check(Reflect.get(object, 'hidden') === 3, 'reflect');
        var accessor = { get value() { return this.x; }, set value(v) { this.x = v; } }, receiver = { x: 8 };
        check(Reflect.get(accessor, 'value', receiver) === 8, 'reflect');
        check(Reflect.set(accessor, 'value', 9, receiver) && receiver.x === 9, 'reflect');
        check(Reflect.defineProperty(object, 'extra', { value: 6, configurable: true }), 'reflect');
        check(Reflect.getOwnPropertyDescriptor(object, 'extra').value === 6, 'reflect');
        check(!Reflect.defineProperty(object, 'hidden', { value: 99 }), 'reflect');
        check(Reflect.deleteProperty(object, 'extra') && !Reflect.deleteProperty(object, 'hidden'), 'reflect');
        check(Reflect.getPrototypeOf(object) === proto, 'reflect');
        check(Reflect.setPrototypeOf(object, null) && Reflect.getPrototypeOf(object) === null, 'reflect');
        check(Reflect.isExtensible(object) && Reflect.preventExtensions(object) && !Reflect.isExtensible(object), 'reflect');
        check(!Reflect.defineProperty(object, 'newProperty', { value: 1 }), 'reflect');
        check(throws(function () { Reflect.ownKeys(1); }), 'reflect');
      });
      var firstClock = 0;
      run('clock', function () { firstClock = performance.now(); check(typeof firstClock === 'number' && isFinite(firstClock) && firstClock >= 0 && performance.now() >= firstClock, 'clock'); });
      var core = g.__OR6SentinelCore, noProof;
      run('core', function () {
        state.coreReady = !!core && typeof core.b === 'function' && typeof core.c === 'function' && typeof core.e === 'function';
        check(state.coreReady, 'core');
        if (!state.coreReady) return;
        check(equal(core.b({ prepare_token: 'compat-fixture' }, null, null), { 'OpenAI-Sentinel-Chat-Requirements-Prepare-Token': 'compat-fixture' }), 'core');
        check(equal(core.b({ prepare_token: 'old', token: 'compat-final' }, null, null), { 'OpenAI-Sentinel-Chat-Requirements-Token': 'compat-final' }), 'core');
        check(throws(function () { core.e(null); }), 'core');
        check(throws(function () { core.c({ proofofwork: { required: true } }); }), 'core');
        noProof = core.c({ proofofwork: { required: false } });
      });
      if (typeof Promise !== 'function') { check(false, 'promise'); finish(); return 'started'; }
      timeout = setTimeout(function () { check(false, 'promise_timeout'); finish(); }, 8000);
      var sync = true, assimilation = 0, finallyCount = 0;
      try {
        var thenable = { then: function (resolve, reject) { assimilation++; resolve(7); reject('ignored'); resolve(8); } };
        var tasks = [
          Promise.resolve(thenable).then(function (v) { check(!sync && v === 7 && assimilation === 1, 'promise'); }),
          Promise.all([Promise.resolve(1), 2]).then(function (v) { check(equal(v, [1, 2]), 'promise'); }),
          Promise.all([]).then(function (v) { check(v.length === 0, 'promise'); }),
          Promise.reject('expected').then(null, function (e) { check(e === 'expected', 'promise'); return 3; }).then(function (v) { check(v === 3, 'promise'); }),
          Promise.resolve(2)['finally'](function () { finallyCount++; }).then(function (v) { check(v === 2 && finallyCount === 1, 'promise'); }),
          Promise.race([Promise.resolve(9)]).then(function (v) { check(v === 9, 'promise'); }),
          Promise.resolve(noProof).then(function (v) { check(v === null && state.coreReady, 'core'); })
        ];
        Promise.all(tasks).then(function () {
          check(performance.now() >= firstClock, 'clock'); state.asyncSettled = true; finish();
        }, function () { check(false, 'promise'); finish(); });
      } catch (e) { check(false, 'promise'); finish(); }
      sync = false;
      return 'started';
    },
    take: function () { return JSON.stringify(state); }
  };
  return 'installed';
})(window);
