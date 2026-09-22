# Installierte macOS-App: TextEdit-Durchlauf am 22. September 2026

## Kandidat und Eingriff

Installiert und gestartet wurde `/Applications/OpenDictate.app`, Version 0.1.0,
Build 1, Quellrevision `68ef919b550eedb982e71405bb4d4d6bb9c27e93`.
Das Bundle war mit `OpenDictate Self-Signed` signiert. Der Checkout blieb sauber;
Quellcode und App-Bundle wurden für diese Prüfung nicht geändert.

Zwei vorherige echte TextEdit-Durchläufe transkribierten erfolgreich, fügten
aber nicht automatisch ein. Beim zweiten blieb TextEdit bis nach Abschluss
vorne. Das App-Log meldete am 22. September um 18:50:19 UTC ein fehlendes,
geschütztes oder verändertes Ursprungsziel. Ein macOS-TCC-Log meldete zuvor,
dass die gespeicherte Code-Anforderung für `local.opendictate.app` beim Dienst
`kTCCServiceAccessibility` nicht mehr zur installierten Signatur passte.

Nach Bastis konkreter Freigabe wurde nur
`tccutil reset Accessibility local.opendictate.app` ausgeführt. In den
macOS-Systemeinstellungen wurde die App aus `/Applications` erneut zu
„Gerätesteuerung und Datenzugriff“ hinzugefügt. Der OpenDictate-Schalter stand
danach auf Ein. Die App wurde beendet und frisch aus `/Applications` gestartet;
der neue Prozess verwendete das unveränderte Bundle. `autoPaste` stand auf 1,
das globale Kürzel wurde laut App-Log als Option+Shift+Leertaste registriert.

## Sichtbarer End-to-End-Nachweis

Basti fokussierte ein leeres, unbenanntes TextEdit-Dokument, startete und
stoppte die Aufnahme mit dem physischen globalen Kürzel und sprach einen kurzen,
unempfindlichen Testsatz. Er blieb bis nach der Ausgabe in TextEdit und
bestätigte sichtbaren Text. Die anschließende native TextEdit-Prüfung zeigte
18 Zeichen im zuvor leeren `AXTextArea`; ein Fensterscreenshot bestätigte die
sichtbare Einfügung. Das App-Log protokollierte Export, Provider-Request,
Übergabe und Stopp-bis-Ergebnis. Der Request dauerte 1.820 ms, die Übergabe
27 ms. Es gab in diesem Durchlauf keinen Einfügefehler. Der genaue Satz wird
hier nicht festgehalten.

Das ist ein erfolgreicher realer Mikrofon-→-Provider-→-TextEdit-Durchlauf der
installierten Revision. Der TCC-Schalter und die erfolgreiche automatische
Einfügung belegen wirksame Bedienungshilfen für diesen Lauf; ein separater
Debugger-Aufruf von `AXIsProcessTrusted()` wurde nicht durchgeführt. Ein
einzelner Erfolg ist keine allgemeine Zusage für Sprachqualität oder andere
Zielprogramme.

## Aufräumen und Grenze

Das unbenannte TextEdit-Testdokument wurde ohne Speichern geschlossen und das
Fenster danach als geschlossen geprüft. Die beiden eindeutig zugeordneten
Recovery-Dateien vom 22. September wurden entfernt. Die ältere Aufnahme vom
15. September samt `.auth` blieb erhalten. Temporäre Prüfscreenshots wurden
entfernt. Zu diesem Durchlauf gehörte genau ein Provider-Upload; es gab keine
Veröffentlichung.

Offen bleiben insbesondere sichtbare Terminaleingabe, ein real bestätigter
negativer Fokuswechsel, Safari-Rückweg, Einrichtungs-/Keychain-Fehler und
Beenden/Abbruch während Aufnahme oder Upload. Dafür ist ein neuer begrenzter
Live-Testblock erforderlich; frühere Budgets sind verbraucht.
