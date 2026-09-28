'use strict';
if (!globalThis.OpenDictateBrowserSession) {
  Object.defineProperty(globalThis, 'OpenDictateBrowserSession', { value: OpenDictateInsertion.create() });
  chrome.runtime.onMessage.addListener((message, sender, reply) => {
    if (sender.id !== chrome.runtime.id || message?.type !== 'opendictate-insert') return;
    reply(OpenDictateBrowserSession.apply(message.token, message.text));
  });
}
