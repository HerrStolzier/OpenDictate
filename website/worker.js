// Cloudflare Worker that serves this folder on opendictate.app.
// It serves the files of one pinned commit: each file is fetched once from
// that commit on GitHub, checked against its SHA-256 prefix, kept in the SITE
// KV namespace and served from there. Visitors never contact GitHub.
// Update COMMIT and FILES with `python3 scripts/website-worker.py <commit>`.

const COMMIT = "5c8bffe7e6cc9f9d585e3b3cf5b9a93a7fbbdbe4";
const FILES = {
  "/apple-touch-icon.png": "017aca3eeebd83164aedace3bca37977",
  "/blink-32.svg": "8f8d4b92a787c76c86e3fbd372ba7f4d",
  "/fonts/Geist-Regular.woff2": "be82b88cfc92b5d4d697141631cf1607",
  "/fonts/Geist-SemiBold.woff2": "7dc4a82da115c2d16ccb19a22ffdb32b",
  "/fonts/GeistMono-Regular.woff2": "0a35a4b44c251cfb15a1040a1cc30179",
  "/fonts/GeistMono-SemiBold.woff2": "9fc2d14841f1a53d23541c63643c9910",
  "/fonts/GeistPixel-Regular.woff2": "70b4b492ee459c69c61cedfa05380e54",
  "/fonts/OFL.txt": "1781d2806a07d91c4edf4740b88449fa",
  "/index.html": "c125c905fe722dc58736c67c6f6a9d9f",
  "/og.png": "a2c85a77e0fbea4381edc54218f36570",
  "/robots.txt": "3fb85fe309acd473d6be9a95d46879e4",
  "/site.js": "f25b1ef32cd6bf463db942107078dafd",
  "/sitemap.xml": "cfec2b8f97737de1b60c7699e5a23378",
  "/style.css": "2cbd0046b0c31aab56b73022c7e433c9",
  "/tokens.css": "ded977b1cea80720ca8fb091c7ba90ec",
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
};

const SECURITY = {
  "content-security-policy":
    "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; " +
    "font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'none'; frame-ancestors 'none'",
  "x-content-type-options": "nosniff",
  "referrer-policy": "strict-origin-when-cross-origin",
  "permissions-policy": "camera=(), microphone=(), geolocation=()",
  "strict-transport-security": "max-age=31536000",
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
    const path = url.pathname === "/" ? "/index.html" : url.pathname;
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
