# Compact native settings — 2026-09-15

## Candidate and behavior

Installed `~/Applications/OpenDictate.app`, signed with the existing
`OpenDictate Self-Signed` identity. Executable SHA-256:
`e7578aff6453413df7030f03f10cfbc12608b6ce62c3fd402cefe399be8b0a9e`. The installed binary matches the verified build.
The previous daily app remains backed up locally.

The main settings now contain microphone, shortcut, language and automatic
insertion. Model, API-key setup and vocabulary are under the initially collapsed
“Erweitert”. “Aufnahmen” and “Hilfe” are secondary pages with a return button.
Recording, cancel/discard, copy/clear and quit actions remain available from the
recording panel's “Weitere Aktionen”. No recording action is duplicated in the
settings page. Existing stored values and action handlers remain authoritative.

Opening settings hides the floating recording panel. Reactivating the app keeps
an already open settings page in front; the explicit menu-bar action opens the
recording panel and hides settings. Window closing still does not end dictation.
Known recording/provider errors now give German next steps; unknown framework
and provider details are not passed into the daily UI. Recovery behavior is unchanged.

## Checks

- 105 offline tests passed, including error categorization, refusal to expose raw
  errors, retention and dictation lifecycle tests. The default local Swift 6.4
  runner failed to find TestingMacros; the native engine with the installed
  Testing framework/plugin paths passed. No toolchain installation was performed.
- Formatting, script syntax and diff checks passed. Release build, signature,
  Hardened Runtime and microphone entitlement verification passed.
- The real installed main settings, expanded section, recording page and Help
  were inspected through native accessibility trees and screenshots.
- Tab/Shift+Tab reached the controls and returned through each page. Space opened
  Erweitert, the model menu, recording page/menu and Help. Model menus were
  dismissed without a selection; credential/vocabulary values were not opened.
- The normal 440 × 308 window, a compact 380 × 300 window and a larger approximately
  640 × 478 window were inspected. Text wraps and the scroll view keeps all actions
  reachable; keyboard navigation scrolls an offscreen focused control into view.
- The final recording page shows the user's short recording as 0,9 s, rather than
  truncating it to 0 s. Its menu exposes retry and delete without invoking either.
- An open recording menu remained open across a background refresh interval and
  closed normally without invoking retry/delete.
- The recording panel's actions menu exposes cancel/discard/copy/clear with
  appropriate idle-state disabling, recording management and quit.
- Quitting from Help terminated the app; the normal daily launcher restarted it.

Before/after hashes confirm that the user's existing recording and authentication
metadata, and the entire stored app preference domain, are unchanged. No new
microphone capture, retry, provider request, deletion, credential or preference
change was made for this UI acceptance. This does not renew the earlier real
dictation, VoiceOver, live interruption or browser-delivery evidence.
