/* @ds-bundle: {"format":4,"namespace":"OpenDictate","components":[{"name":"Blink"},{"name":"Wordmark"},{"name":"Button"},{"name":"Keycap"},{"name":"Meter"},{"name":"Progress"},{"name":"PixelIcon"}]} */
(function () {
  var React = window.React;
  var h = React.createElement;

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

  function Blink(props) {
    var state = props.state || 'bereit';
    var sc = scene(state);
    var box = props.framed ? '0 0 44 50' : sc.box;
    var vbw = parseFloat(box.split(' ')[2]);
    var height = props.size || 200;
    var width = Math.round(height * vbw / 50);
    var cls = 'od-blink' + (props.still ? ' od-still' : '') + (props.glow ? ' od-glow' : '') + (props.className ? ' ' + props.className : '');
    return h('svg', { className: cls, viewBox: box, width: width, height: height, role: 'img', 'aria-label': props.label || ('Blink ' + (LABELS[state] || 'bereit')), shapeRendering: 'crispEdges' },
      sc.layers.map(function (l, i) {
        return h('g', { key: i, className: l.cls || undefined }, l.cells.map(function (c, j) {
          var a = ANIM[c.ch];
          return h('rect', { key: j, x: c.x, y: c.y, width: c.w, height: 1, className: 'od-px-' + c.ch + (a ? ' ' + a[0] : ''), style: a && a[1] ? { animationDelay: a[1] + 's' } : undefined });
        }));
      }));
  }

  /* ---------- Wordmark ---------- */
  var B32 = [[12, 1, 1, 1, 'L'], [13, 1, 6, 1, 'B'], [19, 1, 1, 1, 'S'], [11, 2, 2, 18, 'L'], [13, 2, 6, 18, 'B'], [19, 2, 2, 18, 'S'], [12, 20, 1, 1, 'L'], [13, 20, 6, 1, 'B'], [19, 20, 1, 1, 'S']];
  var B32LEGS = [[12, 21, 2, 6, 'K'], [18, 21, 2, 6, 'K'], [9, 26, 5, 2, 'W'], [9, 28, 5, 1, 'G'], [18, 26, 5, 2, 'W'], [18, 28, 5, 1, 'G']];
  function cells(list) { return list.map(function (c, i) { return h('rect', { key: i, x: c[0], y: c[1], width: c[2], height: c[3], className: 'od-px-' + c[4] }); }); }
  function Wordmark(props) {
    var size = props.size || 48;
    return h('span', { className: 'od-wordmark' + (props.still ? ' od-still' : ''), style: { fontSize: size + 'px' }, role: 'img', 'aria-label': 'opendictate' },
      h('span', { 'aria-hidden': 'true' }, 'opendictate'),
      h('svg', { className: 'od-wordmark-blink', viewBox: '9 1 14 29', 'aria-hidden': 'true', shapeRendering: 'crispEdges' },
        h('g', { className: 'od-a-body' }, cells(B32)), cells(B32LEGS)));
  }

  /* ---------- Button ---------- */
  function Button(props) {
    var variant = props.variant || 'primary';
    var rest = {};
    for (var k in props) if (k !== 'variant' && k !== 'className' && k !== 'children') rest[k] = props[k];
    rest.className = 'od-btn od-btn-' + variant + (props.className ? ' ' + props.className : '');
    if (!rest.type) rest.type = 'button';
    return h('button', rest, h('span', { className: 'od-btn-label' }, props.children));
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
    prompt: [BL, BL, '...XX.......', '....XX......', '.....XX.....', '......XX....', '.....XX.....', '....XX......', '...XX.......', BL, BL, BL]
  };
  function glyphRects(name) {
    var rows = GLYPHS[name] || GLYPHS.prompt, out = [];
    rows.forEach(function (row, y) {
      var x = 0;
      while (x < 12) {
        if (row[x] === 'X') { var w = 1; while (x + w < 12 && row[x + w] === 'X') w++; out.push(h('rect', { key: y + '-' + x, x: x, y: y, width: w, height: 1 })); x += w; } else x++;
      }
    });
    return out;
  }
  function glyph(name, size, cls, label) {
    return h('svg', { className: cls, viewBox: '0 0 12 12', width: size, height: size, shapeRendering: 'crispEdges', role: label ? 'img' : undefined, 'aria-label': label || undefined, 'aria-hidden': label ? undefined : 'true' }, glyphRects(name));
  }

  /* ---------- Keycap ---------- */
  var KEY_LABELS = { option: 'Wahltaste', shift: 'Umschalttaste', space: 'Leertaste' };
  function Keycap(props) {
    var g = props.glyph || 'option';
    return h('kbd', { className: 'od-key od-key-' + g, 'aria-label': KEY_LABELS[g] || g, title: KEY_LABELS[g] || g }, glyph(g, 36, 'od-key-glyph'));
  }

  /* ---------- Meter ---------- */
  var DEMO_LEVELS = [3, 5, 7, 6, 8, 9, 7, 5, 4, 6, 8, 10, 8, 6, 5, 7, 9, 8, 6, 4, 3, 5, 7, 6, 4, 3, 2, 3];
  function Meter(props) {
    var levels = props.levels || DEMO_LEVELS;
    var live = props.live !== false;
    var rects = [];
    levels.forEach(function (lv, i) {
      for (var j = 0; j < 10; j++) {
        var on = j < lv;
        var tone = !on ? 'off' : (j >= 8 ? 'peak' : (j >= 6 ? 'warn' : 'on'));
        var top = on && j === lv - 1 && live;
        rects.push(h('rect', { key: i + '-' + j, x: i * 11, y: (9 - j) * 11, width: 8, height: 8, className: 'od-meter-' + tone + (top ? ' od-a-flicker' : ''), style: top ? { animationDelay: (i * 60) + 'ms' } : undefined }));
      }
    });
    var w = levels.length * 11 - 3;
    return h('svg', { className: 'od-meter', viewBox: '0 0 ' + w + ' 107', width: w, height: 107, role: 'img', 'aria-label': props.label || 'Aufnahmepegel', shapeRendering: 'crispEdges' }, rects);
  }

  /* ---------- Progress ---------- */
  function Progress(props) {
    var n = props.cells || 14;
    var v = Math.max(0, Math.min(1, props.value == null ? 0.65 : props.value));
    var filled = Math.round(v * n);
    var busy = props.busy !== false && filled < n;
    var cellsOut = [];
    for (var i = 0; i < n; i++) {
      var cls = i < filled ? 'od-progress-on' : (busy && i === filled ? 'od-progress-on od-a-blink' : 'od-progress-off');
      cellsOut.push(h('span', { key: i, className: 'od-progress-cell ' + cls }));
    }
    return h('div', { className: 'od-progress', role: 'progressbar', 'aria-valuemin': 0, 'aria-valuemax': 100, 'aria-valuenow': Math.round(v * 100), 'aria-label': props.label || 'Fortschritt' }, cellsOut);
  }

  /* ---------- PixelIcon ---------- */
  var ICON_LABELS = { rec: 'Aufnahme', check: 'Eingefügt', error: 'Fehler', prompt: 'Eingabe' };
  function PixelIcon(props) {
    var name = props.name || 'prompt';
    var tone = props.tone || (name === 'rec' || name === 'error' ? 'rec' : 'signal');
    return glyph(name, props.size || 36, 'od-icon od-icon-' + tone, props.label === undefined ? ICON_LABELS[name] : props.label);
  }

  var api = { Blink: Blink, Wordmark: Wordmark, Button: Button, Keycap: Keycap, Meter: Meter, Progress: Progress, PixelIcon: PixelIcon };
  window.OpenDictate = window.OpenDictate || {};
  for (var key in api) window.OpenDictate[key] = api[key];
})();
