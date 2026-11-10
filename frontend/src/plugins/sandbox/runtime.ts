// What runs inside a sandboxed plugin's iframe, ahead of the plugin's own
// code: a CSP that cuts the frame off from the network, and the `mudnight`
// SDK global, which is the plugin's only line to the host. The host side is
// SandboxedPlugin.tsx; the protocol is documented in docs/plugins.md.
//
// The iframe runs with sandbox="allow-scripts" and no allow-same-origin, so
// its origin is opaque: it can't read Mudnight's cookies, storage or DOM.

// default-src 'none' blocks fetch/XHR/WebSocket, remote scripts, images,
// fonts and media, so a plugin can't phone home. Inline code and data:/blob:
// assets still work, and 'wasm-unsafe-eval' lets plugins compiled from Rust,
// Go, C and friends instantiate WebAssembly.
export const PLUGIN_CSP = [
  "default-src 'none'",
  "script-src 'unsafe-inline' 'wasm-unsafe-eval'",
  "style-src 'unsafe-inline'",
  "img-src data: blob:",
  "font-src data:",
  "media-src data: blob:",
].join("; ");

export const SDK_VERSION = 1;

// Kept as plain ES5-ish source so it runs before (and regardless of) whatever
// the plugin was compiled to.
const SDK_SOURCE = `(function () {
  var VERSION = ${SDK_VERSION};
  var ctx = null, seq = 0, pending = {}, listeners = {}, readyQueue = [];

  function send(msg) { msg.__mudnight = VERSION; parent.postMessage(msg, "*"); }

  function emit(event, data) {
    (listeners[event] || []).slice().forEach(function (fn) {
      try { fn(data); } catch (e) { console.error("[plugin] " + event + " handler failed", e); }
    });
  }

  function request(method, params) {
    return new Promise(function (resolve, reject) {
      var id = ++seq;
      pending[id] = { resolve: resolve, reject: reject };
      send({ type: "request", id: id, method: method, params: params || {} });
    });
  }

  window.addEventListener("message", function (e) {
    if (e.source !== parent) return;
    var m = e.data;
    if (!m || m.__mudnight !== VERSION) return;
    if (m.type === "init") {
      ctx = m.context;
      readyQueue.splice(0).forEach(function (fn) { fn(ctx); });
    } else if (m.type === "event" && ctx) {
      if (m.event === "settings") ctx.settings = m.data;
      if (m.event === "channel") ctx.channel = m.data;
      if (m.event === "active") ctx.active = m.data;
      if (m.event === "reducedMotion") ctx.reducedMotion = m.data;
      emit(m.event, m.data);
    } else if (m.type === "response") {
      var p = pending[m.id];
      if (!p) return;
      delete pending[m.id];
      if (m.error) p.reject(new Error(m.error)); else p.resolve(m.result);
    }
  });

  window.addEventListener("error", function (e) { send({ type: "error", message: String(e.message || e) }); });

  window.mudnight = Object.freeze({
    version: VERSION,
    get context() { return ctx; },
    ready: function (fn) {
      return new Promise(function (resolve) {
        var run = function (c) { if (fn) fn(c); resolve(c); };
        if (ctx) run(ctx); else readyQueue.push(run);
      });
    },
    on: function (event, fn) {
      (listeners[event] = listeners[event] || []).push(fn);
      return function () { listeners[event] = (listeners[event] || []).filter(function (f) { return f !== fn; }); };
    },
    resize: function (height) { send({ type: "resize", height: Number(height) || 0 }); },
    storage: Object.freeze({
      get: function (key) { return request("storage.get", { key: key }); },
      set: function (key, value) { return request("storage.set", { key: key, value: value }); },
      remove: function (key) { return request("storage.remove", { key: key }); }
    })
  });

  send({ type: "hello" });
})();`;

// "</script" or "<!--" inside the plugin's code would end or comment out the
// inline <script> early. Escaping the slash / bang keeps the JS meaning the
// same in strings, regexes and comments (the same trick bundlers use when
// inlining).
function inlineScript(code: string): string {
  return code.replace(/<\/(script)/gi, "<\\/$1").replace(/<!--/g, "<\\!--");
}

export function buildSrcdoc(code: string): string {
  return `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="${PLUGIN_CSP}">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>html,body{margin:0;padding:0;background:transparent;color:#fff;font-family:system-ui,sans-serif;overflow:hidden}</style>
<script>${SDK_SOURCE}</script>
</head>
<body>
<script>${inlineScript(code)}</script>
</body>
</html>`;
}
