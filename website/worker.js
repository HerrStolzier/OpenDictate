// Cloudflare Worker that serves this folder on opendictate.app.
// It serves the files of one pinned commit: each file is fetched once from
// that commit on GitHub, checked against its SHA-256 prefix, kept in the SITE
// KV namespace and served from there. Visitors never contact GitHub.
// Update COMMIT and FILES with `python3 scripts/website-worker.py <commit>`.

const COMMIT = "87cec8b5d50918d0585a5f6175618062c97a7dda";
const FILES = {
  "/blink-32.svg": "8f8d4b92a787c76c86e3fbd372ba7f4d",
  "/fonts/Geist-Regular.woff2": "be82b88cfc92b5d4d697141631cf1607",
  "/fonts/Geist-SemiBold.woff2": "7dc4a82da115c2d16ccb19a22ffdb32b",
  "/fonts/GeistMono-Regular.woff2": "0a35a4b44c251cfb15a1040a1cc30179",
  "/fonts/GeistMono-SemiBold.woff2": "9fc2d14841f1a53d23541c63643c9910",
  "/fonts/GeistPixel-Regular.woff2": "70b4b492ee459c69c61cedfa05380e54",
  "/fonts/OFL.txt": "1781d2806a07d91c4edf4740b88449fa",
  "/index.html": "72041e7f25b044f15a69150125fc54f9",
  "/site.js": "3437a996d809485787825e5df549c508",
  "/style.css": "768ab687c06978537a452e69006cf1b3",
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

async function load(env, path, hash) {
  if (loaded.has(path)) return loaded.get(path);
  let body = await env.SITE.get(path, "arrayBuffer");
  if (!body || (await digest(body)) !== hash) {
    const response = await fetch(SOURCE + path);
    if (!response.ok) throw new Error(`source ${response.status} for ${path}`);
    body = await response.arrayBuffer();
    if ((await digest(body)) !== hash) throw new Error(`hash mismatch for ${path}`);
    // KV allows one write per key and second; a lost race must not cost the visitor the file.
    try {
      await env.SITE.put(path, body);
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
    const headers = { ...SECURITY, "content-type": type, "cache-control": `public, max-age=${maxAge}`, etag };
    if (matches(request.headers.get("if-none-match"), etag)) return new Response(null, { status: 304, headers });
    let body;
    try {
      body = await load(env, path, hash);
    } catch (error) {
      console.error(String(error));
      return plain(503, "Gerade nicht erreichbar, bitte später erneut versuchen.", { "retry-after": "60" });
    }
    return new Response(request.method === "HEAD" ? null : body, { headers });
  },
};
