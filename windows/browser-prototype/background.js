'use strict';
const host = 'de.opendictate.prototype';
let port = null;
let connecting = false;
const captures = new Map();

async function activeTab() {
  const [tab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
  if (!tab?.id) throw Error('inactive_browser');
  const window = await chrome.windows.get(tab.windowId);
  if (!window.focused) throw Error('inactive_browser');
  return tab;
}
async function capture() {
  captures.clear();
  const tab = await activeTab();
  await chrome.scripting.executeScript({
    target: { tabId: tab.id, allFrames: true }, files: ['insertion-core.js', 'content.js']
  });
  // Only frames whose isolated content context has an editable focus can match.
  const values = await chrome.scripting.executeScript({
    target: { tabId: tab.id, allFrames: true },
    func: () => globalThis.OpenDictateBrowserSession?.capture() ?? { ok: false }
  });
  const matches = values.filter(value => value.result?.ok === true && value.documentId);
  if (matches.length !== 1) return { ok: false, reason: 'ambiguous_or_unsupported_target' };
  const match = matches[0];
  const token = crypto.randomUUID();
  captures.set(token, { tabId: tab.id, windowId: tab.windowId, documentId: match.documentId,
    innerToken: match.result.token, expires: Date.now() + 120000 });
  return { ok: true, token, kind: match.result.kind };
}
async function insert(token, text) {
  const capture = captures.get(token);
  captures.delete(token); // Consume before any asynchronous delivery.
  if (!capture || Date.now() >= capture.expires) return { ok: false, reason: 'stale_request' };
  const tab = await activeTab();
  if (tab.id !== capture.tabId || tab.windowId !== capture.windowId) return { ok: false, reason: 'target_changed' };
  return await chrome.tabs.sendMessage(capture.tabId, { type: 'opendictate-insert', token: capture.innerToken, text },
    { documentId: capture.documentId });
}
async function receive(message, currentPort) {
  if (message?.protocol !== 1 || typeof message.id !== 'string' || message.id.length > 64 ||
      !['capture', 'insert', 'cancel'].includes(message.type)) return;
  let response;
  try {
    if (message.type === 'capture') response = await capture();
    if (message.type === 'insert') {
      if (typeof message.text !== 'string' || message.text.length > 16000) response = { ok: false, reason: 'invalid_text' };
      else response = await insert(message.token, message.text);
    }
    if (message.type === 'cancel') { captures.delete(message.token); response = { ok: true }; }
  } catch {
    response = { ok: false, reason: message.type === 'insert' ? 'delivery_uncertain' : 'unsupported_or_disconnected' };
  }
  if (port === currentPort) {
    try { currentPort.postMessage({ type: 'response', protocol: 1, id: message.id, ...response }); } catch { }
  }
}
function connect() {
  if (port || connecting) return;
  connecting = true;
  try {
    const candidate = chrome.runtime.connectNative(host);
    port = candidate;
    candidate.onMessage.addListener(message => { void receive(message, candidate); });
    candidate.onDisconnect.addListener(() => {
      void chrome.runtime.lastError; // Do not log protocol payloads or page content.
      if (port === candidate) { port = null; captures.clear(); }
      void chrome.action.setBadgeText({ text: '–' });
    });
    void chrome.action.setBadgeText({ text: '' });
  } finally { connecting = false; }
}
chrome.runtime.onInstalled.addListener(connect);
chrome.runtime.onStartup.addListener(connect);
chrome.action.onClicked.addListener(connect);
chrome.windows.onFocusChanged.addListener(id => { if (id !== chrome.windows.WINDOW_ID_NONE) connect(); });
