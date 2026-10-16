#!/usr/bin/env python3
"""Compare supplied dictation runs offline; this does not record or send audio."""

from __future__ import annotations

import argparse
import importlib.util
import json
import math
import statistics
import sys
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("evaluate_transcripts", Path(__file__).with_name("evaluate-transcripts.py"))
EVALUATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EVALUATOR)
SMALL = "null eins zwei drei vier fünf sechs sieben acht neun zehn elf zwölf dreizehn vierzehn fünfzehn sechzehn siebzehn achtzehn neunzehn".split()
NUMBERS = {word: str(number) for number, word in enumerate(SMALL)}
for TEN, WORD in enumerate("zwanzig dreißig vierzig fünfzig sechzig siebzig achtzig neunzig".split(), 2):
    NUMBERS[WORD] = str(TEN * 10)
    for UNIT in range(1, 10):
        NUMBERS[("ein" if UNIT == 1 else SMALL[UNIT]) + "und" + WORD] = str(TEN * 10 + UNIT)
NUMBERS = {EVALUATOR.tokens(word)[0]: value for word, value in NUMBERS.items()}


def normalized_numbers(words: list[str]) -> list[str]:
    # Deliberately limited to whole numbers 0–99. Dates, decimals, compounds
    # above 99 and articles (ein/eine) remain unchanged and visible in WER.
    return [NUMBERS.get(word, str(int(word)) if word.isascii() and word.isdecimal() else word) for word in words]


def catalogue(document: object) -> dict[str, dict]:
    if not isinstance(document, dict) or not isinstance(document.get("sentences"), list) or not document["sentences"]:
        raise ValueError("catalogue must contain a non-empty sentences list")
    result = {}
    for row in document["sentences"]:
        if not isinstance(row, dict) or any(not isinstance(row.get(key), str) or not row[key].strip() for key in ("id", "group", "reference")):
            raise ValueError("each sentence needs non-empty id, group and reference strings")
        if row["id"] in result or not EVALUATOR.tokens(row["reference"]):
            raise ValueError("sentence IDs must be unique and references must contain words")
        result[row["id"]] = row
    return result


def compare(sentences: dict[str, dict], runs: list[dict]) -> dict:
    engines: dict[str, list[dict]] = {}
    seen = set()
    for row in runs:
        if not isinstance(row, dict) or any(not isinstance(row.get(key), str) or not row[key].strip() for key in ("engine", "sentence_id")) or not isinstance(row.get("hypothesis"), str):
            raise ValueError("each run needs engine, sentence_id and hypothesis strings")
        if row["sentence_id"] not in sentences:
            raise ValueError(f"unknown sentence_id: {row['sentence_id']}")
        identity = row["engine"], row["sentence_id"]
        if identity in seen:
            raise ValueError("duplicate engine/sentence pair; compare repeated sessions separately")
        seen.add(identity)
        duration = row.get("duration_seconds")
        if isinstance(duration, bool) or not isinstance(duration, (int, float)) or not math.isfinite(duration) or duration < 0 or not isinstance(row.get("background"), bool):
            raise ValueError("duration_seconds must be finite and non-negative; background must be boolean")
        engines.setdefault(row["engine"], []).append(row)
    if not engines:
        raise ValueError("no runs supplied")

    def aggregate(rows):
        errors, number_errors, words = 0, 0, 0
        for row in rows:
            reference = EVALUATOR.tokens(sentences[row["sentence_id"]]["reference"])
            hypothesis = EVALUATOR.tokens(row["hypothesis"])
            words += len(reference)
            errors += EVALUATOR.edit_counts(reference, hypothesis)["errors"]
            number_errors += EVALUATOR.edit_counts(normalized_numbers(reference), normalized_numbers(hypothesis))["errors"]
        durations = sorted(row["duration_seconds"] for row in rows)
        return {
            "runs": len(rows), "reference_words": words, "errors": errors,
            "wer": errors / words if words else None,
            "number_normalized_wer": number_errors / words if words else None,
            "median_seconds": statistics.median(durations) if durations else None,
            "p90_seconds": durations[math.ceil(.9 * len(durations)) - 1] if durations else None,
            "background_fraction": sum(row["background"] for row in rows) / len(rows) if rows else None,
        }

    result = {}
    for engine, rows in sorted(engines.items()):
        present = {row["sentence_id"] for row in rows}
        result[engine] = {
            **aggregate(rows), "missing_sentences": sorted(set(sentences) - present),
            "groups": {group: aggregate([row for row in rows if sentences[row["sentence_id"]]["group"] == group]) for group in sorted({s["group"] for s in sentences.values()})},
        }
    return {"provenance": "Offline comparison of supplied runs; no audio or engine verification. Missing sentences are excluded from WER.", "engines": result}


def markdown(report: dict) -> str:
    lines = [report["provenance"], "", "| Erkennung / Gruppe | Läufe | WER | Nach Zahlennormalisierung | Median (s) | P90 (s) | Hintergrund | Fehlende Sätze |", "| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |"]
    def cell(value):
        return str(value).replace("|", "\\|").replace("\n", " ").replace("\r", " ")
    def percentage(value):
        return "—" if value is None else f"{value:.1%}"
    def seconds(value):
        return "—" if value is None else f"{value:.2f}"
    for engine, result in report["engines"].items():
        for label, data in [(engine, result), *((f"{engine} / {group}", values) for group, values in result["groups"].items())]:
            missing = ", ".join(result["missing_sentences"]) if label == engine else "—"
            lines.append(f"| {cell(label)} | {data['runs']} | {percentage(data['wer'])} | {percentage(data['number_normalized_wer'])} | {seconds(data['median_seconds'])} | {seconds(data['p90_seconds'])} | {percentage(data['background_fraction'])} | {cell(missing) or '—'} |")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runs", type=Path, help="one JSON object per line; one session per file")
    parser.add_argument("--catalogue", type=Path, default=Path(__file__).parent / "fixtures/german-dictation-sentences.json")
    parser.add_argument("--output", type=Path, help="write JSON to a new file; Markdown still goes to stdout")
    args = parser.parse_args()
    try:
        sentences = catalogue(json.loads(args.catalogue.read_text(encoding="utf-8")))
        runs = [json.loads(line) for line in args.runs.read_text(encoding="utf-8").splitlines() if line.strip()]
        report = compare(sentences, runs)
        if args.output:
            with args.output.open("x", encoding="utf-8") as output:
                output.write(json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + "\n")
        sys.stdout.write(markdown(report))
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
