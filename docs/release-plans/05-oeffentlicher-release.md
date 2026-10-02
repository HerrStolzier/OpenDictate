# Plan 5: Öffentlicher Beta-Release

**Ziel:** Die freigegebene erste Mac-Version steht als kostenloser direkter
Download und als **Pre-Release** auf GitHub Releases bereit. Eine öffentliche
Produktseite mit Kennzeichnung „Beta“ führt zum gleichen Paket. Fremde
Nutzer testen danach im öffentlichen Betatest (Stufe 6 der
[ROADMAP](../../ROADMAP.md)); einen Betatest mit fremden Testern vor dieser
Veröffentlichung gibt es nicht (Entscheidung vom 2. Oktober 2026).
Download, Installation, Start und Hilfeweg wurden von außen geprüft.
Ein Bezahlmodell, Mac App Store, Intel-Macs, Linux und Windows sind nicht Teil
dieser ersten Veröffentlichung.

**Voraussetzung:** Der unveränderte Kandidat aus
[Plan 4](04-release-kandidat.md) ist freigegeben. Basti hat **diese konkrete
Veröffentlichung** und die öffentliche Produktseite ausdrücklich genehmigt.
Die bisherige Richtung „zunächst kostenlos“ ist vor Veröffentlichung nochmals
zu bestätigen; dieser Plan trifft keine Vertrags- oder Firmenentscheidung.

## Arbeit

1. Die korrigierte statische Website aus `website/` über GitHub Pages
   veröffentlichen und sichtbar als „Beta“ kennzeichnen. Sie nennt
   Systemvoraussetzung, eigenen OpenAI-Schlüssel,
   zusätzliche API-Kosten, Mikrofon-/Bedienungshilfen-Berechtigung,
   Datenschutz, manuelles Kopieren und bekannte Ziel-/Fokusgrenzen.
   Der Einstieg erklärt die erste Nutzung in drei kurzen Schritten:
   App öffnen und Schlüssel hinterlegen, Berechtigungen geben, Kürzel zweimal
   drücken. Keine Funktionsliste steht vor diesem Ablauf.
2. Ein GitHub **Pre-Release** mit Versionshinweisen, dem **unveränderten** ZIP
   aus Plan 4, SHA-256-Wert und der
   [Installationsanleitung](installationsanleitung.md) veröffentlichen. Die
   private Draft `v0.1.0-beta.8` ist dafür vorgesehen, solange Plan 4 keinen
   neuen Kandidaten erzeugt. Kein
   Ad-hoc-CI-Archiv als Produktdownload verlinken. Die Website verlinkt genau
   diesen Release und seine Datenschutzhinweise.
3. Von den öffentlichen Links das ZIP erneut herunterladen, den Hash
   vergleichen, Signatur/Notarisierung prüfen und auf dem vorhandenen Mac
   aus dem Download installieren. Sichtbar prüfen: Start, vorhandene
   Berechtigungen, Schlüsselzugriff und ein harmloses Diktat. Der Prüflauf ist auf
   denselben Release-Hash bezogen.
4. GitHub Issues mit der Vorlage „Beta-Rückmeldung“ als öffentlichen
   Meldeweg prüfen und auf der Seite verlinken.
   Release- und Installationsprobleme mit Version, macOS und reproduzierbaren
   Schritten erfassen, ohne API-Schlüssel, Aufnahme oder private Texte
   anzufordern. Bei einem kritischen Problem den Downloadhinweis klar ändern
   und einen korrigierten Kandidaten wieder ab Plan 4 prüfen.

## Abnahme

- GitHub Release und Website sind öffentlich erreichbar und verlinken
  denselben SHA-256-geprüften Build. Der öffentliche Download startet ohne
  Entwicklerumweg auf dem zugesagten Mac; Signatur und Notarisierung stimmen.
- Produktseite, README, Privacy und Release-Hinweise widersprechen weder
  einander noch dem veröffentlichten Build. Ein nachvollziehbarer Meldeweg
  funktioniert. Die erste Anleitung ist in drei Schritten lesbar; sie
  verschweigt weder die OpenAI-Kosten noch den manuellen Rückweg.
- Datum, Version, Quellrevision, ZIP-Hash, Website- und Release-Link sowie
  das Ergebnis des externen Downloadtests sind im Release-Protokoll erfasst.

**Freigabegrenze:** GitHub Release, GitHub Pages und jeder andere öffentliche
Kanal bleiben bis zu Bastis konkreter Freigabe unveröffentlicht. Der Plan
erteilt keine Vorabfreigabe. Das Diktat im öffentlichen Downloadtest benötigt
zusätzlich eine begrenzte Freigabe für Mikrofon und OpenAI-Upload.
