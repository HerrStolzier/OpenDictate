// Cloudflare Worker that serves this folder on opendictate.app.
// It serves the files of one pinned commit: each file is fetched once from
// that commit on GitHub, checked against its SHA-256 prefix, kept in the SITE
// KV namespace and served from there. Visitors never contact GitHub.
// Update COMMIT and FILES with `python3 scripts/website-worker.py <commit>`.

const COMMIT = "db8a170ac13b2ff486f39651cb2a8358f612aa8c";
const FILES = {
  "/anleitungen.html": "a0c2d983e0bf6f9b7360b584534f17a3",
  "/apple-touch-icon.png": "017aca3eeebd83164aedace3bca37977",
  "/blink-32.svg": "8f8d4b92a787c76c86e3fbd372ba7f4d",
  "/en/guides.html": "020287e086efa6b3327aa2a73321264b",
  "/en/index.html": "62c800df3af8f3c1647bde7f27cbff6b",
  "/es/index.html": "2a06adc475864ed9074cb41dd2ddfdcb",
  "/es/tutoriales.html": "d81fc7d5d05407143b75368fa2afc860",
  "/fonts/Geist-Regular.woff2": "be82b88cfc92b5d4d697141631cf1607",
  "/fonts/Geist-SemiBold.woff2": "7dc4a82da115c2d16ccb19a22ffdb32b",
  "/fonts/GeistMono-Regular.woff2": "0a35a4b44c251cfb15a1040a1cc30179",
  "/fonts/GeistMono-SemiBold.woff2": "9fc2d14841f1a53d23541c63643c9910",
  "/fonts/GeistPixel-Regular.woff2": "70b4b492ee459c69c61cedfa05380e54",
  "/fonts/OFL.txt": "1781d2806a07d91c4edf4740b88449fa",
  "/fr/index.html": "b534e638a36d1085ec3a848f5827f5a2",
  "/fr/tutoriels.html": "d14285d7c487efcf607a3d973004bda8",
  "/index.html": "777a4f2b85669029e5ec057471bdae97",
  "/it/index.html": "667c6d284a41377cdbfa0b702619a33a",
  "/it/tutorial.html": "4efc98d82a1c6bc9c73ce14fdf16f59d",
  "/nl/index.html": "e212e5a50da7e707723e8818d78f5584",
  "/nl/uitleg.html": "33ad3e2b60df576acf9dbdc5c0db9940",
  "/og.png": "a2c85a77e0fbea4381edc54218f36570",
  "/pl/index.html": "9435bf76160ddbf63b05bf3bff276f77",
  "/pl/poradniki.html": "9fa25caab582b7efffb974079dab02ba",
  "/pt/index.html": "c562ce3a963d7b4f36467adae25965ec",
  "/pt/tutoriais.html": "59e2d15054f96ed738af1124c44cebae",
  "/robots.txt": "3fb85fe309acd473d6be9a95d46879e4",
  "/site.js": "1249b1284e6458f066fe9a18098e6f3e",
  "/sitemap.xml": "4238d565fcfc1a77a9052799a28aeaa1",
  "/style.css": "1622f756217cfa2076514f772c4f9333",
  "/tokens.css": "ded977b1cea80720ca8fb091c7ba90ec",
  "/videos/blink-01-so-diktierst-du-schleife.mp4": "d9f77f553aa7cca24b65c548cd574b13",
  "/videos/blink-01-so-diktierst-du.en.vtt": "6ccd149ac138b6522a159b7af14f9b95",
  "/videos/blink-01-so-diktierst-du.es.vtt": "7c327fae83d35441cf5d74d02937d46a",
  "/videos/blink-01-so-diktierst-du.fr.vtt": "7b2e94fb4edb910766273681747633c9",
  "/videos/blink-01-so-diktierst-du.it.vtt": "4bad8b3f23ce3d3d3e4708b910ad30c8",
  "/videos/blink-01-so-diktierst-du.jpg": "da67768f4d06536978cf9eaa9b6eb6ab",
  "/videos/blink-01-so-diktierst-du.mp4": "e7b9e9f758bc10ae3f0b1348b2ccf2bc",
  "/videos/blink-01-so-diktierst-du.nl.vtt": "5aca514f6997259b0873887eee161ebc",
  "/videos/blink-01-so-diktierst-du.pl.vtt": "501e0db234295b7a4a9299997fac1239",
  "/videos/blink-01-so-diktierst-du.pt.vtt": "cdc257800a1adda2215e9b162336b0a4",
  "/videos/blink-01-so-diktierst-du.vtt": "107d50f4733e8943786a7d2dc8c9ef12",
  "/videos/blink-01-so-diktierst-du.webp": "782c24cf9ecbd59eca838960cceb8111",
  "/videos/blink-02-kostenlos-schleife.mp4": "2f0bb8f13f94f6e02b89dad2e1acd319",
  "/videos/blink-02-kostenlos.en.vtt": "169d2042534a8338b3d649748e81cb8d",
  "/videos/blink-02-kostenlos.es.vtt": "d8df8ad988225b958e288b9c2dd7ee8c",
  "/videos/blink-02-kostenlos.fr.vtt": "f3d698010163cbb9782b6b72b4b39890",
  "/videos/blink-02-kostenlos.it.vtt": "50badb6ddf08412597f3d371ad947b41",
  "/videos/blink-02-kostenlos.jpg": "83bef79c3e96faaa36faa2d528f6168a",
  "/videos/blink-02-kostenlos.mp4": "1b09e563bec67bc366ec22f7bf690cb4",
  "/videos/blink-02-kostenlos.nl.vtt": "a9565c0d9cbd6d41fa19f1c7baed9b7f",
  "/videos/blink-02-kostenlos.pl.vtt": "3186cfca2522ddbb9df9ed94733facb9",
  "/videos/blink-02-kostenlos.pt.vtt": "61935f9b25328fcb3111cc7edc2a1474",
  "/videos/blink-02-kostenlos.vtt": "c62ab7df05d7d7dbf20803b5abaec14d",
  "/videos/blink-02-kostenlos.webp": "5a009bfaad9b8cac669ec3149970c003",
  "/videos/blink-03-uebersetzen-schleife.mp4": "dcf408d64362fda6aa2ebf3cd184daeb",
  "/videos/blink-03-uebersetzen.en.vtt": "8b472de7ef21e69fe4444c9683c9d8dd",
  "/videos/blink-03-uebersetzen.es.vtt": "73891e909b59d883526d18bcb733b5b6",
  "/videos/blink-03-uebersetzen.fr.vtt": "d3e25e6f02f3bcc7e686c4fad0343334",
  "/videos/blink-03-uebersetzen.it.vtt": "1daa59a08a8bd72334bf08a8666aef03",
  "/videos/blink-03-uebersetzen.jpg": "a3b6669cc6d13496ca08dbcfe7c5fe76",
  "/videos/blink-03-uebersetzen.mp4": "f07053ab218beaf77f27aba688d3f9dd",
  "/videos/blink-03-uebersetzen.nl.vtt": "369404ef29e114e2121d80aa8a23fbde",
  "/videos/blink-03-uebersetzen.pl.vtt": "29e14022e87b71a439065314fc1af6c3",
  "/videos/blink-03-uebersetzen.pt.vtt": "7968be8b1f9dd5577b0d2953867d13ea",
  "/videos/blink-03-uebersetzen.vtt": "8545e0741d2f2eb980de49be276bd3e1",
  "/videos/blink-03-uebersetzen.webp": "2a3468a062fa9ae4081edfae8f47a15a",
  "/videos/blink-04-nichts-geht-verloren-schleife.mp4": "94df556eaead64e0fff2473fdfe18c56",
  "/videos/blink-04-nichts-geht-verloren.en.vtt": "2482a9abc3d1546f42009f539e2d027e",
  "/videos/blink-04-nichts-geht-verloren.es.vtt": "96763d91e6bfef5e962463a4c250a268",
  "/videos/blink-04-nichts-geht-verloren.fr.vtt": "93721d71f566cee7f48429688d8ecda1",
  "/videos/blink-04-nichts-geht-verloren.it.vtt": "cff95205019c454eb4546bc6a22a9732",
  "/videos/blink-04-nichts-geht-verloren.jpg": "f954b7378f4ae48d7a1952bb975360ac",
  "/videos/blink-04-nichts-geht-verloren.mp4": "fef28b2a486afc648ae6285af080e181",
  "/videos/blink-04-nichts-geht-verloren.nl.vtt": "4e5c3731b4a97a4af947aac9c92aeaa6",
  "/videos/blink-04-nichts-geht-verloren.pl.vtt": "abdb2f458d01b9bc36a1095e15ca15a5",
  "/videos/blink-04-nichts-geht-verloren.pt.vtt": "abc70dfc80eb0b62101ad65979eae549",
  "/videos/blink-04-nichts-geht-verloren.vtt": "c1a0b24087bdd90f6944f598d0254e43",
  "/videos/blink-04-nichts-geht-verloren.webp": "d9c376d1838742ed6beca9fe034c6478",
  "/videos/blink-05-erste-schritte-schleife.mp4": "2ea3a5abe39968ffa483b7a1f0e314b3",
  "/videos/blink-05-erste-schritte.en.vtt": "bebc9730701e2e19c165fed8cff59805",
  "/videos/blink-05-erste-schritte.es.vtt": "eb52056cb25c4e541818de72c977f7bc",
  "/videos/blink-05-erste-schritte.fr.vtt": "52c6c046bc125146b629fd7fd88abc71",
  "/videos/blink-05-erste-schritte.it.vtt": "4f1ce98b45a8b3812e715b3665289d4c",
  "/videos/blink-05-erste-schritte.jpg": "6ca2f464ef11cf320f15f9e0a3f489de",
  "/videos/blink-05-erste-schritte.mp4": "369f6ed7890e6a722de9521a1e9e5e62",
  "/videos/blink-05-erste-schritte.nl.vtt": "568c4fd78575e2f2b36163ed68210dad",
  "/videos/blink-05-erste-schritte.pl.vtt": "5ce7b310bea8bee174220cbfa2fc982b",
  "/videos/blink-05-erste-schritte.pt.vtt": "4c08ab291d0b8fa2cae89070c8e3c531",
  "/videos/blink-05-erste-schritte.vtt": "faae478f784557e93844ed259ad9e91b",
  "/videos/blink-05-erste-schritte.webp": "264c0e54dcbd51f0215c654190dea198",
};

