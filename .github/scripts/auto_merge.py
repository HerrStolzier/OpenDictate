#!/usr/bin/env python3
# Kopie aus HerrStolzier/claude-config (ci/auto_merge.py); dort pflegen, dann scripts/install-repo-gate.py erneut ausführen.
"""Auto-Merge für Claudes PRs: Basti liest und mergt keine PRs, das übernimmt GitHub selbst.

Läuft als GitHub-Workflow (.github/workflows/auto-merge.yml) im jeweiligen Projekt-Repo, ohne GitHub Pro
und ohne Branch-Schutz. Ein PR wird gemergt (Squash), wenn alles davon stimmt:
  - Er ist kein Entwurf. Entwurf heißt „noch nicht fertig“ oder „wartet bewusst“; Claude stellt ihn auf bereit.
  - Er kommt aus einem Branch dieses Repos, nicht aus einem Fork, und sein Autor ist der Repo-Besitzer.
  - Jeder Commit, der Code ändert (nicht nur .md/.txt/.rst), trägt eine Zeile `Reviewed-by:` (wie hooks/review-gate.py).
  - Alle Prüfungen auf dem letzten Stand sind fertig und grün (Erfolg, neutral oder übersprungen).
  - Es gibt keinen Konflikt mit dem Ziel-Branch und keinen offenen Review-Hinweis (Thread).
  - Er trägt nicht das Label `später` (Basti hat in der Erklärung „Erst mal nicht“ angetippt).
Fehlt ein Review, ist ein Review-Hinweis offen, gibt es einen Konflikt, ist der Branch zu alt für einen
Ziel-Branch, der einen aktuellen Stand verlangt, oder ändert der PR Dateien, die über das Mergen urteilen
(Workflows, CI-Skripte, Claudes Regeln, Secret-Scan-Ausnahmen; siehe guarded()), schreibt der Workflow einmal je Stand einen Kommentar. Der Claude-Thread, der den PR beobachtet,
behebt das dann selbst. Rote CI kommentiert er nicht, die meldet GitHub dem Thread ohnehin.

Quelle: HerrStolzier/claude-config (ci/auto_merge.py), verteilt mit scripts/install-repo-gate.py.
"""
import base64
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import zlib

TRAILER = re.compile(r"^[ \t]*Reviewed-by:[ \t]*\S", re.M)
TEXT_SUFFIXES = (".md", ".markdown", ".txt", ".rst")
OK_CONCLUSIONS = {"success", "neutral", "skipped"}
SELF_CHECK = "Auto-Merge"  # Name des eigenen Jobs; seine Prüfung zählt nicht mit.
# Die Erklärseite (Erklärung für Basti, ci/erklaerseite.yml) entscheidet nicht über den Merge. Gewartet wird nur,
# solange sie die Erklärung schreibt (EXPLAIN_CHECK); scheitert sie, hält das nichts auf.
INFO_PREFIX = "Erklärseite"
LABEL_LATER = "später"  # Basti hat in der Erklärung „Erst mal nicht“ angetippt: nicht mergen, bis das Label weg ist.
# Die Erklärung hat im PR eine Frage an Basti gefunden: nicht mergen, bis er „Ja, mach das“ antippt (Label LABEL_YES).
LABEL_WAIT, LABEL_YES = "wartet-auf-basti", "ja-von-basti"
# Frage an Basti in der PR-Beschreibung (eigene Zeile „Frage an Basti: …“): hält den Merge bis zu seinem „Ja“,
# auch wenn die Erklärung scheitert oder die Frage übersieht. Gleiches Muster in erklaerseite.py.
QUESTION = re.compile(r"^[ \t>#+\-]*(?:\*[ \t]+)?(?:\d+[.)][ \t]*)?[*_]*Frage an Basti[*_]*[ \t\r]*(?:[:–—-]|$)", re.M | re.I)
EXPLAIN_CHECK = "Erklärseite"  # Job, der die Erklärung schreibt: Solange er läuft, kann noch eine Frage kommen.
GRACE_SECONDS = 90  # So lange bekommen andere Workflows Zeit, ihre Prüfungen anzulegen.
POLL_SECONDS = 30  # Abstand der Abfragen bei kurzer Wartezeit
LONG_POLL_SECONDS = 120  # bei langer Wartezeit: GITHUB_TOKEN hat nur 1000 Abfragen je Stunde und Repo
SHORT_WAIT_MINUTES = 3
FILE_CAP = 3000  # Obergrenze der Dateilisten von GitHub (Commit und PR)


