#!/usr/bin/env python3
# Kopie aus HerrStolzier/claude-config (scripts/pruefen.py); dort pflegen, dann scripts/install-repo-gate.py erneut ausführen.
"""Prüft eine Änderung mit Läufen statt Meinung und stellt den Nachweis für die Commit-Zeile aus.

  python3 scripts/pruefen.py               geprüft wird, was mit `git add` vorgemerkt ist
  python3 scripts/pruefen.py --rev HEAD    ein schon gemachter Commit (z. B. nach `git commit --amend`)
  python3 scripts/pruefen.py --basis origin/main --melden    alles seit der Basis (CI), Exit immer 0

Ablauf: Der Stand wird in ein Wegwerf-Verzeichnis exportiert. Dort laufen die Tests des Repos. Danach werden in den
geänderten Zeilen absichtlich kleine Fehler eingebaut (Mutanten); jeder muss einen Test rot machen. Überlebt ein
Mutant, ist die Prüfung dort zu schwach: Test nachlegen oder mit --akzeptiere begründet zulassen.

Nur wenn alles besteht, steht am Ende die Zeile für die Commit-Nachricht:
  Verified-by: pruefer patch=<Fingerabdruck> fehler=<entdeckt>/<eingebaut>
Der Fingerabdruck (patch=) beschreibt den geprüften Stand der geänderten Dateien (Pfad und Blob-SHA). Wächter und
Auto-Merge vergleichen ihn mit dem echten Commit: Eine ausgedachte oder veraltete Zeile fällt auf.
Dieselbe Funktion `fingerprint` steht in hooks/review-gate.py und ci/auto_merge.py; tests/test_pruefen.py hält die
drei Kopien gleich.

Einstellungen (optional) in `pruefung.json` im Repo-Wurzelordner:
  "tests":   Befehl für alle Tests, Standard bei einem Ordner tests/: python3 -m unittest discover tests
  "gezielt": Befehl für einzelne Testdateien mit {module} oder {dateien}, Standard: python3 -m unittest {module}
  "testordner": Ordner mit Tests (Standard ["tests", "test"])
"""
import argparse
import ast
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
import time
from pathlib import Path

TRAILER_NAME = "Verified-by: pruefer"
DEFAULT_TESTS = "python3 -m unittest discover tests"
DEFAULT_TARGETED = "python3 -m unittest {module}"
MAX_MUTANTS = 40
BUDGET = 600
PER_RUN = 180
COPY_HEADER = "# Kopie aus HerrStolzier/claude-config ("  # Kopf, den scripts/install-repo-gate.py in verteilte Kopien schreibt
MAX_OUTPUT = 2_000_000
TEST_FILE = re.compile(r"(^test_.*\.py|_test\.(py|go)|\.(test|spec)\.[cm]?[jt]sx?|Tests?\.swift)$")
TEST_DIRS = {"test", "tests", "__tests__"}
CODE_SUFFIXES = (".py", ".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx", ".rs", ".swift", ".go", ".sh")


def hunk_lines(diff_text: str):
    """Hinzugefügte (+) und entfernte (-) Zeilen aus den Hunks eines Diffs; Kopfzeilen und Kontext zählen nicht.
    Ein Zeilenende \\r wird abgeschnitten, damit Windows-Dateien lokal und bei GitHub gleich zählen."""
    inside = False
    for line in diff_text.split("\n"):
        if line.startswith("diff --git"):
            inside = False
        elif line.startswith("@@"):
            inside = True
        elif inside and line[:1] in ("+", "-"):
            yield line[0], line[1:].rstrip("\r")


def fingerprint(entries) -> str:
    """Fingerabdruck des geprüften Stands: je geänderter Datei der Pfad und der Inhalt danach (Blob-SHA von git; gelöscht
    = lauter Nullen). Ändert sich der Code nach der Prüfung, auch nur in der Reihenfolge der Zeilen oder durch Verschieben
    in eine andere Datei, ändert sich der Fingerabdruck. Unabhängig von Kontext, Diff-Algorithmus und Umbenennungen
    (diese zählen als gelöscht plus neu)."""
    body = "\n".join(f"{path}\t{blob}" for path, blob in sorted(set(entries)))
    return hashlib.sha256(body.encode("utf-8", "replace")).hexdigest()[:12]


