#!/usr/bin/env python3
# Kopie aus HerrStolzier/claude-config (hooks/review-gate.py); dort pflegen, dann scripts/install-repo-gate.py erneut ausführen.
"""PreToolUse-Hook: Review-Pflicht vor Commit, Push und Merge (Basti liest keinen Code, siehe global-CLAUDE.md).

- `git commit`: Enthält der Commit Code (nicht nur Text wie .md/.txt), muss die Nachricht eine Zeile
  `Reviewed-by:` tragen (Ergebnis des Agenten critic).
- `git push`: Jeder noch nicht gepushte Commit mit Code braucht diese Zeile.
- `gh pr merge` und Merge/Auto-Merge per GitHub-MCP: CI auf dem PR muss fertig und grün sein, und jeder
  Commit des PRs, der Code ändert, braucht die Zeile `Reviewed-by:`.
- Commits direkt über die GitHub-MCP-Werkzeuge (push_files, create_or_update_file, delete_file): wie `git commit`.

Bei Verstoß: deny mit Begründung an Claude, nie ask. Die Entscheidung soll bei critic und CI liegen, nicht bei Basti.
"""
import base64
import json
import os
import re
import shlex
import subprocess
from urllib.parse import quote
import sys

# Nur als eigene Zeile der Nachricht, nicht mitten im Satz ("Enforce Reviewed-by: …").
TRAILER = re.compile(r"^[ \t]*Reviewed-by:[ \t]*\S", re.M)
TEXT_SUFFIXES = (".md", ".markdown", ".txt", ".rst")
# git, dann globale Optionen wie -C <dir>, -c <k=v>, --no-pager, dann der Unterbefehl.
GIT = r"(?:^|[;&|(\s])git(?:\s+(?:-[cC]\s+(?:\"[^\"]*\"|'[^']*'|\S+)|--[\w-]+(?:=\S+)?))*\s+"
RE_COMMIT = re.compile(GIT + r"commit(?=\s|$)")
RE_PUSH = re.compile(GIT + r"push(?=\s|$)")
RE_ADD = re.compile(GIT + r"add(?=\s|$)")
RE_MERGE = re.compile(r"(?:^|[;&|(\s])gh\s+pr\s+merge(?=\s|$)")
RE_CD = re.compile(r"(?:^|[;&|(])\s*cd\s+(?=\S)")
SEPARATOR = re.compile(r"[;&|\n]")
OK_CONCLUSIONS = {"SUCCESS", "NEUTRAL", "SKIPPED"}
GH_TIMEOUT = 10
HOW = ("Lass den Agenten critic den aktuellen Stand prüfen, behebe wesentliche Befunde und trag das Ergebnis "
       "als Zeile `Reviewed-by: critic (…)` in die Commit-Nachricht ein. Frag Basti nicht nach einer "
       "Code-Bewertung; er liest keinen Code.")


def deny(reason: str) -> None:
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": f"Review-Pflicht: {reason}",
    }}, ensure_ascii=False))
    sys.exit(0)


def run(args, cwd=None, timeout=15):
    cwd = cwd if cwd and os.path.isdir(cwd) else None
    r = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    return r.returncode, r.stdout


def git(cwd, *args):
    if not os.path.isdir(cwd):
        return None
    code, out = run(["git", "-C", cwd, *args], cwd)
    return out if code == 0 else None


def lines(out):
    return [l for l in (out or "").splitlines() if l.strip()]


def needs_review(paths) -> list:
    """Dateien, die kein reiner Text sind. Reine Textkorrekturen brauchen laut Regeln kein Review."""
    return [p for p in paths if p and not p.lower().endswith(TEXT_SUFFIXES)
            and not os.path.basename(p).upper().startswith("LICENSE")]


def blank(m):
    return re.sub(r"[^\n]", " ", m.group(0))


HEREDOC = re.compile(r"(<<-?\s*['\"]?(\w+)['\"]?[^\n]*)(\n.*?\n\s*\2[ \t]*(?=\n|$))", re.S)


def strip_quotes(cmd: str) -> str:
    cmd = re.sub(r'"(?:[^"\\]|\\.)*"', lambda m: '"' + " " * (len(m.group(0)) - 2) + '"', cmd, flags=re.S)
    return re.sub(r"'[^']*'", lambda m: "'" + " " * (len(m.group(0)) - 2) + "'", cmd)