BEHAVIOR_DIRS = ("agents/", ".claude/")  # .md dort ist Verhalten (Frontmatter mit Werkzeugen, Modell, Hooks)


def needs_review(paths):
    """Dateien, die kein reiner Text sind (gleiche Regel wie hooks/review-gate.py)."""
    return [p for p in paths if p and (p.startswith(BEHAVIOR_DIRS) or "/.claude/" in p
                                       or not (p.lower().endswith(TEXT_SUFFIXES)
                                               or os.path.basename(p).upper().startswith("LICENSE")))]


def latest_checks(check_runs, runs=()):
    """Ohne die eigene Prüfung; je Workflow-Lauf (check suite) und Name zählt nur der jüngste Versuch.
    Gleich benannte Jobs aus verschiedenen Workflows zählen getrennt."""
    latest = {}
    for c in check_runs:
        if c.get("name") == SELF_CHECK or (c.get("name") or "").startswith(INFO_PREFIX):
            continue
        key = ((c.get("check_suite") or {}).get("id"), c.get("name"))
        if key not in latest or c.get("id", 0) > latest[key].get("id", 0):
            latest[key] = c
    # Ein abgebrochener Lauf, den ein neuerer gleichnamiger Lauf desselben Workflows auf demselben Stand abgelöst
    # hat, zählt nicht (z. B. Claude Review, wenn ein PR auf demselben Stand erneut bereit gestellt wird).
    # Ist der Workflow einer Suite unbekannt, bleibt sie für sich und ein abgebrochener Lauf dort rot.
    workflow = {r.get("check_suite_id"): r.get("workflow_id") for r in runs
                if r.get("check_suite_id") and r.get("workflow_id")}

    def group(c):
        suite = (c.get("check_suite") or {}).get("id")
        return (workflow.get(suite) or ("suite", suite), c.get("name"))

    newest = {}
    for c in latest.values():
        newest[group(c)] = max(newest.get(group(c), 0), c.get("id", 0))
    return [c for c in latest.values()
            if not (c.get("conclusion") == "cancelled" and c.get("id", 0) < newest[group(c)])]


GUARDED_PREFIXES = (".github/", "scripts/ci/", ".claude/")
GUARDED_FILES = {"CLAUDE.md", "AGENTS.md", ".gitleaksignore", ".gitattributes"}
# Nur in claude-config: Dort liegen die Vorlagen der Wächter aller Repos.
SOURCE_PREFIXES = ("ci/", "hooks/", "agents/", "config/")
SOURCE_FILES = {"scripts/install-repo-gate.py"}
IS_SOURCE_REPO = os.environ.get("GITHUB_REPOSITORY", "").lower().endswith("/claude-config")
LINT_CONFIGS = {"ruff.toml", ".ruff.toml", ".shellcheckrc", ".ignore"}  # gelten auch in Unterordnern; .ignore blendet Dateien für ruff aus


def guarded(path, source_repo=None):
    """Dateien, die über das Mergen selbst entscheiden: Workflows, Auto-Merge, CI-Skripte, Claudes Regeln und
    Hooks, die Regeln von ruff und shellcheck sowie die Ausnahmen des Secret-Scans. Solche PRs mergt Claude
    selbst (GITHUB_TOKEN darf Workflow-Dateien nicht mergen), denn ein PR soll nicht automatisch rein, wenn
    er die Prüfungen oder Regeln ändert, die über ihn urteilen."""
    source_repo = IS_SOURCE_REPO if source_repo is None else source_repo
    return (path.startswith(GUARDED_PREFIXES) or path in GUARDED_FILES or path.rsplit("/", 1)[-1] in LINT_CONFIGS
            or source_repo and (path.startswith(SOURCE_PREFIXES) or path in SOURCE_FILES))


