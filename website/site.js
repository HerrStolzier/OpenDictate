/* OpenDictate website: pixel components and page motion without dependencies.
   Blink scenes, glyphs and dithering follow design/components/web/bundle.js. */
(function () {
  'use strict';

  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---------- Blink: pixel scenes on a 44 x 50 grid ---------- */
  var GW = 44, GH = 50;
  var ANIM = { r: ['od-a-blink', 0], a: ['od-a-arc', 0.4], b: ['od-a-arc', 0.2], c: ['od-a-arc', 0], '1': ['od-a-type', 0], '2': ['od-a-type', 0.3], '3': ['od-a-type', 0.6] };
  var DRAWN = 'BLSEKkWwVGrRDdabcm123XYyCQ';
  function grid() { var g = []; for (var y = 0; y < GH; y++) { var row = []; for (var x = 0; x < GW; x++) row.push('.'); g.push(row); } return g; }
  function put(g, x, y, ch) { if (y >= 0 && y < GH && x >= 0 && x < GW) g[y][x] = ch; }
  function rect(g, x, y, w, hh, ch) { for (var j = 0; j < hh; j++) for (var i = 0; i < w; i++) put(g, x + i, y + j, ch); }
  function bodyCell(r, c) {
    if (r === 0) return c <= 14 ? 'L' : 'B';
    if (r === 39) return 'E';
    if (c <= 2) return 'L';
    if (c === 3) return r % 2 ? 'L' : 'B';
    if (c === 15) return r % 2 ? 'S' : 'B';
    if (c >= 16) return 'S';
    return 'B';
  }
  function body(g, ox, opt) {
    opt = opt || {};
    for (var r = 0; r < 40; r++) {
      var s = opt.shear ? Math.floor((39 - r) / 10) * opt.shear : 0;
      var x0 = 0, x1 = 19;
      if (r === 0 || r === 39) { x0 = 2; x1 = 17; } else if (r === 1 || r === 38) { x0 = 1; x1 = 18; }
      for (var c = x0; c <= x1; c++) put(g, ox + c + s, r, opt.flat || bodyCell(r, c));
    }
  }
  function shoeL(g, x, y, sole) { rect(g, x + 1, y, 6, 1, 'W'); put(g, x + 2, y, 'w'); put(g, x + 3, y, 'w'); rect(g, x, y + 1, 8, 1, 'W'); put(g, x + 7, y + 1, 'V'); rect(g, x, y + 2, 8, 1, sole); }
  function shoeR(g, x, y, sole) { rect(g, x + 1, y, 6, 1, 'W'); put(g, x + 4, y, 'w'); put(g, x + 5, y, 'w'); rect(g, x, y + 1, 8, 1, 'W'); put(g, x, y + 1, 'V'); rect(g, x, y + 2, 8, 1, sole); }
  function leg(g, x, y, n, dx) { for (var k = 0; k < n; k++) { var xx = x + Math.round(k * dx); put(g, xx, y + k, 'K'); put(g, xx + 1, y + k, 'K'); put(g, xx + 2, y + k, 'k'); } }
  function standLegs(g, ox, sole) { leg(g, ox + 4, 40, 6, 0); leg(g, ox + 13, 40, 6, 0); shoeL(g, ox - 1, 45, sole); shoeR(g, ox + 12, 45, sole); }
  function shadow(g, x0, x1, y) { rect(g, x0 + 1, y, x1 - x0 - 1, 1, 'D'); put(g, x0, y, 'd'); put(g, x1, y, 'd'); }
  function arcs(g, cx, cy) {
    [[4, 'a'], [8, 'b'], [12, 'c']].forEach(function (p) {
      for (var deg = 128; deg <= 232; deg += 2) {
        var t = deg * Math.PI / 180;
        put(g, Math.round(cx + p[0] * Math.cos(t)), Math.round(cy + p[0] * Math.sin(t) * 1.25), p[1]);
      }
    });
  }
  function runs(g) {
    var out = [];
    g.forEach(function (row, y) {
      var x = 0;
      while (x < row.length) {
        var ch = row[x], w = 1;
        while (x + w < row.length && row[x + w] === ch) w++;
        if (DRAWN.indexOf(ch) >= 0) out.push({ x: x, y: y, w: w, ch: ch });
        x += w;
      }
    });
    return out;
  }
  function layer(g, cls) { return { cls: cls || '', cells: runs(g) }; }
  var SCENES = {
    bereit: function () {
      var ox = 12, back = grid(), legs = grid(), b = grid();
      shadow(back, ox - 2, ox + 21, 48); standLegs(legs, ox, 'G'); body(b, ox);
      return { box: '9 0 26 50', layers: [layer(back), layer(legs), layer(b, 'od-a-body')] };
    },
    hoert: function () {
      var ox = 18, g = grid();
      arcs(g, ox - 3, 18); shadow(g, ox - 2, ox + 21, 48); standLegs(g, ox, 'r'); body(g, ox);
      return { box: '0 0 44 50', layers: [layer(g)] };
    },
    schreibt: function () {
      var ox = 17, back = grid(), a = grid(), bb = grid(), b = grid();
      rect(back, 4, 8, 7, 1, 'm'); rect(back, 1, 15, 8, 1, 'm'); rect(back, 4, 22, 7, 1, 'm');
      rect(back, 0, 31, 4, 2, '1'); rect(back, 5, 31, 6, 2, '2'); rect(back, 12, 31, 2, 2, '3');
      shadow(back, ox, ox + 20, 48);
      leg(a, ox + 8, 40, 6, -1); shoeR(a, ox - 1, 45, 'G'); leg(a, ox + 9, 40, 4, 1); shoeR(a, ox + 11, 43, 'G');
      leg(bb, ox + 8, 40, 6, 0); shoeR(bb, ox + 6, 45, 'G'); leg(bb, ox + 8, 40, 3, -1); shoeR(bb, ox - 1, 41, 'G');
      body(b, ox, { shear: 1 });
      return { box: '0 0 44 50', layers: [layer(back), layer(a, 'od-a-run-a'), layer(bb, 'od-a-run-b'), layer(b)] };
    },
    eingefuegt: function () {
      var ox = 18, back = grid(), ch = grid(), front = grid();
      rect(back, 0, 18, 5, 4, 'X'); rect(back, 6, 18, 7, 4, 'X'); rect(back, 14, 18, 2, 4, 'X');
      shadow(back, ox - 2, ox + 21, 48);
      standLegs(ch, ox, 'G'); body(ch, ox);
      [[41, 0], [41, 1], [41, 2], [41, 4], [41, 5], [41, 6], [38, 3], [39, 3], [40, 3], [42, 3], [43, 3]].forEach(function (p) { put(front, p[0], p[1], 'Y'); });
      put(front, 41, 3, 'y');
      return { box: '0 0 44 50', layers: [layer(back, 'od-a-hop-shadow'), layer(ch, 'od-a-hop'), layer(front, 'od-a-twinkle')] };
    },
    hoppla: function () {
      var ox = 14, back = grid(), ch = grid();
      shadow(back, ox - 2, ox + 21, 48); standLegs(back, ox, 'R');
      body(ch, ox - 2, { flat: 'C' }); body(ch, ox + 2, { flat: 'Q' }); body(ch, ox);
      function shift(r0, r1, dx) {
        for (var r = r0; r <= r1; r++) {
          var old = ch[r].slice();
          for (var x = 0; x < GW; x++) ch[r][x] = '.';
          for (var x2 = 0; x2 < GW; x2++) if (old[x2] !== '.') put(ch, x2 + dx, r, old[x2]);
        }
      }
      for (var x = 0; x < GW; x++) { ch[11][x] = '.'; ch[26][x] = '.'; }
      shift(12, 15, 3); shift(27, 30, -3);
      return { box: '0 0 44 50', layers: [layer(back), layer(ch, 'od-a-glitch')] };
    }
  };
  var LABELS = { bereit: 'bereit', hoert: 'hört zu', schreibt: 'schreibt', eingefuegt: 'eingefügt', hoppla: 'Hoppla, Fehler' };
  var cache = {};
  function scene(state) {
    if (!SCENES[state]) state = 'bereit';
    if (!cache[state]) cache[state] = SCENES[state]();
    return cache[state];
  }
  function blink(state, size, framed, glow) {
    var sc = scene(state);
    var box = framed ? '0 0 44 50' : sc.box;
    var height = size || 200;
    var width = Math.round(height * parseFloat(box.split(' ')[2]) / 50);
    var out = '<svg class="od-blink' + (glow ? ' od-glow' : '') + '" viewBox="' + box + '" width="' + width + '" height="' + height +
      '" role="img" aria-label="Blink ' + (LABELS[state] || 'bereit') + '" shape-rendering="crispEdges">';
    sc.layers.forEach(function (l) {
      out += '<g' + (l.cls ? ' class="' + l.cls + '"' : '') + '>';
      l.cells.forEach(function (c) {
        var a = ANIM[c.ch];
        out += '<rect x="' + c.x + '" y="' + c.y + '" width="' + c.w + '" height="1" class="od-px-' + c.ch + (a ? ' ' + a[0] : '') + '"' +
          (a && a[1] ? ' style="animation-delay:' + a[1] + 's"' : '') + '></rect>';
      });
      out += '</g>';
    });
    return out + '</svg>';
  }

  /* ---------- Wordmark ---------- */
  var B32 = [[12, 1, 1, 1, 'L'], [13, 1, 6, 1, 'B'], [19, 1, 1, 1, 'S'], [11, 2, 2, 18, 'L'], [13, 2, 6, 18, 'B'], [19, 2, 2, 18, 'S'], [12, 20, 1, 1, 'L'], [13, 20, 6, 1, 'B'], [19, 20, 1, 1, 'S']];
  var B32LEGS = [[12, 21, 2, 6, 'K'], [18, 21, 2, 6, 'K'], [9, 26, 5, 2, 'W'], [9, 28, 5, 1, 'G'], [18, 26, 5, 2, 'W'], [18, 28, 5, 1, 'G']];
  function cells(list) { return list.map(function (c) { return '<rect x="' + c[0] + '" y="' + c[1] + '" width="' + c[2] + '" height="' + c[3] + '" class="od-px-' + c[4] + '"></rect>'; }).join(''); }
  function wordmark(size, still) {
    return '<span class="od-wordmark' + (still ? ' od-still' : '') + '" style="font-size:' + size + 'px" role="img" aria-label="opendictate">' +
      '<span aria-hidden="true">opendictate</span><svg class="od-wordmark-blink" viewBox="9 1 14 29" aria-hidden="true" shape-rendering="crispEdges">' +
      '<g class="od-a-body">' + cells(B32) + '</g>' + cells(B32LEGS) + '</svg></span>';
  }

  /* ---------- Pixel glyphs (12 x 12) ---------- */
  var BL = '............';
  var GLYPHS = {
    option: [BL, BL, BL, '.XXXX..XXXX.', '....X.......', '.....X......', '......X.....', '.......X....', '.......XXXX.', BL, BL, BL],
    shift: [BL, '.....XX.....', '....X..X....', '...X....X...', '..X......X..', '.XXX....XXX.', '...X....X...', '...X....X...', '...X....X...', '...XXXXXX...', BL, BL],
    space: [BL, BL, BL, BL, BL, BL, '.X........X.', '.X........X.', '.XXXXXXXXXX.', BL, BL, BL],
    rec: [BL, BL, '....XXXX....', '...XXXXXX...', '..XXXXXXXX..', '..XXXXXXXX..', '..XXXXXXXX..', '..XXXXXXXX..', '...XXXXXX...', '....XXXX....', BL, BL],
    check: [BL, BL, '..........X.', '.........XX.', '........XX..', '.X.....XX...', '.XX...XX....', '..XX.XX.....', '...XXX......', '....X.......', BL, BL],
    error: [BL, '.....XX.....', '.....XX.....', '.....XX.....', '.....XX.....', '.....XX.....', '.....XX.....', '.....XX.....', BL, '.....XX.....', '.....XX.....', BL],
    prompt: [BL, BL, '...XX.......', '....XX......', '.....XX.....', '......XX....', '.....XX.....', '....XX......', '...XX.......', BL, BL, BL],
    play: [BL, BL, '...XX.......', '...XXXX.....', '...XXXXXX...', '...XXXXXXXX.', '...XXXXXXXX.', '...XXXXXX...', '...XXXX.....', '...XX.......', BL, BL],
    pause: [BL, BL, '...XX..XX...', '...XX..XX...', '...XX..XX...', '...XX..XX...', '...XX..XX...', '...XX..XX...', '...XX..XX...', '...XX..XX...', BL, BL]
  };
  function glyph(name, size, cls, label) {
    var out = '';
    (GLYPHS[name] || GLYPHS.prompt).forEach(function (row, y) {
      var x = 0;
      while (x < 12) {
        if (row[x] === 'X') { var w = 1; while (x + w < 12 && row[x + w] === 'X') w++; out += '<rect x="' + x + '" y="' + y + '" width="' + w + '" height="1"></rect>'; x += w; } else x++;
      }
    });
    var a11y = label ? ' role="img" aria-label="' + label + '"' : ' aria-hidden="true"';
    return '<svg class="' + cls + '" viewBox="0 0 12 12" width="' + size + '" height="' + size + '" shape-rendering="crispEdges"' + a11y + '>' + out + '</svg>';
  }
  var KEY_LABELS = { option: 'Wahltaste', shift: 'Umschalttaste', space: 'Leertaste' };
  function keycap(g) {
    return '<kbd class="od-key od-key-' + g + '" aria-label="' + KEY_LABELS[g] + '" title="' + KEY_LABELS[g] + '">' + glyph(g, 36, 'od-key-glyph') + '</kbd>';
  }
  function icon(name, size, tone, label) {
    tone = tone || (name === 'rec' || name === 'error' ? 'rec' : 'signal');
    return glyph(name, size || 36, 'od-icon od-icon-' + tone, label);
  }

  /* ---------- Meter and Progress ---------- */
  var DEMO_LEVELS = [3, 5, 7, 6, 8, 9, 7, 5, 4, 6, 8, 10, 8, 6, 5, 7, 9, 8, 6, 4, 3, 5, 7, 6, 4, 3, 2, 3];
  function meter() {
    var out = '';
    DEMO_LEVELS.forEach(function (lv, i) {
      for (var j = 0; j < 10; j++) {
        var on = j < lv;
        var tone = !on ? 'off' : (j >= 8 ? 'peak' : (j >= 6 ? 'warn' : 'on'));
        var top = on && j === lv - 1;
        out += '<rect x="' + i * 11 + '" y="' + (9 - j) * 11 + '" width="8" height="8" class="od-meter-' + tone + (top ? ' od-a-flicker" style="animation-delay:' + i * 60 + 'ms' : '') + '"></rect>';
      }
    });
    var w = DEMO_LEVELS.length * 11 - 3;
    return '<svg class="od-meter" viewBox="0 0 ' + w + ' 107" width="' + w + '" height="107" role="img" aria-label="Aufnahmepegel" shape-rendering="crispEdges">' + out + '</svg>';
  }
  function progress(value, n, label) {
    var filled = Math.round(value * n);
    var out = '';
    for (var i = 0; i < n; i++) {
      out += '<span class="od-progress-cell ' + (i < filled ? 'od-progress-on' : (i === filled ? 'od-progress-on od-a-blink' : 'od-progress-off')) + '"></span>';
    }
    return '<div class="od-progress" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="' + Math.round(value * 100) + '" aria-label="' + label + '">' + out + '</div>';
  }

  function render(el) {
    var d = el.dataset;
    var size = Number(d.size) || undefined;
    switch (d.od) {
      case 'blink': return blink(d.state, size, 'framed' in d, 'glow' in d);
      case 'wordmark': return wordmark(size || 48, 'still' in d);
      case 'icon': return icon(d.name, size, d.tone, d.label);
      case 'key': return keycap(d.glyph);
      case 'meter': return meter();
      case 'progress': return progress(Number(d.value), Number(d.cells), d.label);
    }
    return '';
  }
  function mount(root) {
    Array.prototype.forEach.call((root || document).querySelectorAll('[data-od]'), function (el) { el.innerHTML = render(el); });
  }

  /* ---------- Dithering (8 x 8 Bayer matrix, 3 px cells) ---------- */
  var B8 = [0, 32, 8, 40, 2, 34, 10, 42, 48, 16, 56, 24, 50, 18, 58, 26, 12, 44, 4, 36, 14, 46, 6, 38, 60, 28, 52, 20, 62, 30, 54, 22, 3, 35, 11, 43, 1, 33, 9, 41, 51, 19, 59, 27, 49, 17, 57, 25, 15, 47, 7, 39, 13, 45, 5, 37, 63, 31, 55, 23, 61, 29, 53, 21];
  function colour(el) {
    if (el._rgb) return el._rgb;
    var s = getComputedStyle(el).getPropertyValue('--' + (el.dataset.color || 'signal')).trim();
    var m = /^#([0-9a-f]{6})$/i.exec(s);
    var n = m ? parseInt(m[1], 16) : 0xB6FF4D;
    el._rgb = [(n >> 16) & 255, (n >> 8) & 255, n & 255];
    return el._rgb;
  }
  function paint(el, t, level, live) {
    var cell = 3, cw = el.clientWidth, chh = el.clientHeight;
    if (!cw || !chh) return;
    var W = Math.max(1, Math.round(cw / cell)), H = Math.max(1, Math.round(chh / cell));
    var ctx = el.getContext('2d');
    if (!ctx) return;
    if (el.width !== W || el.height !== H) { el.width = W; el.height = H; el._img = null; }
    var rgb = colour(el);
    if (!el._img) el._img = ctx.createImageData(W, H);
    var d = el._img.data, kind = el.dataset.dither;
    var L = el.dataset.level === 'live' ? live : level;
    var cx = (W - 1) / 2, cyv = (H - 1) / 2;
    var cyF = parseFloat(el.dataset.cy || '0') / cell, hwF = parseFloat(el.dataset.hw || '0') / cell;
    var R = 0.27 * H, col = null, x, y, v, i;
    if (kind === 'voice') {
      col = new Float32Array(W);
      for (x = 0; x < W; x++) {
        var u = W > 1 ? x / (W - 1) : 0.5;
        var wob = 0.55 + 0.45 * Math.sin(x * 0.55 + t * 9) * Math.sin(x * 0.13 - t * 3.1);
        col[x] = Math.max(0.6, (0.1 + 0.9 * L) * Math.sin(Math.PI * u) * wob * (cyv + 0.5) * 0.75);
      }
    }
    for (y = 0; y < H; y++) {
      for (x = 0; x < W; x++) {
        v = 0;
        if (kind === 'voice') {
          v = (col[x] - Math.abs(y - cyv)) / (col[x] * 0.6);
        } else {
          var dx = Math.max(0, Math.abs(x - cx) - hwF), dy = Math.abs(y - cyF);
          var dn = Math.sqrt(dx * dx + dy * dy) / R;
          if (dn < 1) v = L * 0.45 * (1 - dn);
        }
        i = (y * W + x) << 2;
        d[i] = rgb[0]; d[i + 1] = rgb[1]; d[i + 2] = rgb[2];
        d[i + 3] = v > (B8[((y & 7) << 3) + (x & 7)] + 0.5) / 64 ? 255 : 0;
      }
    }
    ctx.putImageData(el._img, 0, 0);
  }
  function speech(t) {
    var syl = 0.5 + 0.5 * Math.sin(t * 8.7) * Math.sin(t * 3.3 + 0.7);
    var word = Math.sin(t * 1.9) + 0.35 * Math.sin(t * 5.1);
    return Math.max(0, Math.min(1, (0.25 + 0.75 * syl) * (word > -0.55 ? 1 : 0.12)));
  }

  /* ---------- Hero stage: one dictation, looped ---------- */
  var HUD = {
    bereit: { word: 'Bereit', sub: 'fn halten' },
    hoert: { word: 'Hört zu', sub: 'REC 0:0' },
    schreibt: { word: 'Schreibt', sub: 'wird zu Text' },
    eingefuegt: { word: 'Eingefügt', sub: 'ins Textfeld' },
    hoppla: { word: 'Hoppla', sub: 'Keine Verbindung. Deine Aufnahme ist gesichert.' }
  };
  var PHASES = [['bereit', 2400], ['hoert', 4600], ['schreibt', 1800], ['eingefuegt', 3000]];
  var TOTAL = 11800;

  function stage() {
    var hud = document.querySelector('.hud');
    if (!hud) return;
    var hudBlink = hud.querySelector('.hud-blink');
    var word = hud.querySelector('.hud-word');
    var sub = hud.querySelector('.hud-sub-text');
    var recIcon = hud.querySelector('.hud-rec');
    var vis = hud.querySelectorAll('[data-show]');
    var rec = document.querySelector('.menubar-rec');
    var paste = document.querySelector('.notes-paste');
    var field = document.querySelector('canvas[data-dither="field"]');
    var steps = document.querySelectorAll('.flow-steps li');
    var shown = null, shownSecs = -1;
    var t0 = performance.now(), level = 0, live = 0, last = 0;

    function show(phase, secs) {
      if (phase !== shown) {
        shown = phase;
        hud.classList.toggle('is-open', phase !== 'bereit');
        hudBlink.innerHTML = blink(phase, 100, true);
        word.textContent = HUD[phase].word;
        recIcon.hidden = phase !== 'hoert';
        rec.hidden = phase !== 'hoert';
        paste.classList.toggle('is-pasted', phase === 'eingefuegt');
        Array.prototype.forEach.call(vis, function (el) { el.hidden = el.dataset.show !== phase; });
        Array.prototype.forEach.call(steps, function (li) { li.classList.toggle('is-on', li.dataset.phase === phase); });
        if (field) { field.dataset.cy = phase !== 'bereit' ? 176 : 38; field.dataset.hw = phase !== 'bereit' ? 290 : 110; }
      }
      if (secs !== shownSecs) {
        shownSecs = secs;
        sub.textContent = phase === 'hoert' ? 'REC 0:0' + secs : HUD[phase].sub;
      }
    }

    if (reduce) {
      show('hoert', 3);
      level = live = 0.6;
      Array.prototype.forEach.call(document.querySelectorAll('canvas[data-dither]'), function (el) { paint(el, 1.2, level, live); });
      return;
    }
    function frame(now) {
      var el = (now - t0) % TOTAL, acc = 0, phase = 'bereit', secs = 0;
      for (var i = 0; i < PHASES.length; i++) {
        if (el < acc + PHASES[i][1]) { phase = PHASES[i][0]; secs = Math.floor((el - acc) / 1000); break; }
        acc += PHASES[i][1];
      }
      show(phase, phase === 'hoert' ? secs : 0);
      var t = (now - t0) / 1000;
      level += ((phase === 'hoert' ? speech(t) : 0) - level) * 0.14;
      live += (speech(t + 2.3) - live) * 0.14;
      if (now - last >= 66) {
        last = now;
        Array.prototype.forEach.call(document.querySelectorAll('canvas[data-dither]'), function (c) {
          var r = c.getBoundingClientRect();
          if (r.bottom > 0 && r.top < window.innerHeight && !c.closest('[hidden]')) paint(c, t, level, live);
        });
      }
      raf = requestAnimationFrame(frame);
    }
    // The loop only runs while the stage is on screen, so it costs nothing further down the page.
    var raf = 0;
    if (!('IntersectionObserver' in window)) { raf = requestAnimationFrame(frame); return; }
    new IntersectionObserver(function (entries) {
      var seen = entries[entries.length - 1].isIntersecting;
      if (seen && !raf) raf = requestAnimationFrame(frame);
      else if (!seen && raf) { cancelAnimationFrame(raf); raf = 0; }
    }).observe(document.querySelector('.stage'));
  }

  /* ---------- Footer: Blink runs along while the page scrolls ---------- */
  function runner() {
    var track = document.querySelector('.run-track');
    var mover = track && track.querySelector('.run-blink');
    if (!mover) return;
    var x = 0, target = 0, dir = 1, running = false, queued = false, frame = 0, last = 0;
    mover.innerHTML = blink('bereit', 100, true);
    // Reduced motion keeps the runner still at the start of the track.
    if (reduce) return;
    function span() { return Math.max(0, track.clientWidth - 88 - 52); }
    function place() { mover.style.transform = 'translateX(' + Math.round(x) + 'px) scaleX(' + dir + ')'; }
    function stand() {
      frame = 0; last = 0;
      if (running) { running = false; mover.innerHTML = blink('bereit', 100, true); }
    }
    // Blink runs towards the scroll target instead of jumping, at most one track width per 0.6 s.
    // He only runs while the whole track is on screen: partly hidden at either edge he stands still, fully
    // hidden he takes his place unseen, so he is never cut off at the window edge mid-run.
    function step(now) {
      var r = track.getBoundingClientRect(), vh = window.innerHeight;
      if (r.top >= vh || r.bottom <= 0) { x = target; place(); stand(); return; }
      if (r.top < -1 || r.bottom > vh + 1) { stand(); return; }
      var dt = last ? Math.min(64, now - last) : 16, d = target - x, reach = Math.max(1, span()) / 600 * dt;
      var heading = d < 0 ? -1 : 1;
      last = now;
      dir = heading;
      if (!running) { running = true; mover.innerHTML = blink('schreibt', 100, true); }
      x = Math.abs(d) <= reach ? target : x + (d > 0 ? reach : -reach);
      place();
      if (x !== target) { frame = requestAnimationFrame(step); return; }
      stand();
    }
    function measure() {
      queued = false;
      var docEl = document.scrollingElement || document.documentElement;
      var vh = window.innerHeight, scrollTop = window.pageYOffset || docEl.scrollTop || 0;
      var maxScroll = Math.max(0, docEl.scrollHeight - vh);
      // The run starts only once the whole track is on screen, so Blink never runs cut off at the window edge.
      var start = Math.max(0, track.getBoundingClientRect().bottom + scrollTop - vh);
      var prog = maxScroll > start + 1 ? Math.min(1, Math.max(0, (scrollTop - start) / (maxScroll - start))) : 0;
      target = Math.round(prog * span());
      if (target !== x && !frame) frame = requestAnimationFrame(step);
    }
    function queue() { if (!queued) { queued = true; requestAnimationFrame(measure); } }
    window.addEventListener('scroll', queue, { passive: true });
    window.addEventListener('resize', queue);
    queue();
  }

  /* ---------- Explainer player: one clip at a time, chapters advance on their own ---------- */
  function kino() {
    var root = document.querySelector('.kino');
    if (!root) return;
    var video = root.querySelector('.kino-video');
    var play = root.querySelector('.kino-play');
    var sound = root.querySelector('.kino-sound');
    var items = root.querySelectorAll('.kino-list li');
    var save = navigator.connection && navigator.connection.saveData;
    // With reduced motion or data saving nothing starts until the visitor asks for it.
    var held = reduce || !!save, visible = false, withSound = false, current = 0;

    function chapter(i) { return items[i].querySelector('.kino-chapter'); }
    function start() {
      var playing = video.play();
      if (!playing) return;
      playing.catch(function () {
        // Some browsers refuse sound without a fresh tap, e.g. when the next chapter starts on its own.
        if (video.muted) return;
        setSound(false);
        select(current, video.currentTime);
      });
    }
    function setSound(on) {
      withSound = on;
      sound.setAttribute('aria-pressed', String(on));
    }
    function button() {
      play.innerHTML = glyph(video.paused ? 'play' : 'pause', 20, '');
      play.setAttribute('aria-label', video.paused ? 'Abspielen' : 'Anhalten');
    }
    function select(i, time) {
      items[current].classList.remove('is-on');
      chapter(current).removeAttribute('aria-current');
      chapter(current).querySelector('.kino-bar').style.setProperty('--p', 0);
      current = i;
      var link = chapter(i);
      items[i].classList.add('is-on');
      link.setAttribute('aria-current', 'step');
      video.poster = link.dataset.poster;
      video.src = withSound ? link.dataset.full : link.dataset.loop;
      video.muted = !withSound;
      video.setAttribute('aria-label', 'Erklärvideo: ' + link.querySelector('.kino-name').textContent);
      if (time) video.addEventListener('loadedmetadata', function () { video.currentTime = time; }, { once: true });
      if (visible && !held) start();
    }
    function fromHash() {
      for (var i = 0; i < items.length; i++) {
        if ('#' + items[i].id !== location.hash) continue;
        if (i !== current) select(i);
        // The link points at a chapter; show the whole player instead of the list row,
        // after the browser's own jump to the fragment on page load.
        if (document.readyState === 'complete') root.scrollIntoView({ block: 'center' });
        else window.addEventListener('load', function () { root.scrollIntoView({ block: 'center' }); }, { once: true });
      }
    }

    video.removeAttribute('controls');
    video.addEventListener('play', button);
    video.addEventListener('pause', button);
    video.addEventListener('ended', function () { select((current + 1) % items.length); });
    video.addEventListener('timeupdate', function () {
      var p = video.duration ? video.currentTime / video.duration : 0;
      chapter(current).querySelector('.kino-bar').style.setProperty('--p', Math.round(p * 24) / 24);
    });
    Array.prototype.forEach.call(items, function (item, i) {
      chapter(i).addEventListener('click', function (event) {
        event.preventDefault();
        held = false;
        if (i !== current) select(i);
        start();
        // On a phone the list sits below the picture; bring the picture back into view.
        if (!visible) root.querySelector('.kino-screen').scrollIntoView({ block: 'center', behavior: reduce ? 'auto' : 'smooth' });
      });
    });
    play.addEventListener('click', function () {
      held = !video.paused;
      if (held) video.pause();
      else start();
    });
    sound.addEventListener('click', function () {
      setSound(!withSound);
      held = false;
      select(current, video.currentTime);
      start();
    });
    window.addEventListener('hashchange', fromHash);
    fromHash();
    button();
    root.querySelector('.kino-tools').hidden = false;
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(function (entries) {
        visible = entries[entries.length - 1].isIntersecting;
        if (visible && !held) start();
        else if (!visible) video.pause();
      }, { threshold: 0.5 }).observe(video);
    }
  }

  document.documentElement.classList.add('js');
  mount();
  stage();
  runner();
  kino();
})();