const HOST = "opendictate.app";
const SOURCE = `https://raw.githubusercontent.com/HerrStolzier/OpenDictate/${COMMIT}/website`;

// Content type and browser cache lifetime in seconds per file extension.
// HTML, CSS and JS share one short lifetime because their names carry no hash.
// Keep the extensions in step with SERVED_TYPES in scripts/website-worker.py.
const KINDS = {
  html: ["text/html; charset=utf-8", 300],
  css: ["text/css; charset=utf-8", 300],
  js: ["text/javascript; charset=utf-8", 300],
  svg: ["image/svg+xml", 86400],
  woff2: ["font/woff2", 86400],
  txt: ["text/plain; charset=utf-8", 86400],
  png: ["image/png", 86400],
  xml: ["application/xml; charset=utf-8", 300],
  jpg: ["image/jpeg", 86400],
  mp4: ["video/mp4", 86400],
  webp: ["image/webp", 86400],
  vtt: ["text/vtt; charset=utf-8", 300],
};

// Styles come only from style.css and the CSSOM in site.js; no style attributes.
// Every opendictate.app host in use (the site, www, support) answers over HTTPS,
// so HSTS covers the subdomains; preload is not requested.
const SECURITY = {
  "content-security-policy":
    "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; " +
    "font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'none'; frame-ancestors 'none'; " +
    "upgrade-insecure-requests",
  "cross-origin-opener-policy": "same-origin",
  "cross-origin-resource-policy": "same-site",
  "x-content-type-options": "nosniff",
  "referrer-policy": "strict-origin-when-cross-origin",
  "permissions-policy": "camera=(), microphone=(), geolocation=()",
  "strict-transport-security": "max-age=63072000; includeSubDomains",
};