HOLD_LATER_TICK = "Basti: erst mal nicht (Häkchen im Erklär-Kommentar)"
HOLD_YES_TICK = "wartet auf Bastis Entscheidung (Häkchen „Ja“ im Erklär-Kommentar fehlt)"
TICK_HOLDS = {HOLD_LATER_TICK: "haekchen_spaeter", HOLD_YES_TICK: "haekchen_ja"}


def held_by_labels(issue, ticks=None):
    """Bastis Labels, die einen Merge anhalten: Grund oder "". ticks: Häkchen im Erklär-Kommentar (siehe
    explain_ticks); sie zählen schon, bevor der Knopf-Job das Label angeglichen hat."""
    labels = {lb.get("name") or "" for lb in issue.get("labels") or []}
    ticks = ticks or {}
    if LABEL_LATER in labels:
        return "Basti: erst mal nicht"
    if ticks.get("spaeter"):
        return HOLD_LATER_TICK
    asks = LABEL_WAIT in labels or QUESTION.search(issue.get("body") or "")
    # Ein abgehaktes „Ja, mach das“ nimmt das Label noch nicht weg, solange der Knopf-Job in der Warteschlange steht.
    if asks and LABEL_YES not in labels:
        return "wartet auf Bastis Entscheidung"
    if asks and not ticks.get("ja", True):
        return HOLD_YES_TICK
    mark = ticks.get("_beschreibung")
    if asks and mark and mark != hashlib.sha256((issue.get("body") or "").strip().encode()).hexdigest()[:16]:
        # Die Beschreibung ist neuer als die Erklärung, zu der Basti Ja sagte (der Lauf „Erklärseite“, der das alte
        # Ja abnimmt, ist vielleicht noch nicht angelegt). Gleiche Rechnung wie description_mark in erklaerseite.py.
        return "wartet auf Bastis Entscheidung (Beschreibung geändert, neue Erklärung folgt)"
    return ""


EXPLAIN_MARK, EXPLAIN_BOT = "<!-- erklaerseite -->", "github-actions[bot]"
EXPLAIN_BOX = re.compile(r"^- \[( |x|X)\] .*<!-- k:(\w+) -->[ \t\r]*$", re.M)


def explain_ticks(gh, number):
    """Häkchen im Erklär-Kommentar der Erklärseite, etwa {"spaeter": True, "ja": False}, dazu unter "_beschreibung"
    der Fingerabdruck der Beschreibung, zu der die Erklärung gehört; {} ohne Kommentar.
    Basti tippt direkt in diesen Kommentar. Das Label setzt erst der Knopf-Job, und der kann hinter einem
    belegten Runner warten. Beide Richtungen halten nur an, darum zählt hier jedes Häkchen."""
    for c in gh.pages(f"/repos/{gh.repo}/issues/{number}/comments"):
        body = c.get("body") or ""
        if (c.get("user") or {}).get("login") == EXPLAIN_BOT and EXPLAIN_MARK in body:
            ticks = {m.group(2): m.group(1).lower() == "x" for m in EXPLAIN_BOX.finditer(body)}
            mark = (explain_data(body) or {}).get("beschreibung")
            return {**ticks, "_beschreibung": mark} if isinstance(mark, str) else ticks
    return {}


EXPLAIN_DATA = re.compile(r"<!-- erklaerseite-daten (z )?([A-Za-z0-9+/=]*) -->")


def explain_data(body):
    """Versteckte Daten des Erklär-Kommentars (wie parse_data in erklaerseite.py): gepackt („z “) oder reines JSON."""
    m = EXPLAIN_DATA.search(body or "")
    if not m:
        return None
    try:
        raw = base64.b64decode(m.group(2))
        if m.group(1):
            unpack = zlib.decompressobj()
            raw = unpack.decompress(raw, 5_000_000)
            if unpack.unconsumed_tail:
                return None
        data = json.loads(raw.decode())
    except (ValueError, UnicodeDecodeError, zlib.error):
        return None
    return data if isinstance(data, dict) else None