def raw_entries(raw: str) -> list:
    """(Pfad, Blob-SHA nach der Änderung) aus der Ausgabe von `git diff --raw -z --no-abbrev --no-renames`."""
    parts, out = raw.split("\0"), []
    for i in range(len(parts) - 1):
        if parts[i].startswith(":"):
            out.append((parts[i + 1], parts[i].split()[3]))
    return out


def changed_lines(diff_text: str) -> dict:
    """Datei -> Menge der hinzugefügten Zeilennummern (neue Seite)."""
    out, name, new = {}, None, 0
    for line in diff_text.split("\n"):
        if line.startswith("+++ "):
            name = line[4:].strip()
            name = None if name == "/dev/null" else (name[2:] if name.startswith("b/") else name)
        elif line.startswith("@@"):
            m = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)", line)
            new = int(m.group(1)) if m else 0
        elif name and new and line[:1] == "+" and not line.startswith("+++"):
            out.setdefault(name, set()).add(new)
            new += 1
        elif name and new and line[:1] == " ":
            new += 1
    return out


def git(root, *args, check=True):
    r = subprocess.run(["git", "-c", "core.quotePath=false", "-C", str(root), *args], capture_output=True,
                       errors="replace")
    if check and r.returncode != 0:
        raise SystemExit(f"git {' '.join(args)} ist fehlgeschlagen: {r.stderr.strip()}")
    return r.stdout


DIFF_FLAGS = ["--no-renames", "--no-ext-diff", "--no-textconv", "--no-color", "--src-prefix=a/", "--dst-prefix=b/"]


RAW_FLAGS = ["--raw", "-z", "--no-abbrev", "--no-renames", "--no-ext-diff", "--no-textconv"]


def entries_of(root, mode, value):
    """(Pfad, Blob-SHA) der Änderung: vorgemerkter Stand, ein Commit oder alles seit einer Basis."""
    if mode == "index":
        raw = git(root, "diff", "--cached", *RAW_FLAGS)
    elif mode == "rev":
        raw = git(root, "diff-tree", "--root", "-r", "--no-commit-id", *RAW_FLAGS, value)
    else:
        raw = git(root, "diff", *RAW_FLAGS, f"{value}...HEAD")
    return raw_entries(raw)


def diff_of(root, mode, value):
    if mode == "index":
        return git(root, "diff", "--cached", *DIFF_FLAGS, "-U0")
    if mode == "rev":
        return git(root, "diff-tree", "--root", "-p", "--no-commit-id", "-r", *DIFF_FLAGS, "-U0", value)
    return git(root, "diff", *DIFF_FLAGS, "-U0", f"{value}...HEAD")


def export(root, mode, value, dest: Path):
    """Der geprüfte Stand als eigenes kleines Git-Repo (manche Tests brauchen ein Repo, etwa um Kopien zu vergleichen)."""
    if mode == "index":
        git(root, "checkout-index", "-a", "-f", f"--prefix={dest}/")
    else:
        rev = value if mode == "rev" else "HEAD"
        archive = subprocess.run(["git", "-C", str(root), "archive", rev], capture_output=True)
        if archive.returncode != 0:
            raise SystemExit(f"git archive {rev} ist fehlgeschlagen: {archive.stderr.decode().strip()}")
        subprocess.run(["tar", "-x", "-C", str(dest)], input=archive.stdout, check=True)
    git(dest, "init", "-q")
    git(dest, "add", "-A")
    git(dest, "-c", "user.name=pruefen", "-c", "user.email=pruefen@localhost", "-c", "commit.gpgsign=false",
        "commit", "-qm", "export")


def evident_tests(tree: Path) -> list:
    """Dateien im Stand, die erkennbar Tests sind (nach Dateiname, oder Code in einem Ordner test/tests/__tests__).
    Gibt es welche, aber keinen bekannten Testbefehl, darf es keinen Nachweis geben: Es liefe nichts."""
    found = []
    for name in git(tree, "ls-files").splitlines():
        base, parts = os.path.basename(name), name.split("/")[:-1]
        if TEST_FILE.search(base) or (base.endswith(CODE_SUFFIXES) and base != "__init__.py"
                                      and any(p.lower() in TEST_DIRS for p in parts)):
            found.append(name)
    return found


