/* Prototype for an isolated browser-extension content script. No networking,
   storage, clipboard access or provider calls. Target text stays in this frame. */
(() => {
  'use strict';
  if (globalThis.OpenDictateInsertion) return;
  // Match the extension-side ticket: 90 s recording + 60 s provider timeout
  // plus 30 s for preparation and delivery.
  const defaultMaxAgeMs = 180000;
  function create({ document: doc = document, now = () => performance.now(), maxAgeMs = defaultMaxAgeMs } = {}) {
    const win = doc.defaultView;
    let current = null;
    let delivering = false;
    let expiryTimer = null;
    function forget() { current = null; win.clearTimeout(expiryTimer); expiryTimer = null; }
    const listeners = [];
    function listen(object, name, callback) {
      object.addEventListener(name, callback, true);
      listeners.push(() => object.removeEventListener(name, callback, true));
    }
    function supported(element) {
      if (!element?.isConnected || element.ownerDocument !== doc ||
          element.getAttribute('aria-disabled') === 'true' ||
          element.getAttribute('aria-readonly') === 'true') return false;
      if (element instanceof win.HTMLTextAreaElement) return !element.disabled && !element.readOnly;
      if (element instanceof win.HTMLInputElement)
        return ['text', 'search', 'url', 'tel'].includes(element.type) && !element.disabled && !element.readOnly;
      return element.isContentEditable;
    }
    function sameSelection(ticket) {
      const element = ticket.element;
      if (ticket.kind === 'plain') return element.selectionStart === ticket.start &&
        element.selectionEnd === ticket.end && element.selectionDirection === ticket.direction;
      const selection = doc.getSelection();
      if (selection?.rangeCount !== 1) return false;
      const range = selection.getRangeAt(0);
      return range.startContainer === ticket.range.startContainer && range.startOffset === ticket.range.startOffset &&
        range.endContainer === ticket.range.endContainer && range.endOffset === ticket.range.endOffset;
    }
    function valid(ticket) {
      return !ticket.invalid && now() < ticket.deadline && doc.visibilityState === 'visible' && doc.hasFocus() &&
        doc.activeElement === ticket.element && supported(ticket.element) && sameSelection(ticket) &&
        (ticket.kind === 'plain' ? ticket.element.value === ticket.initial : ticket.element.innerHTML === ticket.initial);
    }
    listen(doc, 'focusout', () => { if (current && !delivering) current.invalid = true; });
    listen(win, 'blur', () => { if (current && !delivering) current.invalid = true; });
    listen(doc, 'visibilitychange', () => { if (current && doc.visibilityState !== 'visible') current.invalid = true; });
    listen(doc, 'selectionchange', () => {
      if (current && !delivering && !sameSelection(current)) current.invalid = true;
    });
    listen(doc, 'input', (event) => {
      if (current && !delivering && (event.target === current.element || current.element.contains(event.target)))
        current.invalid = true;
    });
    function capture() {
      forget();
      const element = doc.activeElement;
      if (!doc.hasFocus() || doc.visibilityState !== 'visible' || !supported(element))
        return { ok: false, reason: 'unsupported_or_inactive_target' };
      const kind = element instanceof win.HTMLInputElement || element instanceof win.HTMLTextAreaElement ? 'plain' : 'rich';
      const initial = kind === 'plain' ? element.value : element.innerHTML;
      if (initial.length > 200000) return { ok: false, reason: 'target_too_large' };
      const ticket = { token: win.crypto.randomUUID(), element, kind, initial, deadline: now() + maxAgeMs, invalid: false };
      if (kind === 'plain') {
        if (element.selectionStart === null || element.selectionEnd === null) return { ok: false, reason: 'selection_unavailable' };
        ticket.start = element.selectionStart;
        ticket.end = element.selectionEnd;
        ticket.direction = element.selectionDirection;
      } else {
        const selection = doc.getSelection();
        if (selection?.rangeCount !== 1) return { ok: false, reason: 'selection_unavailable' };
        const range = selection.getRangeAt(0);
        if (!element.contains(range.startContainer) || !element.contains(range.endContainer))
          return { ok: false, reason: 'selection_outside_target' };
        ticket.range = range.cloneRange();
      }
      current = ticket;
      expiryTimer = win.setTimeout(() => { if (current === ticket) forget(); }, maxAgeMs);
      return { ok: true, token: ticket.token, kind };
    }
    function apply(token, text) {
      const ticket = current;
      if (!ticket || ticket.token !== token) return { ok: false, reason: 'stale_request' };
      if (typeof text !== 'string' || text.length === 0 || text.length > 16000 || text.includes('\0'))
        return { ok: false, reason: 'invalid_text' };
      if (ticket.element instanceof win.HTMLInputElement && /[\r\n]/.test(text))
        return { ok: false, reason: 'multiline_in_singleline_target' };
      if (!valid(ticket)) { forget(); return { ok: false, reason: 'target_changed' }; }
      // Give the page a cancellable input event, then check again. Never force
      // insertion if a handler cancels, changes focus, selection or field data.
      const before = new win.InputEvent('beforeinput', {
        inputType: 'insertText', data: text, bubbles: true, composed: true, cancelable: true
      });
      if (!ticket.element.dispatchEvent(before)) {
        forget();
        return { ok: false, reason: 'page_cancelled' };
      }
      if (!valid(ticket)) { forget(); return { ok: false, reason: 'target_changed' }; }
      const expected = ticket.kind === 'plain' ? ticket.initial.slice(0, ticket.start) + text + ticket.initial.slice(ticket.end) : null;
      // execCommand retains native editing/undo behavior. It is deprecated; this
      // capability must be checked on the actual supported Chromium versions.
      delivering = true;
      forget(); // Consume before delivery: no replay or automatic retries.
      try {
        const accepted = doc.execCommand('insertText', false, text);
        if (!accepted || (expected !== null && ticket.element.value !== expected))
          return { ok: false, reason: 'delivery_uncertain' };
        return { ok: true, delivery: 'completed' };
      } catch {
        return { ok: false, reason: 'delivery_uncertain' };
      } finally { delivering = false; }
    }
    return Object.freeze({
      capture, apply,
      cancel(token) { if (current && (token === undefined || current.token === token)) forget(); },
      dispose() { forget(); listeners.splice(0).forEach(remove => remove()); }
    });
  }
  Object.defineProperty(globalThis, 'OpenDictateInsertion', { value: Object.freeze({ create }) });
})();