const loaded = new Map();

async function digest(body) {
  const bytes = new Uint8Array(await crypto.subtle.digest("SHA-256", body));
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("").slice(0, 32);
}

// A KV entry carries the hash it was verified against as metadata, so a read
// costs no rehash; that matters for the videos, which are several megabytes.
async function load(env, path, hash) {
  if (loaded.has(path)) return loaded.get(path);
  let { value: body, metadata } = await env.SITE.getWithMetadata(path, "arrayBuffer");
  if (!body || metadata?.hash !== hash) {
    const response = await fetch(SOURCE + path);
    if (!response.ok) throw new Error(`source ${response.status} for ${path}`);
    body = await response.arrayBuffer();
    if ((await digest(body)) !== hash) throw new Error(`hash mismatch for ${path}`);
    // KV allows one write per key and second; a lost race must not cost the visitor the file.
    try {
      await env.SITE.put(path, body, { metadata: { hash } });
    } catch (error) {
      console.error(`kv put ${path}: ${error}`);
    }
  }
  loaded.set(path, body);
  return body;
}

// True when an If-None-Match header names this ETag, also as a weak ETag.
function matches(header, etag) {
  return (header ?? "").split(",").some((tag) => tag.trim().replace(/^W\//, "") === etag || tag.trim() === "*");
}

// Resolves a Range header against a file of `size` bytes: null serves the whole
// file, false is unsatisfiable, otherwise the inclusive byte span. Safari plays
// video only when the server answers ranges. Multiple ranges get the whole file.
function byteRange(header, size) {
  const match = /^bytes=(\d*)-(\d*)$/.exec((header ?? "").trim());
  if (!match || (match[1] === "" && match[2] === "")) return null;
  let start;
  let end;
  if (match[1] === "") {
    const suffix = Number(match[2]);
    if (suffix === 0) return false;
    start = Math.max(0, size - suffix);
    end = size - 1;
  } else {
    start = Number(match[1]);
    end = match[2] === "" ? size - 1 : Math.min(Number(match[2]), size - 1);
    if (start > end || start >= size) return false;
  }
  return { start, end };
}

function plain(status, text, extra = {}) {
  const headers = { ...SECURITY, "content-type": "text/plain; charset=utf-8", ...extra };
  return new Response(text, { status, headers });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.hostname !== HOST) {
      url.hostname = HOST;
      return Response.redirect(url.toString(), 301);
    }
    if (request.method !== "GET" && request.method !== "HEAD") {
      return plain(405, "Methode nicht erlaubt", { allow: "GET, HEAD" });
    }
    // Each language lives in its own folder, e.g. /en/ for /en/index.html.
    if (Object.hasOwn(FILES, `${url.pathname}/index.html`)) {
      url.pathname += "/";
      return Response.redirect(url.toString(), 301);
    }
    const path = url.pathname.endsWith("/") ? `${url.pathname}index.html` : url.pathname;
    const hash = Object.hasOwn(FILES, path) ? FILES[path] : null;
    if (!hash) return plain(404, "Nicht gefunden");
    const [type, maxAge] = KINDS[path.split(".").pop()];
    const etag = `"${hash}"`;
    const headers = {
      ...SECURITY,
      "content-type": type,
      "cache-control": `public, max-age=${maxAge}`,
      etag,
      "accept-ranges": "bytes",
    };
    if (matches(request.headers.get("if-none-match"), etag)) return new Response(null, { status: 304, headers });
    let body;
    try {
      body = await load(env, path, hash);
    } catch (error) {
      console.error(String(error));
      return plain(503, "Gerade nicht erreichbar, bitte später erneut versuchen.", { "retry-after": "60" });
    }
    const ifRange = request.headers.get("if-range");
    const range = ifRange === null || ifRange === etag ? byteRange(request.headers.get("range"), body.byteLength) : null;
    if (range === false) {
      return new Response(null, { status: 416, headers: { ...headers, "content-range": `bytes */${body.byteLength}` } });
    }
    if (range) {
      const part = body.slice(range.start, range.end + 1);
      headers["content-range"] = `bytes ${range.start}-${range.end}/${body.byteLength}`;
      headers["content-length"] = String(part.byteLength);
      return new Response(request.method === "HEAD" ? null : part, { status: 206, headers });
    }
    return new Response(request.method === "HEAD" ? null : body, { headers });
  },
};