def no_command_message(found: list) -> str:
    return (f"Im Repo liegen Tests ({', '.join(found[:3])}{', …' if len(found) > 3 else ''}), aber es ist kein Testbefehl "
            "bekannt, der sie ausführt. Ohne Lauf gibt es keinen Nachweis: `pruefung.json` mit {\"tests\": \"…\"} anlegen "
            "(docs/pruefung.md).")


def load_config(root: Path) -> dict:
    cfg = {}
    p = root / "pruefung.json"
    if p.is_file():
        cfg = json.loads(p.read_text(encoding="utf-8"))
    cfg["testordner"] = cfg.get("testordner") or ["tests", "test"]
    if "tests" not in cfg and (root / "tests").is_dir():
        cfg["tests"] = DEFAULT_TESTS
        cfg.setdefault("gezielt", DEFAULT_TARGETED)
    return cfg


def is_test_file(path: str, folders) -> bool:
    name = os.path.basename(path)
    return path.split("/")[0] in folders or name.startswith("test_") or name.endswith("_test.py")


def related_tests(tree: Path, source: str, folders) -> list:
    stem = os.path.splitext(os.path.basename(source))[0]
    names = {stem, stem.replace("_", "-"), stem.replace("-", "_")}
    found = []
    for folder in folders:
        for p in sorted((tree / folder).rglob("*.py")) if (tree / folder).is_dir() else []:
            if p.name.startswith("test_") or p.name.endswith("_test.py"):
                text = p.read_text(encoding="utf-8", errors="ignore")
                if any(n in text for n in names):
                    found.append(p.relative_to(tree).as_posix())
    return found


CMP = {ast.Eq: ("==", "!="), ast.NotEq: ("!=", "=="), ast.Lt: ("<", ">="), ast.LtE: ("<=", ">"),
       ast.Gt: (">", "<="), ast.GtE: (">=", "<"), ast.Is: ("is", "is not"), ast.IsNot: ("is not", "is"),
       ast.In: ("in", "not in"), ast.NotIn: ("not in", "in")}
WORDS = {ast.Is, ast.IsNot, ast.In, ast.NotIn}


class Positions:
    """Wandelt (Zeile, Spalte in UTF-8-Bytes) aus dem ast in Byte-Stellen der Quelle um."""

    def __init__(self, raw: bytes):
        self.raw, self.starts = raw, [0]
        for line in raw.split(b"\n")[:-1]:
            self.starts.append(self.starts[-1] + len(line) + 1)

    def start(self, n):
        return self.starts[n.lineno - 1] + n.col_offset

    def end(self, n):
        return self.starts[n.end_lineno - 1] + n.end_col_offset

    def find(self, pattern: str, begin: int, end: int):
        m = re.search(pattern.encode(), self.raw[begin:end])
        return (begin + m.start(), begin + m.end()) if m else None