def label_hold(gh, number):
    """Labels und Häkchen direkt vor dem Merge frisch lesen: Die Erklärung setzt „wartet-auf-basti“ vielleicht
    erst, nachdem der PR gelesen wurde, und Basti tippt vielleicht gerade „Erst mal nicht“ an."""
    # Über /pulls lesen, nicht /issues: Der Workflow hat keine issues-Rechte (403 „Resource not accessible“).
    return held_by_labels(gh.get(f"/repos/{gh.repo}/pulls/{number}"), explain_ticks(gh, number))


def evaluate(pr, owner, default_branch, commits, files, check_runs, status, waited, runs=(), has_ci=False,
             unresolved=0):
    """Entscheidung für einen PR. Gibt (Ergebnis, Begründung) zurück.

    Ergebnis: "skip" (nicht unser Fall), "block" (Claude muss etwas tun, Kommentar), "red" (CI rot),
    "wait" (noch nicht entscheidbar) oder "merge".
    commits: [{"sha", "message", "parents", "files"}], files: Dateinamen des PRs,
    status: kombinierter Commit-Status {"state", "total_count"}, waited: Sekunden seit Start dieses Laufs,
    runs: andere Workflow-Läufe auf diesem Stand (fängt Jobs ab, deren Prüfung noch nicht angelegt ist),
    has_ci: Das Repo hat eigene CI. Dann wird ohne jede sichtbare Prüfung nie gemergt, nur gewartet.
    unresolved: Zahl offener Review-Threads. GitHub lehnt den Merge sonst ab, wenn das Repo verlangt,
    dass alle Hinweise erledigt sind.
    """
    if pr.get("state") != "open" or pr.get("merged"):
        return "skip", "nicht offen"
    if pr.get("draft"):
        return "skip", "Entwurf"
    head_repo = ((pr.get("head") or {}).get("repo") or {}).get("full_name")
    base_repo = ((pr.get("base") or {}).get("repo") or {}).get("full_name")
    if not head_repo or head_repo != base_repo:
        return "skip", "Fork"
    if (pr.get("user") or {}).get("login", "").lower() != owner.lower():
        return "skip", "fremder Autor"
    if (pr.get("base") or {}).get("ref") != default_branch:
        return "skip", "Ziel ist nicht der Haupt-Branch"
    held = held_by_labels(pr)
    if held:
        return "skip", held

    unreviewed = [c["sha"][:7] for c in commits
                  if len(c.get("parents") or []) < 2 and needs_review(c.get("files") or [])
                  and not TRAILER.search(c.get("message") or "")]
    if unreviewed:
        return "block", "review:" + ",".join(unreviewed)
    if any(guarded(f) for f in files):
        return "block", "workflow"
    if pr.get("mergeable") is False or pr.get("mergeable_state") == "dirty":
        return "block", "konflikt"
    if unresolved:
        return "block", f"hinweise:{unresolved}"

    checks = latest_checks(check_runs, runs)
    failed = [c["name"] for c in checks if c.get("status") == "completed"
              and (c.get("conclusion") or "") not in OK_CONCLUSIONS]
    failed += [r.get("name") or "Workflow" for r in runs if r.get("status") == "completed"
               and (r.get("conclusion") or "") not in OK_CONCLUSIONS | {"cancelled"}]
    if failed or status.get("state") in ("failure", "error"):
        return "red", ", ".join(failed) or "Commit-Status rot"
    pending = [c["name"] for c in checks if c.get("status") != "completed"]
    pending += [r.get("name") or "Workflow" for r in runs if r.get("status") != "completed"]
    if pending or (status.get("total_count") and status.get("state") == "pending"):
        return "wait", "läuft: " + ", ".join(pending or ["Commit-Status"])
    if any(c.get("name") == EXPLAIN_CHECK and c.get("status") != "completed" for c in check_runs):
        return "wait", "Erklärseite schreibt noch die Erklärung"  # scheitert sie, hält das den Merge nicht auf
    if not checks and not runs and not status.get("total_count") and (has_ci or waited < GRACE_SECONDS):
        return "wait", "noch keine Prüfungen angelegt"
    if pr.get("mergeable") is None:
        return "wait", "GitHub prüft noch auf Konflikte"
    return "merge", "alles grün"