def strip_text(cmd: str) -> str:
    """Heredocs und Text in Anführungszeichen durch Leerzeichen ersetzen (gleiche Länge, damit Positionen zu `raw`
    passen). So löst z. B. eine Nachricht „vor git push“ nichts aus, und Trenner in Texten zählen nicht."""
    # Nur den Körper ausblenden; der Rest der Startzeile (`<<'EOF' && git push`) bleibt Befehl.
    cmd = HEREDOC.sub(lambda m: m.group(1) + re.sub(r".", " ", m.group(3), flags=re.S), cmd)
    return strip_quotes(cmd)


class Segment:
    """Ein Befehlsabschnitt (bis ; & | oder Zeilenende) ab dem Treffer, mit Wörtern aus dem Originalbefehl."""

    def __init__(self, raw, bare, match):
        self.start = match.start()
        m = SEPARATOR.search(bare, match.end())
        self.end = m.start() if m else len(bare)
        self.raw = raw[match.end():self.end]
        # Wörter nur bis zu einem Heredoc; dessen Inhalt ist Nachricht, keine Argumente.
        cut = strip_quotes(raw).find("<<", match.end(), self.end)
        cut = cut if cut >= 0 else self.end
        # Der Körper eines Heredocs aus einem früheren Teilbefehl (`cat <<EOF && git push`) gehört nicht dazu.
        for h in HEREDOC.finditer(raw):
            if h.start() < match.start() and match.end() <= h.start(3) < cut:
                cut = self.end = h.start(3)
                self.raw = raw[match.end():self.end]
                if "|" in strip_quotes(raw[h.start():match.end()]):
                    self.piped = h.group(3)  # `cat <<EOF | git commit -F -`: der Heredoc ist stdin
        body = HEREDOC.match(raw, cut) if cut < self.end else None
        self.heredoc = body.group(3) if body else getattr(self, "piped", "")
        try:
            self.words = shlex.split(raw[match.end():cut])
            self.parsed = True
        except ValueError:
            self.words = bare[match.end():cut].split()
            self.parsed = False
        self.prefix = raw[self.start:match.end()]


def segments(raw, bare, regex):
    return [Segment(raw, bare, m) for m in regex.finditer(bare)]


def expand(path, base):
    path = os.path.expandvars(os.path.expanduser(path))
    return path if os.path.isabs(path) else os.path.join(base, path)


def seg_dir(raw, bare, seg, cwd):
    """Arbeitsordner eines Abschnitts: `git -C <dir>` im Abschnitt, sonst das letzte `cd <dir>` davor, sonst cwd."""
    d = cwd
    for m in RE_CD.finditer(bare[:seg.start]):
        try:
            words = shlex.split(raw[m.end():(SEPARATOR.search(bare, m.end()) or re.search("$", bare)).start()])
        except ValueError:
            continue
        if words:
            d = expand(words[0], d)
    try:
        pre = shlex.split(seg.prefix)
    except ValueError:
        pre = seg.prefix.split()
    for i, w in enumerate(pre[:-1]):
        if w == "-C":
            d = expand(pre[i + 1], d)
    return d if os.path.isdir(d) else cwd


def toplevel(d):
    top = git(d, "rev-parse", "--show-toplevel")
    return top.strip() if top else None


def changed_under(top, d, paths, tracked_only=False):
    """Geänderte und (optional) neue Dateien unter den Pfaden, relativ zum Repo-Root."""
    rel = [os.path.relpath(expand(p, d), top) for p in paths]
    files = set(lines(git(top, "diff", "--name-only", "HEAD", "--", *rel) or git(top, "diff", "--name-only", "--", *rel)))
    if not tracked_only:
        files |= set(lines(git(top, "ls-files", "--others", "--exclude-standard", "--", *rel)))
    return files


def positional(words, with_value, short_value=""):
    """Argumente ohne Optionen und deren Werte. `short_value`: Kurzoptionen mit Wert, auch gebündelt (`-qm x`)."""
    out, i, rest = [], 0, False
    while i < len(words):
        w = words[i]
        if rest or not w.startswith("-") or w == "-":
            out.append(w)
        elif w == "--":
            rest = True
        elif w in with_value:
            i += 1
        elif re.fullmatch(r"-[a-zA-Z]+", w):
            # Gebündelte Kurzoptionen: die erste mit Wert nimmt den Rest (`-mtext`) oder das nächste Wort (`-qm x`).
            pos = next((k for k, ch in enumerate(w[1:], 1) if ch in short_value), None)
            if pos == len(w) - 1:
                i += 1
        i += 1
    return out


