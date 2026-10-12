# Kostenlos diktieren mit einem lokalen Modell

OpenDictate kann statt OpenAI ein Sprachmodell auf deinem eigenen Rechner
nutzen. Dann kostet ein Diktat nichts, du brauchst keinen API-Schlüssel, und
deine Aufnahme verlässt den Rechner nicht. Diese Anleitung richtet dafür
[whisper.cpp](https://github.com/ggml-org/whisper.cpp) ein, ein freies
Programm, das Sprache in Text umwandelt.

Du brauchst dafür einmal das Terminal und etwa 600 MB Platz für das Modell.

**Wo es geht:** In der Mac-Beta ab Build 12
([`v0.1.0-beta.12`](https://github.com/HerrStolzier/OpenDictate/releases/tag/v0.1.0-beta.12))
und in der Linux-Beta.

**Was es nicht kann:** whisper.cpp schreibt nur ab, es übersetzt nicht.
Schalte die Übersetzung aus, sonst bleibt das Diktat als fehlgeschlagen
liegen.

## Mac

1. [Homebrew](https://brew.sh) installieren, falls noch nicht da. Dann im
   Terminal:

   ```bash
   brew install whisper-cpp ffmpeg
   ```

   ffmpeg braucht whisper.cpp, um die Aufnahmen der Mac-App zu lesen.

2. Das Modell laden. `large-v3-turbo` in der Variante `q5_0` versteht Deutsch
   gut und ist auf Macs mit Apple-Chip schnell:

   ```bash
   mkdir -p ~/whisper-modelle
   curl -L -o ~/whisper-modelle/ggml-large-v3-turbo-q5_0.bin \
     https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin
   ```

3. Den Server starten. Er ist nur auf deinem Mac erreichbar, nicht im Netz:

   ```bash
   whisper-server -m ~/whisper-modelle/ggml-large-v3-turbo-q5_0.bin \
     --host 127.0.0.1 --port 8080 \
     --inference-path /v1/audio/transcriptions --convert -l auto
   ```

   Er läuft, solange das Terminal-Fenster offen ist. Beenden mit ⌃C.

4. In OpenDictate: **Einstellungen → Erweitert → Eigener Server**
   `http://127.0.0.1:8080/v1` eintragen und speichern, Modellnamen leer
   lassen. **Übersetzen** auf **Aus** stellen.

5. Diktieren wie immer. Bei unserem Test auf einem Mac mini mit Apple-Chip stand
   der Text etwa zweieinhalb Sekunden nach dem Loslassen da. Das ist ein
   einzelner Test, auf deinem Mac kann es anders sein.

Zurück zu OpenAI: das Feld **Eigener Server** leeren.

## Linux

1. whisper.cpp installieren, unter Arch zum Beispiel aus dem Paket
   `whisper-cpp`.
2. Ein Modell laden wie oben in Schritt 2 beschrieben. Ohne Grafikkarte ist
   ein großes Modell langsam; ein kleineres wie `ggml-base.bin` ist schneller,
   erkennt aber weniger genau.
3. Den Server starten:

   ```bash
   whisper-server -m ~/whisper-modelle/ggml-large-v3-turbo-q5_0.bin \
     --host 127.0.0.1 --port 8080 \
     --inference-path /v1/audio/transcriptions
   ```

4. OpenDictate darauf zeigen lassen und die Übersetzung ausschalten:

   ```bash
   opendictate settings server http://127.0.0.1:8080/v1
   opendictate settings target off
   ```

   Mehr dazu im [Linux-Handbuch](../linux/README.de.md#eigenen-server-verwenden).

Unter Linux ist whisper.cpp mit OpenDictate noch nicht geprüft. Wenn du es
ausprobierst, freuen wir uns über eine
[Rückmeldung](https://github.com/HerrStolzier/OpenDictate/issues/new?template=linux-beta-feedback.md).

## Wieder entfernen

Mac: `brew uninstall whisper-cpp` und den Ordner `~/whisper-modelle` löschen.
Linux: das Paket entfernen und den Modellordner löschen.
