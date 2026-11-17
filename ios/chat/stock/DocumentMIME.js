// Function expression. Native caller invokes: (SOURCE)(window, VERIFIED_FACTS).
// Adds only a missing standard API, bound to this exact real HTTPS response.
// Never run with invented MIME, an HTML/baseURL page, or unverified TLS facts.
(function (w, facts) {
  'use strict';
  var d = w.document, target = 'https://chatgpt.com/robots.txt';
  if (!facts || facts.certificateVerified !== true || facts.certificateVerificationRequired !== true || facts.hostnameVerificationRequired !== true ||
      facts.status !== 200 || facts.responseMIME !== 'text/plain' || facts.mimeTextPlain !== true || facts.serviceStop !== false ||
      facts.networkRequestsDispatched !== 1 || facts.loadsStarted !== 1 || facts.blockedRequests !== 0 ||
      facts.nativeUserAgentForwarded !== true || facts.htmlStringLoaded !== false || facts.baseURLUsed !== false || !(facts.bodyBytes > 0)) return 'wrong_response';
  if (w !== w.top || w.location.href !== target || !d || d.URL !== target || d.domain !== 'chatgpt.com' || !d.body ||
      d.body.textContent.indexOf('User-agent') < 0 || d.getElementsByTagName('script').length !== 0) return 'wrong_document';
  var current, descriptor;
  try { current = d.contentType; descriptor = Object.getOwnPropertyDescriptor(d, 'contentType'); } catch (e) { return 'unsupported'; }
  if (current !== undefined) {
    if (current !== facts.responseMIME) return 'mime_conflict';
    return descriptor && descriptor.get && descriptor.get.__or6VerifiedMIME === true ? 'already_installed' : 'native';
  }
  if ('contentType' in d) return 'unsupported';  // no replacement of an existing facility
  var mime = facts.responseMIME;
  var getter = function () {
    if (w.document !== d || w.location.href !== target || d.URL !== target) throw new URIError('stale_document');
    return mime;
  };
  getter.__or6VerifiedMIME = true;
  try { Object.defineProperty(d, 'contentType', { configurable: true, enumerable: true, get: getter }); }
  catch (e) { return 'unsupported'; }
  return d.contentType === mime ? 'installed' : 'unsupported';
})