def candidates(tree, pos: Positions, lines):
    """(Zeile, Beschreibung, von, bis, Ersatz) für jede Stelle in `lines`, in Reihenfolge der Quelle."""
    found = []

    def add(node, desc, span, repl):
        if span:
            found.append((node.lineno, desc, span[0], span[1], repl))

    settings = {id(n.value) for n in ast.walk(tree) if isinstance(n, ast.Assign) and isinstance(n.value, ast.Constant)
                and all(isinstance(t, ast.Name) and t.id.isupper() for t in n.targets)}
    for node in ast.walk(tree):
        if getattr(node, "lineno", None) not in lines or id(node) in settings:
            continue
        if isinstance(node, ast.Compare) and type(node.ops[0]) in CMP:
            old, new = CMP[type(node.ops[0])]
            pattern = r"\s+".join(re.escape(w) for w in old.split())
            pattern = rf"\b{pattern}\b" if type(node.ops[0]) in WORDS else pattern
            add(node, f"Vergleich {old} -> {new}",
                pos.find(pattern, pos.end(node.left), pos.start(node.comparators[0])), new)
        elif isinstance(node, ast.BoolOp):
            old, new = ("and", "or") if isinstance(node.op, ast.And) else ("or", "and")
            add(node, f"{old} -> {new}", pos.find(rf"\b{old}\b", pos.end(node.values[0]), pos.start(node.values[1])), new)
        elif isinstance(node, ast.BinOp) and isinstance(node.op, (ast.Add, ast.Sub)) \
                and not any(isinstance(x, (ast.JoinedStr, ast.Constant)) and not isinstance(getattr(x, "value", 0), int)
                            for x in (node.left, node.right)):
            old, new = ("+", "-") if isinstance(node.op, ast.Add) else ("-", "+")
            add(node, f"{old} -> {new}", pos.find(re.escape(old), pos.end(node.left), pos.start(node.right)), new)
        elif isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Not):
            start = pos.start(node)
            add(node, "not entfernt", (start, start + 3), "")
        elif isinstance(node, ast.Constant) and isinstance(node.value, bool):
            add(node, f"{node.value} -> {not node.value}", (pos.start(node), pos.end(node)), str(not node.value))
        elif isinstance(node, ast.Constant) and isinstance(node.value, int):
            add(node, f"{node.value} -> {node.value + 1}", (pos.start(node), pos.end(node)), str(node.value + 1))
        elif isinstance(node, ast.Return) and node.value is not None \
                and not (isinstance(node.value, ast.Constant) and node.value.value is None):
            add(node, "return-Wert -> None", (pos.start(node.value), pos.end(node.value)), "None")
        elif isinstance(node, (ast.If, ast.While, ast.IfExp)):
            t = node.test
            plain = not isinstance(t, (ast.Compare, ast.BoolOp, ast.Constant)) and \
                not (isinstance(t, ast.UnaryOp) and isinstance(t.op, ast.Not))
            if plain:
                text = pos.raw[pos.start(t):pos.end(t)].decode("utf-8")
                add(node, "Bedingung umgekehrt", (pos.start(t), pos.end(t)), f"not ({text})")
    found.sort(key=lambda f: (f[2], f[3], f[1]))
    return found


def edit(raw: bytes, start: int, end: int, repl: str) -> str:
    return (raw[:start] + repl.encode("utf-8") + raw[end:]).decode("utf-8")


def valid_mutants(source: str, lines) -> list:
    """[(Zeile, Beschreibung, von, bis, Ersatz)] der Mutanten, deren Quelltext sich noch übersetzen lässt."""
    pos = Positions(source.encode("utf-8"))
    out = []
    for c in candidates(ast.parse(source), pos, lines):
        try:
            ast.parse(edit(pos.raw, c[2], c[3], c[4]))
        except SyntaxError:
            continue
        out.append(c)
    return out


def mutants_of(source: str, lines) -> list:
    """[(Nummer, Zeile, Beschreibung)]"""
    return [(n, c[0], c[1]) for n, c in enumerate(valid_mutants(source, lines))]


def apply_mutant(source: str, lines, number: int) -> str:
    """Quelltext mit genau dem Mutanten `number`; alles andere (Kommentare, Shebang, Format) bleibt Zeichen für Zeichen."""
    _, _, start, end, repl = valid_mutants(source, lines)[number]
    return edit(source.encode("utf-8"), start, end, repl)


UNITTEST_ID = re.compile(r"^(?:FAIL|ERROR): \S+ \(([\w.]+)\)", re.M)
PYTEST_ID = re.compile(r"^(?:FAILED|ERROR) (\S+)", re.M)


def failing_ids(output: str) -> set:
    return set(UNITTEST_ID.findall(output)) | set(PYTEST_ID.findall(output))


def run_cmd(cmd: str, cwd: Path, timeout: int):
    """(Exit-Code, Ausgabe); Zeitüberschreitung zählt als Exit-Code -1."""
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    try:
        r = subprocess.run(shlex.split(cmd), cwd=cwd, capture_output=True, errors="replace",
                           timeout=timeout, env=env)
    except subprocess.TimeoutExpired:
        return -1, "Zeitüberschreitung"
    except OSError as exc:
        return 127, str(exc)
    return r.returncode, (r.stdout + r.stderr)[-MAX_OUTPUT:]


def pick(todo: list, limit: int) -> list:
    """Stabile Auswahl, wenn es mehr Mutanten gibt als erlaubt: nach Hash geordnet, nicht nach Stelle."""
    ranked = sorted(todo, key=lambda t: hashlib.sha256(f"{t[0]}:{t[1]}".encode()).hexdigest())
    return sorted(ranked[:limit], key=lambda t: (t[0], t[2]))


def test_command(tree: Path, name: str, cfg: dict) -> str:
    related = related_tests(tree, name, cfg["testordner"])
    if related and "gezielt" in cfg:
        modules = " ".join(r[:-3].replace("/", ".") for r in related)
        return cfg["gezielt"].replace("{module}", modules).replace("{dateien}", " ".join(related))
    return cfg["tests"]


