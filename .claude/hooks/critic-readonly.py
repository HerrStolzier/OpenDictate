#!/usr/bin/env python3
# Kopie aus HerrStolzier/claude-config (hooks/critic-readonly.py); dort pflegen, dann scripts/install-repo-gate.py erneut ausführen.
"""PreToolUse-Hook (Bash) für die lesenden Agenten `critic`, `explorer` und `Explore`: lässt ausschließlich lesende Befehle durch.

Der Befehl wird wie von der Shell zerlegt (Anführungszeichen beachtet). Jeder Teilbefehl einer
Kette (&&, ||, ;, |) muss auf der Erlaubnisliste stehen. Umleitungen, Befehlsersetzung,
Subshells und Hintergrundprozesse werden abgelehnt.
"""
import json
import os
import re
import shlex
import subprocess
import sys

SEPARATORS = {"&&", "||", "|", ";"}
SIMPLE = {"cd", "pwd", "ls", "rg", "grep", "cat", "head", "tail", "wc", "cut", "tr", "diff",
          "stat", "jq", "echo", "basename", "dirname", "realpath", "find", "git"}
GIT_READ = {"diff", "log", "show", "status", "blame", "ls-files", "ls-tree", "rev-parse", "rev-list",
            "cat-file", "describe", "merge-base", "shortlog", "reflog", "branch", "stash", "worktree",
            "for-each-ref", "diff-tree", "show-ref", "remote"}
# git akzeptiert eindeutige Abkürzungen langer Optionen (--outp = --output), deshalb Präfixe prüfen.
GIT_DANGEROUS_LONG = ("--output", "--ext-diff", "--open-files-in-pager", "--exec", "--edit-description",
                      "--textconv", "--filters")
# Diese Unterbefehle starten ein eingerichtetes textconv-Programm (gitattributes), wenn es eins gibt.
TEXTCONV_SUBS = {"diff", "log", "show", "blame", "diff-tree"}
BRANCH_READ_FLAGS = {"-a", "--all", "-r", "--remotes", "-v", "-vv", "--verbose", "--show-current", "--list",
                     "-l", "--contains", "--no-contains", "--merged", "--no-merged", "--points-at", "--sort",
                     "--format", "--column", "--no-column", "--color", "--no-color", "-i", "--ignore-case"}
# Diese Anhänge sind beim Lesen üblich und harmlos; sie werden vor der Prüfung entfernt.
HARMLESS_REDIRECTS = re.compile(r"(?<=\s)(2>/dev/null|2>&1)(?=\s|$)")
HINT = ("Erlaubt sind z. B. git diff/log/show/status/blame, ls, rg, grep, cat, head, tail, wc, "
        "find ohne -exec/-delete.")


def deny(reason: str) -> None:
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": f"Dieser Agent ist nur lesend: {reason}. {HINT}",
    }}, ensure_ascii=False))
    sys.exit(0)


def diff_programs(path: str) -> set:
    """Welche Arten von Diff-Programmen hier eingerichtet sind: "textconv" und/oder "external"."""
    try:
        out = subprocess.run(["git", "-C", path, "config", "--get-regexp",
                              r"^diff\.(external|.*\.(textconv|command))$"],
                             capture_output=True, text=True, timeout=5)
    except Exception:
        return {"textconv", "external"}  # im Zweifel sperren
    if out.returncode not in (0, 1):  # 1 = nichts eingerichtet; alles andere ist unklar
        return {"textconv", "external"}
    keys = [l.split()[0] for l in out.stdout.splitlines() if l.strip()]
    if os.environ.get("GIT_EXTERNAL_DIFF"):
        keys.append("diff.external")
    return ({"textconv"} if any(k.endswith(".textconv") for k in keys) else set()) | \
           ({"external"} if any(not k.endswith(".textconv") for k in keys) else set())


