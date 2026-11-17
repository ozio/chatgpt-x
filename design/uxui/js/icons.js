/* Original line glyphs (24×24) and glossy tiles. "C" is replaced by the colour. */
(function () {
  'use strict';
  var S = 'fill="none" stroke="C" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"';
  var F = 'fill="C"';
  var G = {
    menu: '<path ' + S + ' d="M4 6.5h16M4 12h16M4 17.5h16"/>',
    compose: '<path ' + S + ' d="M13 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-7"/><path ' + S + ' d="M18.5 3.5l2 2L12 14l-3 1 1-3z"/>',
    plus: '<path ' + S + ' stroke-width="2.6" d="M12 5v14M5 12h14"/>',
    mic: '<rect x="9" y="3" width="6" height="11" rx="3" ' + F + '/><path ' + S + ' d="M6 11a6 6 0 0 0 12 0M12 17v4M9 21h6"/>',
    voice: '<path ' + S + ' stroke-width="2.4" d="M4 10v4M8 7v10M12 4v16M16 7v10M20 10v4"/>',
    stop: '<rect x="6" y="6" width="12" height="12" rx="2" ' + F + '/>',
    up: '<path ' + S + ' stroke-width="2.6" d="M12 19V6M6 11l6-6 6 6"/>',
    copy: '<rect x="8" y="8" width="12" height="12" rx="2" ' + S + '/><path ' + S + ' d="M16 5H6a2 2 0 0 0-2 2v9"/>',
    regen: '<path ' + S + ' d="M19 12a7 7 0 1 1-2.05-4.95"/><path ' + F + ' d="M20.5 3.5v6h-6z"/>',
    speaker: '<path ' + F + ' d="M4 9h4l5-4v14l-5-4H4z"/><path ' + S + ' d="M16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12"/>',
    speakerOff: '<path ' + F + ' d="M4 9h4l5-4v14l-5-4H4z"/><path ' + S + ' d="M16 9l5 6M21 9l-5 6"/>',
    share: '<path ' + S + ' d="M8 9H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8a2 2 0 0 0-2-2h-2"/><path ' + S + ' d="M12 15V3M8 7l4-4 4 4"/>',
    more: '<circle cx="5" cy="12" r="2.2" ' + F + '/><circle cx="12" cy="12" r="2.2" ' + F + '/><circle cx="19" cy="12" r="2.2" ' + F + '/>',
    search: '<circle cx="10.5" cy="10.5" r="6" ' + S + ' stroke-width="2.6"/><path ' + S + ' stroke-width="3" d="M15 15l5 5"/>',
    globe: '<circle cx="12" cy="12" r="8.5" ' + S + '/><path ' + S + ' stroke-width="1.6" d="M3.5 12h17M12 3.5c3 3 3 14 0 17M12 3.5c-3 3-3 14 0 17"/>',
    photo: '<rect x="3" y="5" width="18" height="14" rx="2" ' + S + '/><path ' + F + ' d="M5 17l4.5-5 3 3 2.5-2.5L19 17z"/><circle cx="16" cy="9" r="1.6" ' + F + '/>',
    camera: '<path ' + F + ' d="M8.5 5l1.5-2h4l1.5 2H19a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2z"/><circle cx="12" cy="12" r="3.6" fill="none" stroke="#fff" stroke-width="2"/>',
    file: '<path ' + S + ' d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path ' + S + ' d="M14 3v5h5M9 13h6M9 17h6"/>',
    book: '<path ' + S + ' d="M4 5.5C6.5 4 9.5 4 12 6c2.5-2 5.5-2 8-.5V19c-2.5-1.5-5.5-1.5-8 .5-2.5-2-5.5-2-8-.5z"/><path ' + S + ' d="M12 6v13.5"/>',
    research: '<path ' + S + ' d="M13 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h4"/><circle cx="16" cy="14" r="3.5" ' + S + '/><path ' + S + ' d="M18.5 16.5L21 19M8.5 8h5M8.5 12h2"/>',
    pin: '<path ' + F + ' d="M9 3h6l-1 6 3 3v2h-4v6l-1 1-1-1v-6H7v-2l3-3z"/>',
    archive: '<rect x="3" y="4" width="18" height="5" rx="1" ' + S + '/><path ' + S + ' d="M5 9v9a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V9M10 13h4"/>',
    trash: '<path ' + S + ' d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 11v6M14 11v6"/>',
    folder: '<path ' + F + ' d="M3 6a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
    lock: '<rect x="5" y="10" width="14" height="11" rx="2" ' + F + '/><path ' + S + ' stroke-width="2.4" d="M8 10V7a4 4 0 0 1 8 0v3"/>',
    gear: '<path ' + F + ' d="M10.3 2h3.4l.5 2.6 1.9.8 2.2-1.5 2.4 2.4-1.5 2.2.8 1.9 2.6.5v3.4l-2.6.5-.8 1.9 1.5 2.2-2.4 2.4-2.2-1.5-1.9.8-.5 2.6h-3.4l-.5-2.6-1.9-.8-2.2 1.5-2.4-2.4 1.5-2.2-.8-1.9L2 13.7v-3.4l2.6-.5.8-1.9-1.5-2.2 2.4-2.4 2.2 1.5 1.9-.8z"/><circle cx="12" cy="12" r="3.4" fill="#fff"/>',
    translate: '<path ' + S + ' d="M3 5h10M8 3v2M5 5c1 4 4 7 7 8M11 5c-1 4-4 7-7 8"/><path ' + S + ' d="M13 21l4-9 4 9M14.5 18h5"/>',
    library: '<rect x="3" y="4" width="4" height="16" rx="1" ' + S + '/><rect x="9" y="4" width="4" height="16" rx="1" ' + S + '/><path ' + S + ' d="M15 5.5l3.5-1 3 14.5-3.5 1z"/>',
    gpt: '<circle cx="7.5" cy="7.5" r="3.5" ' + F + '/><circle cx="16.5" cy="7.5" r="3.5" ' + S + '/><circle cx="7.5" cy="16.5" r="3.5" ' + S + '/><circle cx="16.5" cy="16.5" r="3.5" ' + F + '/>',
    clock: '<circle cx="12" cy="12" r="8.5" ' + S + '/><path ' + S + ' d="M12 7v5l3.5 2"/>',
    images: '<rect x="6" y="3" width="15" height="13" rx="2" ' + S + '/><path ' + S + ' d="M3 8v11a2 2 0 0 0 2 2h11"/><path ' + F + ' d="M8 14l3.5-4 2.5 2.5 2-2 3 3.5z"/>',
    ghost: '<path ' + S + ' stroke-dasharray="3 2.6" d="M12 3.5c-5 0-8.5 3.4-8.5 7.6 0 2.4 1.2 4.4 3 5.8L5.5 21l4.4-2.3c.7.1 1.4.2 2.1.2 5 0 8.5-3.4 8.5-7.7S17 3.5 12 3.5z"/>',
    expand: '<path ' + S + ' d="M14 4h6v6M10 20H4v-6M20 4l-7 7M4 20l7-7"/>',
    collapse: '<path ' + S + ' d="M20 10h-6V4M4 14h6v6M14 10l7-7M10 14l-7 7"/>',
    at: '<circle cx="12" cy="12" r="3.6" ' + S + '/><path ' + S + ' d="M15.6 12v1.5a2.5 2.5 0 0 0 5 0V12A8.6 8.6 0 1 0 17 19"/>',
    scan: '<path ' + S + ' d="M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3M8 9h8M8 12h8M8 15h5"/>',
    brush: '<path ' + F + ' d="M20 3c.8.8-4.5 8.5-7 10.5l-2.5-2.5C12.5 8.5 19.2 2.2 20 3zM9.5 12.5l2 2c-.3 3.2-3.2 5.5-7.5 5 1.6-1.1 1.3-2.7 2.3-4.6.8-1.4 2-2.3 3.2-2.4z"/>',
    eraser: '<path ' + F + ' d="M14.5 3.5l6 6L11 19H6.5l-3-3z"/><path fill="#fff" opacity=".6" d="M9.6 8.4l6 6-3 3-6-6z"/>',
    person: '<circle cx="12" cy="8" r="4.2" ' + F + '/><path ' + F + ' d="M3.5 21c.6-4.6 4-7 8.5-7s7.9 2.4 8.5 7z"/>',
    check: '<path ' + S + ' stroke-width="3" d="M5 12.5l4.5 4.5L19 7"/>',
    down: '<path ' + S + ' stroke-width="2.6" d="M6 9l6 6 6-6"/>',
    bag: '<rect x="3" y="7" width="18" height="13" rx="2" ' + S + '/><path ' + S + ' d="M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2M3 12h18"/>',
    mail: '<rect x="3" y="5" width="18" height="14" rx="2" ' + S + '/><path ' + S + ' d="M3.5 6.5L12 13l8.5-6.5"/>',
    link: '<path ' + S + ' d="M10 14a4 4 0 0 0 5.7 0l3.6-3.6a4 4 0 0 0-5.7-5.7L12 6.3M14 10a4 4 0 0 0-5.7 0l-3.6 3.6a4 4 0 0 0 5.7 5.7l1.6-1.6"/>',
    chart: '<path ' + S + ' d="M4 20h17M4 20V4"/><rect x="7" y="12" width="3" height="6" ' + F + '/><rect x="12" y="8" width="3" height="10" ' + F + '/><rect x="17" y="5" width="3" height="13" ' + F + '/>',
    swap: '<path ' + S + ' d="M4 8h15M15 4l4 4-4 4M20 16H5M9 12l-4 4 4 4"/>',
    branch: '<circle cx="6" cy="5" r="2.2" ' + S + '/><circle cx="6" cy="19" r="2.2" ' + S + '/><circle cx="18" cy="9" r="2.2" ' + S + '/><path ' + S + ' d="M6 7.2v9.6M18 11.2c0 4-6 3-11 5.8"/>',
    flag: '<path ' + S + ' d="M5 21V4M5 4h11l-2 4 2 4H5"/>',
    edit: '<path ' + S + ' d="M15 4.5l4.5 4.5L9 19.5H4.5V15z"/>',
    play: '<path ' + F + ' d="M7 4.5v15l12.5-7.5z"/>',
    pause: '<rect x="6" y="4.5" width="4" height="15" rx="1" ' + F + '/><rect x="14" y="4.5" width="4" height="15" rx="1" ' + F + '/>',
    star: '<path ' + F + ' d="M12 2.8l2.8 5.9 6.4.8-4.7 4.4 1.2 6.4L12 17.2l-5.7 3.1 1.2-6.4-4.7-4.4 6.4-.8z"/>',
    bell: '<path ' + F + ' d="M12 3a6 6 0 0 0-6 6v4.5L4 17h16l-2-3.5V9a6 6 0 0 0-6-6zM9.5 19a2.5 2.5 0 0 0 5 0z"/>',
    location: '<path ' + F + ' d="M21 3L3 10.5l7.5 3 3 7.5z"/>',
    shield: '<path ' + F + ' d="M12 2.5l8 3v6c0 5-3.4 8.7-8 10-4.6-1.3-8-5-8-10v-6z"/>',
    brain: '<path ' + S + ' d="M9 4a3 3 0 0 0-3 3 3 3 0 0 0-2 5 3 3 0 0 0 2 5 3 3 0 0 0 6 1V5a2 2 0 0 0-3-1zM15 4a3 3 0 0 1 3 3 3 3 0 0 1 2 5 3 3 0 0 1-2 5 3 3 0 0 1-6 1"/>',
    text: '<path ' + F + ' d="M3 19l5-14h2l5 14h-2.4l-1.3-3.8H6.7L5.4 19zm4.4-6h3.9L9.4 7.4zM16 19l2.8-8h1.6l2.8 8h-1.7l-.7-2.1h-2.4l-.7 2.1zm2.8-3.5h1.6l-.8-2.4z"/>',
    sun: '<circle cx="12" cy="12" r="4" ' + F + '/><path ' + S + ' d="M12 2.5v2.5M12 19v2.5M2.5 12H5M19 12h2.5M5.3 5.3l1.8 1.8M16.9 16.9l1.8 1.8M5.3 18.7l1.8-1.8M16.9 7.1l1.8-1.8"/>',
    sliders: '<path ' + S + ' d="M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12M20 18h0"/><circle cx="16" cy="6" r="2" ' + S + '/><circle cx="10" cy="12" r="2" ' + S + '/><circle cx="18" cy="18" r="2" ' + S + '/>',
    devices: '<rect x="2.5" y="4" width="13" height="10" rx="1.5" ' + S + '/><path ' + S + ' d="M5.5 18h7"/><rect x="16" y="8" width="6" height="12" rx="1.5" ' + S + '/>',
    key: '<circle cx="8" cy="12" r="4.5" ' + S + '/><path ' + S + ' d="M12.5 12H21M18 12v3M21 12v2"/>',
    apps: '<rect x="3.5" y="3.5" width="7" height="7" rx="1.6" ' + F + '/><rect x="13.5" y="3.5" width="7" height="7" rx="1.6" ' + F + '/><rect x="3.5" y="13.5" width="7" height="7" rx="1.6" ' + F + '/><path ' + S + ' d="M17 13.5v7M13.5 17h7"/>',
    cloud: '<path ' + F + ' d="M7 19a4.5 4.5 0 0 1-.6-9A6 6 0 0 1 18 8.5a4.5 4.5 0 0 1-.5 10.5z"/>',
    terminal: '<rect x="2.5" y="4" width="19" height="16" rx="2.5" ' + S + '/><path ' + S + ' d="M6.5 9.5l3.5 3-3.5 3M12 16h5"/>',
    thumb: '<path ' + F + ' d="M3 10h3.5v10H3zM8.5 20V10l4-7c1.6 0 2.5 1.2 2.1 2.8L14 9h5.2c1.3 0 2.2 1.2 1.9 2.4l-1.8 7c-.3 1-1.1 1.6-2.1 1.6z"/>'
  };
  K.glyph = function (name, size, color, extra) {
    size = size || 24;
    return '<svg width="' + size + '" height="' + size + '" viewBox="0 0 24 24"' + (extra || '') + '>' + (G[name] || '').replace(/="C"/g, '="' + (color || '#fff') + '"') + '</svg>';
  };
  /* Embossed white bar-button glyph (iOS 6 toolbar icon look). */
  K.barGlyph = function (name, size) {
    return '<svg width="' + (size || 20) + '" height="' + (size || 20) + '" viewBox="0 0 24 24" style="overflow:visible">' +
      '<g transform="translate(0,-1)" opacity=".55">' + G[name].replace(/="C"/g, '="#063b22"') + '</g>' + G[name].replace(/="C"/g, '="#fff"') + '</svg>';
  };
  var TILE = {
    green: ['#7fdcab', '#1e9656'], blue: ['#7fb5f5', '#2a66cc'], orange: ['#ffc874', '#e07a0c'], red: ['#ff8c7f', '#c9200f'],
    purple: ['#c6a4f4', '#6c3fc2'], gray: ['#c9d0cd', '#6b7672'], teal: ['#7ee0dd', '#13878a'], pink: ['#ffa3c8', '#d0377a'],
    graphite: ['#8a959b', '#353e43'], yellow: ['#ffe27a', '#d9a400'], dark: ['#4f6d61', '#163328']
  };
  K.tile = function (name, color, size) {
    var c = TILE[color] || TILE.green;
    size = size || 29;
    return '<span class="ic s' + size + '" style="background-image:-webkit-linear-gradient(top,' + c[0] + ',' + c[1] + ')">' + K.glyph(name, 24, '#fff') + '</span>';
  };
  K.appIcon = function (size) {
    return '<span class="ic s' + size + ' flat"><img src="img/icon-' + (size <= 29 ? 58 : 114) + '.png" alt=""></span>';
  };
})();