COMMIT_VALUE_OPTS = {"-m", "--message", "-F", "--file", "-C", "--reuse-message", "-c", "--reedit-message",
                     "--author", "--date", "-t", "--template", "--fixup", "--squash", "--cleanup", "--trailer",
                     "--pathspec-from-file", "-S", "--gpg-sign"}


def commit_files(top, raw, bare, seg, cwd) -> set:
    d = seg_dir(raw, bare, seg, cwd)
    files = set(lines(git(top, "diff", "--cached", "--name-only")))
    opts = [w for w in seg.words if w.startswith("-") and w != "--"]
    if any(w == "--all" or re.fullmatch(r"-[a-zA-Z]*a[a-zA-Z]*", w) for w in opts):
        files |= set(lines(git(top, "diff", "--name-only")))
    if "--amend" in opts:
        files |= set(lines(git(top, "diff-tree", "--root", "--no-commit-id", "--name-only", "-r", "HEAD")))
    paths = positional(seg.words, COMMIT_VALUE_OPTS, short_value="mFCct")
    if paths:
        files |= changed_under(top, d, paths)
    # `git add …` vorher im selben Befehl: das, was dort hinzugefügt wird, landet auch im Commit.
    for add in segments(raw, bare, RE_ADD):
        if add.start > seg.start:
            continue
        ad = seg_dir(raw, bare, add, cwd)
        if toplevel(ad) != top:
            continue
        aopts = [w for w in add.words if w.startswith("-")]
        apaths = positional(add.words, {"--pathspec-from-file", "--chmod"})
        if any(o in ("-A", "--all") for o in aopts) or (not apaths and any(o in ("-u", "--update") for o in aopts)):
            files |= changed_under(top, top, ["."], tracked_only=any(o in ("-u", "--update") for o in aopts))
        elif apaths:
            files |= changed_under(top, ad, apaths, tracked_only=any(o in ("-u", "--update") for o in aopts))
    return files


def commit_message(top, seg, cwd) -> str:
    """Die Nachricht so, wie git sie zusammensetzt: -m-Abschnitte, --trailer, -F-Datei oder -F - mit Heredoc."""
    w = seg.words
    if not seg.parsed:
        return seg.raw + "\n" + seg.heredoc  # Wörter nicht lesbar: Rohtext, Zeilenanfang zählt weiter
    parts, files, reuse = [], [], []
    i = 0
    while i < len(w):
        x = w[i]
        nxt = w[i + 1] if i + 1 < len(w) else ""
        i += 1
        if x in ("--message", "--trailer") or re.fullmatch(r"-[a-zA-Z]*m", x):
            parts.append(nxt)
            i += 1  # der Wert ist Nachricht, keine weitere Option
        elif x.startswith(("--message=", "--trailer=")):
            parts.append(x.split("=", 1)[1])
        elif re.fullmatch(r"-m.+", x):
            parts.append(x[2:])
        elif x in ("-F", "--file") or re.fullmatch(r"-[a-zA-Z]*F", x):
            files.append(nxt)
            i += 1
        elif x.startswith("--file="):
            files.append(x.split("=", 1)[1])
        elif re.fullmatch(r"-F.+", x):
            files.append(x[2:])
        elif x in ("--reuse-message", "--reedit-message") or re.fullmatch(r"-[a-zA-Z]*[cC]", x):
            reuse.append(nxt)
            i += 1
        elif x.startswith(("--reuse-message=", "--reedit-message=")):
            reuse.append(x.split("=", 1)[1])
    for path in files:
        if path == "-":
            parts.append(seg.heredoc)  # nur mit -F - liest git den Heredoc
            continue
        for base in (cwd, top):
            p = expand(path, base)
            if os.path.isfile(p):
                with open(p, encoding="utf-8", errors="ignore") as fh:
                    parts.append(fh.read())
                break
    for rev in reuse:
        parts.append(git(top, "log", "-1", "--format=%B", rev) or "")
    if "--amend" in w and "--no-edit" in w and not parts:
        parts.append(git(top, "log", "-1", "--format=%B") or "")
    return "\n\n".join(parts)


def check_commit(raw, bare, seg, cwd):
    top = toplevel(seg_dir(raw, bare, seg, cwd))
    if not top:
        return
    code = sorted(needs_review(commit_files(top, raw, bare, seg, cwd)))
    if not code or TRAILER.search(commit_message(top, seg, cwd)):
        return
    shown = ", ".join(code[:5]) + (" …" if len(code) > 5 else "")
    deny(f"Der Commit ändert Code ({shown}), aber die Nachricht hat keine Zeile `Reviewed-by:`. {HOW}")


