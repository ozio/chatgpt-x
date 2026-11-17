// StockHTTPS document check. Classic ES5 (iOS 6 JavaScriptCore). Reads the real
// location/DOM values of the loaded top-level document and returns booleans and
// integers only: never the body text, the URL or the user agent. Defines no global,
// changes nothing, touches no network, cookie or storage facility.
(function (w, d) {
  'use strict';
  var TARGET = 'https://chatgpt.com/robots.txt';
  function has(test) { try { return test() === true; } catch (e) { return false; } }
  function read(get) { try { return get(); } catch (e) { return undefined; } }
  var loc = w.location;
  var agent = read(function () { return w.navigator.userAgent; });
  var ua = typeof agent === 'string' ? agent : '';
  var webkit = /AppleWebKit\/(\d+)/.exec(ua);
  var text = read(function () { return d.body ? d.body.textContent : null; });
  var contentType = read(function () { return d.contentType; });
  var scripts = read(function () { return d.getElementsByTagName('script').length; });
  return JSON.stringify({
    topLevel: has(function () { return w === w.top && w.parent === w; }),
    hrefExact: has(function () { return loc.href === TARGET; }),
    documentURLExact: has(function () { return d.URL === TARGET; }),
    protocolHttps: has(function () { return loc.protocol === 'https:'; }),
    hostExact: has(function () { return loc.host === 'chatgpt.com' && loc.hostname === 'chatgpt.com'; }),
    portDefault: has(function () { return loc.port === ''; }),
    pathExact: has(function () { return loc.pathname === '/robots.txt'; }),
    searchEmpty: has(function () { return loc.search === ''; }),
    hashEmpty: has(function () { return loc.hash === ''; }),
    domainExact: has(function () { return d.domain === 'chatgpt.com'; }),
    originExposed: has(function () { return typeof loc.origin === 'string'; }),
    originExact: has(function () { return loc.origin === 'https://chatgpt.com'; }),
    contentTypeExposed: typeof contentType === 'string',
    contentTypeTextPlain: contentType === 'text/plain',
    readyComplete: has(function () { return d.readyState === 'complete'; }),
    bodyPresent: has(function () { return !!d.body; }),
    bodyTextNonEmpty: typeof text === 'string' && text.length > 0,
    bodyMarker: typeof text === 'string' && text.indexOf('User-agent') >= 0,
    bodySinglePre: has(function () { var c = d.body.children; return c.length === 1 && c[0].tagName === 'PRE'; }),
    doctypeAbsent: has(function () { return d.doctype === null; }),
    scriptElements: typeof scripts === 'number' && isFinite(scripts) ? scripts : -1,
    coreGlobalPresent: typeof w.__OR6SentinelCore !== 'undefined',
    harnessPresent: typeof w.__SPHarness !== 'undefined',
    userAgentPresent: ua.length > 0,
    userAgentMobile: /\bMobile\//.test(ua),
    webkitMajor: webkit ? parseInt(webkit[1], 10) : -1
  });
})(window, document);
