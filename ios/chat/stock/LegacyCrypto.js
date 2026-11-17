// A transparent WebCrypto return-value compatibility wrapper. Native entropy,
// validation, receiver checks and exceptions are delegated exactly once. The
// wrapper shows its real JS source; no native-source camouflage or fake RNG.
(function (w) {
  'use strict';
  var c = w.crypto, apply = Function.prototype.apply;
  if (!c || !c.getRandomValues) return JSON.stringify({ installed: false });
  var native = c.getRandomValues, sample = new Uint8Array(16), value;
  try { value = apply.call(native, c, [sample]); } catch (e) { return JSON.stringify({ installed: false }); }
  if (value === sample) return JSON.stringify({ installed: true, methodReplaced: false, cryptoObjectPreserved: w.crypto === c, returnsInput: true, nativeEntropy: true, sourceHonest: true });
  if (value !== undefined) return JSON.stringify({ installed: false });
  var wrapper = function getRandomValues(array) {
    if (this instanceof wrapper) throw new TypeError('getRandomValues is not a constructor');
    var result = apply.call(native, this, arguments);
    return result === undefined ? array : result;
  };
  try { Object.defineProperty(c, 'getRandomValues', { configurable: true, enumerable: true, writable: true, value: wrapper }); }
  catch (e) { return JSON.stringify({ installed: false }); }
  var array = new Uint8Array(16), returned;
  try { returned = c.getRandomValues(array); } catch (e) { return JSON.stringify({ installed: false, methodReplaced: true }); }
  // This flag describes entry-point identity (the base fixtures ran before this
  // additional interface wrapper); native entropy is reported separately below.
  if (w.__OR6Compatibility) w.__OR6Compatibility.nativeFacilitiesPreserved = false;
  return JSON.stringify({ installed: returned === array, methodReplaced: true, originalReturnedUndefined: true, cryptoObjectPreserved: w.crypto === c,
    returnsInput: returned === array, nativeEntropy: true, sourceHonest: Function.prototype.toString.call(wrapper).indexOf('[native code]') < 0 });
})