def default_base(top, remote="origin"):
    head = git(top, "symbolic-ref", "-q", "--short", f"refs/remotes/{remote}/HEAD")
    if head and head.strip():
        return head.strip()
    for cand in (f"{remote}/main", f"{remote}/master"):
        if git(top, "rev-parse", "--verify", "-q", cand):
            return cand
    return None


def is_opt(word, full):
    """git nimmt eindeutige Abkürzungen langer Optionen an (--al = --all)."""
    # Schon `--m` reicht git, wenn eindeutig; ist sie mehrdeutig, lehnt git ab, dann schadet ein Treffer nicht.
    return word == full or (len(word) > 2 and full.startswith(word))


def default_remote(top):
    """Das Ziel von `git push` ohne Repo-Angabe, in der Reihenfolge, in der git es wählt."""
    branch = (git(top, "branch", "--show-current") or "").strip()
    keys = ([f"branch.{branch}.pushRemote"] if branch else []) + ["remote.pushDefault"] + \
           ([f"branch.{branch}.remote"] if branch else [])
    for key in keys:
        val = (git(top, "config", "--get", key) or "").strip()
        if val and val != ".":
            return val
    return "origin"


def check_push(raw, bare, seg, cwd):
    top = toplevel(seg_dir(raw, bare, seg, cwd))
    if not top:
        return
    opts = [w.split("=")[0] for w in seg.words if w.startswith("--")] + \
           [w for w in seg.words if re.fullmatch(r"-[a-zA-Z]+", w)]
    if any(re.fullmatch(r"-[a-zA-Z]*d[a-zA-Z]*", o) or is_opt(o, "--delete") for o in opts):
        return  # Löschen schiebt keine neuen Commits.
    args = positional(seg.words, {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}, short_value="o")
    remote = args[0] if args else default_remote(top)
    refspecs = args[1:] or lines(git(top, "config", "--get-all", f"remote.{remote}.push")) or ["HEAD"]
    if any(is_opt(o, n) for o in opts for n in ("--all", "--branches")) or ":" in refspecs or \
            (not args[1:] and refspecs == ["HEAD"] and
             (git(top, "config", "--get", "push.default") or "").strip() == "matching"):
        refspecs = ["refs/heads/*"]  # alle lokalen Branches
    if any(is_opt(o, "--mirror") for o in opts):
        # --mirror schiebt alle Refs; Remote-Tracking-Refs liegen schon auf einem Remote.
        refspecs = [r for r in lines(git(top, "for-each-ref", "--format=%(refname)"))
                    if not r.startswith(("refs/remotes/", "refs/stash", "refs/notes/"))]
    if any(is_opt(o, "--tags") for o in opts):
        # Ohne Refspec schiebt --tags nur die Tags, sonst zusätzlich.
        refspecs = (refspecs if args[1:] else []) + ["refs/tags/*"]
    expanded = []
    for spec in refspecs:
        src = spec.lstrip("+").partition(":")[0]
        if "*" in src:
            expanded += lines(git(top, "for-each-ref", "--format=%(refname)", src.split("*")[0]))
        else:
            expanded.append(spec)
    refspecs = expanded
    missing = []
    for spec in refspecs:
        src, _, dst = spec.lstrip("+").partition(":")
        if not src:
            continue
        if not git(top, "rev-parse", "--verify", "-q", src + "^{commit}"):
            continue
        if src == "HEAD" and not dst:
            up = git(top, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{push}") or \
                git(top, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
            base = up.strip() if up and up.strip() else None
        else:
            name = re.sub(r"^refs/(heads|tags)/", "", dst or src)
            base = f"{remote}/{name}" if git(top, "rev-parse", "--verify", "-q", f"{remote}/{name}") else None
        base = base or default_base(top, remote)
        # Ohne Vergleichsstand zählen alle Commits, die noch auf keinem Remote liegen.
        rng = [f"{base}..{src}"] if base else [src, "--not", "--remotes"]
        for c in lines(git(top, "rev-list", "--no-merges", *rng)):
            files = lines(git(top, "diff-tree", "--root", "--no-commit-id", "--name-only", "-r", c))
            if needs_review(files) and not TRAILER.search(git(top, "log", "-1", "--format=%B", c) or ""):
                missing.append((c[:8], base))
    if missing:
        hashes = ", ".join(sorted({h for h, _ in missing})[:10])
        base = missing[0][1]
        tip = (f" Da sie noch nicht auf {base} liegen, kannst du sie mit `git reset --soft {base}` zusammenfassen "
               "und nach dem Review als einen Commit neu anlegen.") if base else ""
        deny(f"Diese noch nicht gepushten Commits ändern Code ohne Zeile `Reviewed-by:`: {hashes}. {HOW}{tip}")


def gh_json(args, cwd):
    try:
        code, out = run(["gh", *args], cwd, timeout=GH_TIMEOUT)
        return json.loads(out) if code == 0 else None
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return None


def blocked(what):
    deny(f"Ich konnte {what} nicht prüfen. Ohne diese Prüfung wird nicht gemergt. "
         "Melde Basti das als Blocker in einfachen Worten.")


def pr_workflows(repo, ref, cwd) -> bool:
    """Gibt es einen Workflow, der bei PRs läuft? Workflows nur für main, Deploy oder Zeitplan zählen nicht."""
    wf = gh_json(["api", f"repos/{repo}/contents/.github/workflows?ref={ref}"], cwd)
    if not isinstance(wf, list):
        return False  # Kein Workflow-Ordner: Repo ohne CI.
    for f in wf:
        if not f.get("name", "").endswith((".yml", ".yaml")):
            continue
        body = gh_json(["api", f"repos/{repo}/contents/{f.get('path', '')}?ref={ref}"], cwd)
        if not isinstance(body, dict):
            blocked(f"den Workflow {f.get('name')}")
        try:
            text = base64.b64decode(body.get("content") or "").decode("utf-8", "ignore")
        except ValueError:
            blocked(f"den Workflow {f.get('name')}")
        if re.search(r"\bpull_request(_target)?\b", text):
            return True
    return False


def origin_repo(cwd):
    """owner/repo aus der Remote-Adresse (github.com oder ein Git-Proxy mit …/owner/repo am Ende)."""
    url = (git(cwd, "remote", "get-url", "origin") or "").strip()
    m = re.search(r"[:/]([^/:]+)/([^/]+?)(?:\.git)?/?$", url)
    return f"{m.group(1)}/{m.group(2)}" if m else None


def check_pr(repo, target, cwd):
    """Nur REST-Aufrufe (`gh api`), weil GraphQL (`gh pr view`) in Cloud-Sitzungen gesperrt ist."""
    if target:
        m = re.search(r"github\.com/([^/]+/[^/]+)/pull/(\d+)", target)
        if m:
            repo, target = m.group(1), m.group(2)
    repo = repo or origin_repo(cwd)
    if not repo:
        blocked("das Repo des PRs")
    if not target or not target.isdigit():
        branch = target or (git(cwd, "branch", "--show-current") or "").strip()
        if not branch:
            blocked("den PR (kein Branch, z. B. losgelöster HEAD)")
        found = gh_json(["api", f"repos/{repo}/pulls?state=open&head={repo.split('/')[0]}:{quote(branch, safe='')}"],
                        cwd)
        match = [p for p in found or [] if (p.get("head") or {}).get("ref") == branch] if isinstance(found, list) else []
        if not match:
            blocked(f"den PR zum Branch {branch}")
        target = str(match[0].get("number"))
    num = target
    pr = gh_json(["api", f"repos/{repo}/pulls/{num}"], cwd)
    if not isinstance(pr, dict) or not (pr.get("head") or {}).get("sha"):
        blocked(f"den PR #{num} in {repo}")
    sha = pr["head"]["sha"]
    runs = gh_json(["api", f"repos/{repo}/commits/{sha}/check-runs?per_page=100"], cwd)
    status = gh_json(["api", f"repos/{repo}/commits/{sha}/status?per_page=100"], cwd)
    if not isinstance(runs, dict) or not isinstance(status, dict):
        blocked("den CI-Stand")
    if (runs.get("total_count") or 0) > len(runs.get("check_runs") or []) or \
            (status.get("total_count") or 0) > len(status.get("statuses") or []):
        blocked("alle CI-Läufe (mehr als 100)")
    pending, failed = [], []
    for c in runs.get("check_runs") or []:
        if c.get("status") != "completed":
            pending.append(c.get("name") or "?")
        elif (c.get("conclusion") or "").upper() not in OK_CONCLUSIONS:
            failed.append(c.get("name") or "?")
    for c in status.get("statuses") or []:
        if c.get("state") == "pending":
            pending.append(c.get("context") or "?")
        elif c.get("state") != "success":
            failed.append(c.get("context") or "?")
    if failed:
        deny(f"CI ist rot ({', '.join(failed[:5])}). Erst die Ursache beheben und pushen, dann erneut mergen.")
    if pending:
        deny(f"CI läuft noch ({', '.join(pending[:5])}). Warten, bis alles grün ist, dann erneut mergen.")
    if not runs.get("check_runs") and not status.get("statuses"):
        if pr_workflows(repo, sha, cwd):
            deny("Das Repo hat CI für PRs, aber für diesen PR ist noch kein Lauf gemeldet. Kurz warten, dann "
                 "erneut mergen.")
    files = gh_json(["api", f"repos/{repo}/pulls/{num}/files?per_page=100"], cwd)
    if not isinstance(files, list):
        blocked("die Dateien des PRs")
    if len(files) < 100 and not needs_review([f.get("filename", "") for f in files]):
        return
    commits = gh_json(["api", f"repos/{repo}/pulls/{num}/commits?per_page=100"], cwd)
    if not isinstance(commits, list):
        blocked("die Commits des PRs")
    if len(commits) >= 100:
        deny(f"PR #{num} hat 100 oder mehr Commits; die kann ich nicht alle prüfen. Fasse sie zusammen "
             "(nach Review) oder teile den PR auf.")
    missing = []
    for c in commits:
        if len(c.get("parents") or []) > 1 or TRAILER.search((c.get("commit") or {}).get("message") or ""):
            continue
        detail = gh_json(["api", f"repos/{repo}/commits/{c.get('sha', '')}"], cwd)
        if not isinstance(detail, dict):
            blocked("die Dateien eines PR-Commits")
        if needs_review([f.get("filename", "") for f in detail.get("files") or []]):
            missing.append((c.get("sha") or "")[:8])
            break  # Ein Fund reicht; weitere Abfragen könnten das Zeitlimit des Hooks reißen (dann liefe der Merge durch).
    if missing:
        deny(f"PR #{num}: Mindestens dieser Commit ändert Code ohne Zeile `Reviewed-by:`: {missing[0]}. {HOW}")


def check_gh_merge(raw, bare, seg, cwd):
    with_value = {"-R", "--repo", "-t", "--subject", "-b", "--body", "-F", "--body-file",
                  "-A", "--author-email", "--match-head-commit"}
    w = seg.words
    repo = None
    for i, x in enumerate(w):
        if x in ("-R", "--repo") and i + 1 < len(w):
            repo = w[i + 1]
        elif x.startswith("--repo="):
            repo = x.split("=", 1)[1]
    if repo:
        repo = re.sub(r"^(?:https?://)?github\.com/", "", repo).strip("/")
    target = (positional(w, with_value, short_value="RtbFA") or [None])[0]
    check_pr(repo, target, seg_dir(raw, bare, seg, cwd))


def main():
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)
    tool = data.get("tool_name") or "Bash"
    ti = data.get("tool_input") or {}
    cwd = data.get("cwd") or os.getcwd()

    if tool.endswith(("merge_pull_request", "enable_pr_auto_merge")):
        repo = f"{ti.get('owner', '')}/{ti.get('repo', '')}"
        check_pr(repo, str(ti.get("pullNumber") or ti.get("pull_number") or ""), cwd)
        return
    if tool.endswith(("push_files", "create_or_update_file", "delete_file")):
        paths = [f.get("path", "") for f in ti.get("files") or []] or [ti.get("path", "")]
        code = needs_review(paths)
        if code and not TRAILER.search(ti.get("message") or ""):
            deny(f"Der Commit über GitHub ändert Code ({', '.join(code[:5])}) ohne Zeile `Reviewed-by:`. {HOW}")
        return

    raw = ti.get("command") or ""
    if not raw.strip():
        return
    bare = strip_text(raw)
    for seg in segments(raw, bare, RE_COMMIT):
        check_commit(raw, bare, seg, cwd)
    for seg in segments(raw, bare, RE_PUSH):
        check_push(raw, bare, seg, cwd)
    for seg in segments(raw, bare, RE_MERGE):
        check_gh_merge(raw, bare, seg, cwd)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as exc:  # Ein Ausfall des Wächters darf Commit, Push oder Merge nicht still durchlassen.
        deny(f"Wächter-Fehler ({type(exc).__name__}). Melde das als Blocker, statt die Prüfung zu umgehen.")