COMMENTS = {
    "review": ("Auto-Merge wartet: Diese Commits ändern Code, tragen aber keine `Reviewed-by:`-Zeile: {detail}. "
               "Lass critic den Stand prüfen, behebe wesentliche Befunde und ergänze die Zeile in diesen Commits "
               "(eigener Branch: umschreiben und mit `--force-with-lease` pushen). Danach mergt Auto-Merge von selbst."),
    "workflow": ("Auto-Merge mergt diesen PR nicht, weil er Dateien ändert, die über das Mergen urteilen "
                 "(`.github/`, `scripts/ci/`, `.claude/`, `CLAUDE.md`, `AGENTS.md`, `.gitleaksignore`, `.gitattributes`, "
                 "Lint-Regeln wie `ruff.toml`, in claude-config auch `ci/`, `hooks/`, `agents/`, `config/` und "
                 "`scripts/install-repo-gate.py`). Claude: Wenn die CI grün ist und jeder Code-Commit "
                 "geprüft ist, merge den PR selbst (Squash). Basti muss nichts tun."),
    "konflikt": ("Auto-Merge wartet: Der PR hat einen Konflikt mit `{base}`. Claude: Hol `{base}` in den Branch, "
                 "löse den Konflikt und pushe. Danach mergt Auto-Merge von selbst."),
    "hinweise": ("Auto-Merge wartet: {detail} Review-Hinweis(e) sind noch offen. Claude: Prüf jeden Hinweis, behebe "
                 "die berechtigten und pushe, dann beantworte und löse jeden Thread auf. Musstest du nichts pushen, "
                 "starte Auto-Merge danach neu: lokal `gh workflow run auto-merge.yml`, in der Cloud "
                 "`POST /repos/{repo}/actions/workflows/auto-merge.yml/dispatches` mit `{{\"ref\": \"{base}\"}}`. "
                 "Danach mergt Auto-Merge von selbst."),
    "haekchen_spaeter": ("Auto-Merge wartet: Basti hat im Erklär-Kommentar „Erst mal nicht“ angehakt. Claude: Nichts tun "
                         "und nicht nachfragen. Der PR wartet, bis Basti das Häkchen selbst entfernt."),
    "haekchen_ja": ("Auto-Merge wartet: Im Erklär-Kommentar ist „Ja, mach das“ nicht angehakt; das Label `ja-von-basti` "
                    "allein zählt nicht. Claude: Setz Häkchen und Label nie selbst. Brauchst du die Antwort, frag Basti "
                    "per Karte nach dem Ziel und verlinke den Erklär-Kommentar; antippen muss er dort (oder auf der "
                    "Erklärseite) selbst. Ein Ja auf der Karte setzt du nicht um."),
    "hinter": ("Auto-Merge wartet: Der Branch ist hinter `{base}`, und `{base}` verlangt einen aktuellen Stand. "
               "Claude: Hol `{base}` in den Branch, lokal `gh pr update-branch`, in der Cloud "
               "`PUT /repos/{repo}/pulls/{number}/update-branch`. Nach grüner CI mergt Auto-Merge von selbst."),
}


class RateLimited(RuntimeError):
    """GitHub lehnt weitere Abfragen ab, bis das Stunden-Kontingent sich erneuert."""