def is_installer_copy(text: str) -> bool:
    """Kopien aus dem Installer tragen in den ersten Zeilen den Kopf; ihr Original wird in claude-config geprüft, im
    Projekt-Repo läuft kein Test gegen sie."""
    return any(line.startswith(COPY_HEADER) for line in text.splitlines()[:3])


def original_files(sources: dict) -> list:
    """Von Dateien mit gleichem Namen und gleichem Code (Kommentare zählen nicht) bleibt eine übrig, am liebsten die ohne
    Punkt-Ordner im Pfad. Eine Kopie wie `.claude/x.py` verteilt nur das Original, und kein Test läuft gegen sie."""
    groups = {}
    for name, text in sources.items():
        code = "\n".join(line for line in text.split("\n") if not line.lstrip().startswith("#"))
        key = (os.path.basename(name), hashlib.sha256(code.encode("utf-8")).hexdigest())
        groups.setdefault(key, []).append(name)
    return sorted(min(g, key=lambda n: (any(p.startswith(".") for p in n.split("/")), n)) for g in groups.values())


def mutation_run(tree: Path, files: dict, cfg: dict, limit: int, budget: int, waived: set):
    """Gibt (eingebaut, entdeckt, Überlebende, Rest ohne Prüfung, akzeptiert, mögliche) zurück.

    Ein Test, der schon bei einer wirkungslosen Änderung der Datei (ein Zeilenumbruch am Ende) rot wird, vergleicht nur
    Dateiinhalte, etwa eine Kopie mit dem Original. Er zählt nicht als Beleg, dass ein Fehler entdeckt wurde."""
    sources = {}
    for name in sorted(files):
        path = tree / name
        if name.endswith(".py") and not is_test_file(name, cfg["testordner"]) and path.is_file():
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            if not is_installer_copy(text):
                sources[name] = text
    todo = []
    for name in original_files(sources):
        try:
            found = mutants_of(sources[name], files[name])
        except SyntaxError:
            continue
        todo += [(name, n, ln, desc) for n, ln, desc in found]
    total_found = len(todo)
    todo = pick(todo, limit) if len(todo) > limit else todo
    started, killed, survivors, accepted, left, done = time.monotonic(), 0, [], [], 0, 0
    neutral = {}
    for name, number, lineno, desc in todo:
        if time.monotonic() - started > budget:
            left = len(todo) - done
            break
        path = tree / name
        original = path.read_text(encoding="utf-8")
        cmd = test_command(tree, name, cfg)
        try:
            if name not in neutral:
                path.write_text(original + "\n", encoding="utf-8")
                code, out = run_cmd(cmd, tree, PER_RUN)
                neutral[name] = failing_ids(out) if code != 0 else set()
            path.write_text(apply_mutant(original, files[name], number), encoding="utf-8")
            code, out = run_cmd(cmd, tree, PER_RUN)
        finally:
            path.write_text(original, encoding="utf-8")
        done += 1
        ids = failing_ids(out) if code != 0 else set()
        key = f"{name}:{lineno}"
        if code != 0 and (not ids or ids - neutral[name]):
            killed += 1
        elif key in waived:
            accepted.append(key)
        else:
            survivors.append((name, lineno, desc))
    return len(todo) - left, killed, survivors, left, accepted, total_found


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--rev", help="einen schon gemachten Commit prüfen")
    ap.add_argument("--basis", help="alles seit dieser Basis prüfen (CI)")
    ap.add_argument("--melden", action="store_true", help="nur berichten, Exit-Code immer 0")
    ap.add_argument("--akzeptiere", action="append", default=[], metavar="DATEI:ZEILE",
                    help="überlebenden Mutanten begründet zulassen; erscheint in der Commit-Zeile")
    ap.add_argument("--max", type=int, default=MAX_MUTANTS, help="höchstens so viele Mutanten (mindestens 1)")
    ap.add_argument("--zeit", type=int, default=BUDGET, help="Sekunden für alle Mutanten (mindestens 1)")
    ap.add_argument("--repo", default=".", help="Repo-Ordner (Standard: aktueller Ordner)")
    args = ap.parse_args(argv)
    if args.max < 1 or args.zeit < 1:
        ap.error("--max und --zeit müssen mindestens 1 sein")

    root = Path(git(args.repo, "rev-parse", "--show-toplevel").strip())
    mode, value = ("rev", args.rev) if args.rev else ("basis", args.basis) if args.basis else ("index", None)
    diff = diff_of(root, mode, value)
    if not diff.strip():
        print("Nichts zu prüfen: kein vorgemerkter Unterschied (git add?), oder der Commit ist leer.")
        return 0 if args.melden else 1
    fp = fingerprint(entries_of(root, mode, value))
    cfg = load_config(root)
    files = changed_lines(diff)
    ok = True
    ran, killed, survivors, left, accepted, total = 0, 0, [], 0, [], 0
    note = []

    with tempfile.TemporaryDirectory(prefix="pruefen-") as tmp:
        tree = Path(tmp) / "stand"
        tree.mkdir()
        export(root, mode, value, tree)
        missing = sorted(f for f in files if f.endswith(".py") and not (tree / f).is_file())
        if missing:
            raise SystemExit(f"Geänderte Python-Datei im geprüften Stand nicht gefunden: {', '.join(missing)}. "
                             "Kein Nachweis, damit nicht still nichts geprüft wird.")
        found = evident_tests(tree) if "tests" not in cfg else []
        if found:
            print(no_command_message(found))
            ok = False
        elif "tests" not in cfg:
            note.append("Keine Tests im Repo (kein Ordner tests/, keine pruefung.json): nur der Fingerabdruck wird bestätigt.")
        else:
            code, tail = run_cmd(cfg["tests"], tree, PER_RUN * 5)
            standard = cfg["tests"] == DEFAULT_TESTS
            if standard and re.search(r"^Ran 0 tests", tail, re.M):
                del cfg["tests"]
                found = evident_tests(tree)
                if found:
                    print("Der Standardbefehl (unittest) findet keinen dieser Tests. " + no_command_message(found))
                    ok = False
                else:
                    note.append("Der Standardbefehl (unittest) findet in tests/ keine Tests: nur der Fingerabdruck wird bestätigt.")
            elif code != 0:
                print(f"Die Tests sind im geprüften Stand rot (Exit {code}):\n{tail[-1500:]}")
                if standard:
                    print("Hinweis: Nutzt das Repo andere Tests als unittest (etwa pytest)? Dann `pruefung.json` mit "
                          "{\"tests\": \"…\"} anlegen (docs/pruefung.md).")
                ok = False
            else:
                print("Alle Tests laufen grün auf dem geprüften Stand.")
                ran, killed, survivors, left, accepted, total = mutation_run(
                    tree, files, cfg, args.max, args.zeit, set(args.akzeptiere))
                py = [f for f in files if f.endswith(".py") and not is_test_file(f, cfg["testordner"])]
                if not py:
                    note.append("Keine geänderten Python-Zeilen außerhalb der Tests: kein Fehler-Einbau nötig.")
                elif total == 0:
                    note.append("In den geänderten Zeilen gibt es nichts, was sich sinnvoll abändern lässt.")
                if total > ran + left:
                    note.append(f"Stichprobe: {ran + left} von {total} möglichen Mutanten.")
                if left:
                    note.append(f"Zeitbudget aufgebraucht: {left} Mutanten blieben ungeprüft.")

    for n in note:
        print(n)
    if "tests" in cfg and ok:
        print(f"Eingebaute Fehler: {ran}, entdeckt: {killed}, übrig: {len(survivors)}")
    for name, line, desc in survivors:
        print(f"  NICHT ENTDECKT: {name}:{line} ({desc}). Test nachlegen oder mit "
              f"--akzeptiere {name}:{line} begründet zulassen.")
        ok = False
    if not ok:
        print("Kein Nachweis ausgestellt.")
        return 0 if args.melden else 1
    if args.melden or mode == "basis":
        print(f"patch={fp}")
        return 0
    extra = f" akzeptiert={','.join(accepted)}" if accepted else ""
    unchecked = f" ungeprueft={left}" if left else ""
    sample = f" von={total}" if total > ran + left else ""
    rate = f"{killed}/{ran}" if "tests" in cfg and ran else "n/a"
    print(f"\n{TRAILER_NAME} patch={fp} fehler={rate}{sample}{unchecked}{extra}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