def check_git(args: list, cwd: str) -> None:
    i = 0
    while i < len(args) and args[i].startswith("-"):
        if args[i] == "-C":
            if i + 1 < len(args):
                cwd = os.path.join(cwd, os.path.expanduser(args[i + 1]))
            i += 2
        elif args[i] in ("--no-pager", "--no-optional-locks"):
            i += 1
        else:
            deny(f"git-Option {args[i]}")
    sub = args[i] if i < len(args) else ""
    rest = args[i + 1:]
    if sub not in GIT_READ:
        deny(f"git {sub or '(ohne Unterbefehl)'} ist nicht lesend")
    if sub == "branch":
        names_ok = any(a.split("=")[0] in ("--list", "-l", "--contains", "--no-contains", "--merged",
                                           "--no-merged", "--points-at") for a in rest)
        for a in rest:
            if a.startswith("-") and a.split("=")[0] not in BRANCH_READ_FLAGS:
                deny(f"git branch {a} ist nicht lesend")
            if not a.startswith("-") and not names_ok:
                deny("git branch <name> legt einen Branch an")
    if sub == "worktree" and (not rest or rest[0] != "list"):
        deny("git worktree ändert Worktrees")
    if sub == "remote" and any(a not in ("-v", "--verbose") for a in rest):
        deny("git remote nur als 'git remote -v'")
    if sub == "stash" and (not rest or rest[0] not in ("list", "show")):
        deny("git stash ändert den Stand")
    if sub == "reflog" and rest and rest[0] in ("expire", "delete"):
        deny("git reflog ändert den Stand")
    if sub in TEXTCONV_SUBS:
        progs = diff_programs(cwd)
        if "textconv" in progs and "--no-textconv" not in rest:
            deny(f"git {sub} würde hier ein textconv-Programm starten; mit --no-textconv aufrufen")
        # Ohne --ext-diff starten nur git diff (Porcelain) externe Diff-Programme; --ext-diff ist ohnehin gesperrt.
        if sub == "diff" and "external" in progs and "--no-ext-diff" not in rest:
            deny("git diff würde hier ein externes Diff-Programm starten; mit --no-ext-diff aufrufen")
    for a in rest:
        opt = a.split("=")[0]
        if opt.startswith("--") and len(opt) > 3 and opt not in ("--text", "--filter") and any(d.startswith(opt) or opt.startswith(d) for d in GIT_DANGEROUS_LONG):
            deny(f"git-Option {a}")


def check_segment(words: list, cwd: str) -> str:
    cmd, args = words[0], words[1:]
    if cmd not in SIMPLE:
        deny(f"Befehl {cmd} ist nicht freigegeben")
    if cmd == "cd":
        if len(args) > 1 or (args and args[0].startswith("-")):
            deny("cd nur mit genau einem Ordner")
        return os.path.join(cwd, os.path.expanduser(args[0])) if args else os.path.expanduser("~")
    if cmd == "git":
        check_git(args, cwd)
    elif cmd == "find" and any(a in ("-exec", "-execdir", "-ok", "-okdir", "-delete", "-fprint",
                                     "-fprint0", "-fprintf", "-fls") for a in args):
        deny("find mit schreibender Aktion")
    elif cmd == "rg" and any(a.startswith("--pre") for a in args):
        deny("rg --pre führt Programme aus")
    return cwd


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        deny("Hook-Eingabe nicht lesbar")
    cmd = (data.get("tool_input") or {}).get("command") or ""
    if not cmd.strip():
        sys.exit(0)
    if "\n" in cmd:
        deny("mehrzeiliger Befehl")
    if any(s in cmd for s in ("$(", "`", "<(", ">(")):
        deny("Befehlsersetzung")
    cmd = HARMLESS_REDIRECTS.sub("", cmd)
    try:
        lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        lex.commenters = ""  # sonst würde `x#` den Rest der Zeile verschlucken; die Shell sieht das anders
        tokens = list(lex)
    except ValueError:
        deny("Befehl nicht eindeutig lesbar (Anführungszeichen)")
    cwd = data.get("cwd") or os.getcwd()
    segment, before = [], ";"
    for tok in tokens + [";"]:
        if tok in SEPARATORS:
            if segment:
                new = check_segment(segment, cwd)
                # Teile einer Pipe laufen in einer Subshell; ein cd dort ändert den Ordner danach nicht.
                if "|" not in (before, tok):
                    cwd = new
            segment, before = [], tok
        elif tok and set(tok) <= set("();<>|&"):
            deny(f"Umleitung, Subshell oder Hintergrund ({tok})")
        else:
            segment.append(tok)
    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as exc:  # Ausfall des Wächters darf nie zum Durchlassen führen
        deny(f"Wächter-Fehler ({type(exc).__name__})")