class GitHub:
    def __init__(self, token, repo, api="https://api.github.com"):
        self.token, self.repo, self.api = token, repo, api.rstrip("/")

    def call(self, method, path, body=None):
        url = path if path.startswith("http") else f"{self.api}{path}"
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method, headers={
            "Authorization": f"Bearer {self.token}", "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "auto-merge"})
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                raw = r.read()
                return r.status, (json.loads(raw) if raw else None), r.headers.get("Link", "")
        except urllib.error.HTTPError as e:
            raw = e.read()
            try:
                payload = json.loads(raw) if raw else None
            except ValueError:
                payload = {"message": raw.decode(errors="replace")}
            if e.code in (403, 429) and e.headers.get("x-ratelimit-remaining") == "0":
                # Erschöpftes Kontingent ist nur am Kopf sicher erkennbar, die Meldung ist nicht garantiert
                message = payload.get("message", "") if isinstance(payload, dict) else ""
                payload = {"message": f"API rate limit exceeded (x-ratelimit-remaining: 0) {message}".strip()}
            return e.code, payload, ""

    def get(self, path):
        code, data, _ = self.call("GET", path)
        if code != 200:
            fail(path, code, data)
        return data

    def pages(self, path, key=None, limit=10):
        sep = "&" if "?" in path else "?"
        url, out = f"{path}{sep}per_page=100", []
        for _ in range(limit):
            code, data, link = self.call("GET", url)
            if code != 200:
                fail(url, code, data)
            out += data[key] if key else data
            m = re.search(r'<([^>]+)>;\s*rel="next"', link or "")
            if not m:
                break
            url = m.group(1)
        else:  # Mehr Seiten als erlaubt: lieber abbrechen, als mit unvollständigen Daten zu mergen.
            raise RuntimeError(f"GET {path}: mehr als {limit} Seiten")
        return out


def rate_limited(code, data):
    message = data.get("message", "") if isinstance(data, dict) else ""
    return code in (403, 429) and "rate limit" in str(message).lower()


def fail(path, code, data):
    if rate_limited(code, data):
        raise RateLimited(f"GET {path}: {code} Abfrage-Kontingent erschöpft")
    raise RuntimeError(f"GET {path}: {code} {data}")


def candidates(gh, event_name, event):
    r = gh.repo
    if event_name == "pull_request":
        return [event["pull_request"]["number"]]
    if event_name == "workflow_run":
        run = event.get("workflow_run") or {}
        nums = [p["number"] for p in run.get("pull_requests") or []]
        if nums:
            return nums
        sha = run.get("head_sha")
        return [p["number"] for p in gh.pages(f"/repos/{r}/pulls?state=open") if p["head"]["sha"] == sha]
    return [p["number"] for p in gh.pages(f"/repos/{r}/pulls?state=open")]


def comment_once(gh, number, sha, kind, text):
    marker = f"<!-- auto-merge:{sha}:{kind} -->"
    for c in gh.pages(f"/repos/{gh.repo}/issues/{number}/comments"):
        if marker in (c.get("body") or ""):
            return
    gh.call("POST", f"/repos/{gh.repo}/issues/{number}/comments", {"body": f"{text}\n\n{marker}"})


def paths(files):
    """Alle betroffenen Pfade, bei Umbenennungen auch der alte Name."""
    if len(files) >= FILE_CAP:  # GitHub liefert höchstens so viele Dateien; der Rest wäre ungeprüft.
        raise RuntimeError(f"mehr als {FILE_CAP - 1} geänderte Dateien, bitte selbst mergen")
    return [p for f in files for p in (f.get("filename"), f.get("previous_filename")) if p]


def pr_facts(gh, number, cache):
    r = gh.repo
    pr = gh.get(f"/repos/{r}/pulls/{number}")
    sha = pr["head"]["sha"]
    if cache.get(number, {}).get("sha") != sha:
        commits = []
        for c in gh.pages(f"/repos/{r}/pulls/{number}/commits", limit=3):
            files = paths(gh.pages(f"/repos/{r}/commits/{c['sha']}", key="files", limit=30))
            commits.append({"sha": c["sha"], "message": c["commit"]["message"],
                            "parents": c.get("parents") or [], "files": files})
        if len(commits) != pr.get("commits"):  # GitHub liefert höchstens 250 Commits; der Rest bliebe ungeprüft.
            raise RuntimeError(f"PR #{number}: {pr.get('commits')} Commits, nur {len(commits)} geliefert, bitte selbst mergen")
        files = paths(gh.pages(f"/repos/{r}/pulls/{number}/files", limit=30))
        cache[number] = {"sha": sha, "commits": commits, "files": files}
    checks = gh.pages(f"/repos/{r}/commits/{sha}/check-runs", key="check_runs")
    status = gh.get(f"/repos/{r}/commits/{sha}/status")
    own = str(os.environ.get("GITHUB_RUN_ID", ""))
    runs = [x for x in gh.pages(f"/repos/{r}/actions/runs?head_sha={sha}", key="workflow_runs", limit=3)
            if str(x.get("id")) != own and x.get("name") != SELF_CHECK
            and not (x.get("name") or "").startswith(INFO_PREFIX)]
    return pr, cache[number]["commits"], cache[number]["files"], checks, status, runs, unresolved_threads(gh, number)


def unresolved_threads(gh, number):
    """Offene Review-Threads; nur über GraphQL abfragbar. Mehr als 100 Threads zählen als offen."""
    owner, _, name = gh.repo.partition("/")
    query = ("query($o:String!,$n:String!,$p:Int!){repository(owner:$o,name:$n){pullRequest(number:$p)"
             "{reviewThreads(first:100){totalCount nodes{isResolved}}}}}")
    code, data, _ = gh.call("POST", "/graphql", {"query": query, "variables": {"o": owner, "n": name, "p": number}})
    errors = data.get("errors") if isinstance(data, dict) else None
    if code == 200 and errors and any(e.get("type") == "RATE_LIMITED" or "rate limit" in str(e.get("message", "")).lower()
                                      for e in errors if isinstance(e, dict)):
        raise RateLimited("POST /graphql: Abfrage-Kontingent erschöpft")  # GraphQL meldet das mit Status 200
    if code != 200 or not isinstance(data, dict) or errors:
        fail("POST /graphql", code, data)
    threads = data["data"]["repository"]["pullRequest"]["reviewThreads"]
    open_count = sum(1 for t in threads["nodes"] if not t.get("isResolved"))
    return open_count + max(0, threads.get("totalCount", 0) - len(threads["nodes"]))


def wait_minutes(event_name, private, has_ci):
    """Wie lange ein Lauf auf laufende Prüfungen wartet. Ein Lauf zu einem fertigen CI-Workflow wartet nur kurz:
    Jeder fertige CI-Workflow startet einen eigenen Lauf, der letzte sieht alles grün. Warteten diese Läufe
    lange, fragten je PR mehrere gleichzeitig bei GitHub nach und erschöpften das Abfrage-Kontingent.
    Lange wartet nur der Lauf zum Push in öffentlichen Repos (freie Minuten); er fängt Prüfungen ab,
    die keinen Lauf auslösen (etwa CodeQL). In privaten Repos mit CI wartet auch er nur kurz."""
    if event_name in ("schedule", "workflow_dispatch", "workflow_run") or (private and has_ci):
        return SHORT_WAIT_MINUTES
    return 45


def poll_seconds(wait_limit):
    return POLL_SECONDS if wait_limit <= SHORT_WAIT_MINUTES * 60 else LONG_POLL_SECONDS


def run(gh, event_name, event, wait_limit, sleep=time.sleep, clock=time.monotonic, has_ci=False):
    info = gh.get(f"/repos/{gh.repo}")
    owner, default_branch = info["owner"]["login"], info["default_branch"]
    method = "squash" if info.get("allow_squash_merge", True) else "merge"
    started, cache, retries, merged, failed = clock(), {}, {}, [], []
    open_prs = candidates(gh, event_name, event)
    print(f"Prüfe PRs: {open_prs or 'keine'}")

    try:
        while open_prs:
            waited = clock() - started
            for number in list(open_prs):
                pr, commits, files, checks, status, runs, unresolved = pr_facts(gh, number, cache)
                result, why = evaluate(pr, owner, default_branch, commits, files, checks, status, waited, runs,
                                       has_ci, unresolved)
                print(f"#{number}: {result} ({why})")
                if result == "wait":
                    continue
                open_prs.remove(number)
                if result == "block":
                    kind, _, detail = why.partition(":")
                    comment_once(gh, number, pr["head"]["sha"], kind,
                                 COMMENTS[kind].format(detail=detail, base=default_branch, repo=gh.repo, number=number))
                elif result == "merge":
                    held = label_hold(gh, number)
                    if held:  # Label kam erst nach dem Lesen des PRs (etwa die Frage aus der Erklärung)
                        print(f"#{number}: skip ({held})")
                        tick = TICK_HOLDS.get(held)  # nur das Häkchen hält an: sonst wüsste niemand, warum der PR wartet
                        if tick:
                            comment_once(gh, number, pr["head"]["sha"], tick, COMMENTS[tick])
                        continue
                    code, data, _ = gh.call("PUT", f"/repos/{gh.repo}/pulls/{number}/merge", {
                        "merge_method": method, "sha": pr["head"]["sha"],
                        "commit_title": f"{pr['title']} (#{number})"})
                    msg = (data or {}).get("message", "")
                    print(f"#{number}: Merge {code} {msg}")
                    if code == 200:
                        merged.append(number)
                        refresh_overview(gh, default_branch)
                    elif rate_limited(code, data):
                        raise RateLimited(f"Merge #{number}: {code} Abfrage-Kontingent erschöpft")
                    elif code == 405 and pr.get("mergeable_state") == "behind":  # wird von allein nicht aktuell
                        comment_once(gh, number, pr["head"]["sha"], "hinter",
                                     COMMENTS["hinter"].format(base=default_branch, repo=gh.repo, number=number))
                    elif code in (405, 409) and retries.get(number, 0) < 3:  # Stand geändert oder GitHub noch nicht so weit
                        retries[number] = retries.get(number, 0) + 1
                        open_prs.append(number)
                    elif "workflow" in msg.lower():
                        comment_once(gh, number, pr["head"]["sha"], "workflow", COMMENTS["workflow"])
                    else:
                        failed.append(f"#{number}: {code} {msg}")
            if not open_prs or clock() - started >= wait_limit:
                break
            sleep(poll_seconds(wait_limit))
    except RateLimited as e:
        if failed:  # ein echter Merge-Fehler davor bleibt rot
            print(f"{e}. Der nächste Lauf prüft erneut.")
            raise RuntimeError("Merge fehlgeschlagen: " + "; ".join(failed)) from None
        raise
    if open_prs:
        print(f"Zeitlimit erreicht, noch offen: {open_prs}. Der nächste Lauf prüft erneut.")
    if failed:  # roter Lauf: Der Thread, der den PR beobachtet, sieht das und kümmert sich
        raise RuntimeError("Merge fehlgeschlagen: " + "; ".join(failed))
    return merged


def refresh_overview(gh, default_branch):
    """Nach einem Merge die Übersicht der Erklärseite neu schreiben lassen: Ein Merge über GITHUB_TOKEN startet
    sonst keinen Workflow, der gemergte PR stünde bis zum nächsten Morgen als „läuft“ da. Fehlt die Erklärseite
    in diesem Repo, lehnt GitHub mit 404 ab; das ist kein Fehler."""
    code, data, _ = gh.call("POST", f"/repos/{gh.repo}/actions/workflows/erklaerseite.yml/dispatches",
                            {"ref": default_branch})
    print(f"Übersicht der Erklärseite angestoßen: {code}" + ("" if code == 204 else f" {(data or {}).get('message', '')}"))


def main():
    repo = os.environ["GITHUB_REPOSITORY"]
    gh = GitHub(os.environ["GITHUB_TOKEN"], repo, os.environ.get("GITHUB_API_URL", "https://api.github.com"))
    event_name = os.environ.get("GITHUB_EVENT_NAME", "")
    with open(os.environ["GITHUB_EVENT_PATH"], encoding="utf-8") as fh:
        event = json.load(fh)
    private = bool((event.get("repository") or {}).get("private", True))
    has_ci = os.environ.get("AUTO_MERGE_HAS_CI") == "1"
    try:
        run(gh, event_name, event, wait_minutes(event_name, private, has_ci) * 60, has_ci=has_ci)
    except RateLimited as e:  # kein Fehler des PRs: ein späterer Lauf prüft erneut
        print(f"{e}. Der nächste Lauf prüft erneut.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
