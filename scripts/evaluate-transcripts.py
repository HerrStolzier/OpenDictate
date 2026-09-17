#!/usr/bin/env python3
"""Evaluate supplied reference/hypothesis transcript pairs without network access."""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
import unicodedata
from pathlib import Path
from typing import Any

TOKEN_RE = re.compile(r"[^\W_]+(?:['’][^\W_]+)*", re.UNICODE)
MEASUREMENTS = ("correction_time_seconds", "time_to_first_text_seconds", "stop_to_final_text_seconds")


def tokens(text: str) -> list[str]:
    return TOKEN_RE.findall(unicodedata.normalize("NFKC", text).casefold())


def edit_counts(reference: list[str], hypothesis: list[str]) -> dict[str, int]:
    # Cells hold (total errors, substitutions, deletions, insertions).
    previous = [(i, 0, i, 0) for i in range(len(reference) + 1)]
    for hyp_index, hyp_token in enumerate(hypothesis, start=1):
        current = [(hyp_index, 0, 0, hyp_index)]
        for ref_index, ref_token in enumerate(reference, start=1):
            if ref_token == hyp_token:
                current.append(previous[ref_index - 1])
                continue
            substitution = previous[ref_index - 1]
            deletion = current[ref_index - 1]
            insertion = previous[ref_index]
            current.append(
                min(
                    (substitution[0] + 1, substitution[1] + 1, substitution[2], substitution[3]),
                    (deletion[0] + 1, deletion[1], deletion[2] + 1, deletion[3]),
                    (insertion[0] + 1, insertion[1], insertion[2], insertion[3] + 1),
                )
            )
        previous = current
    total, substitutions, deletions, insertions = previous[-1]
    return {"errors": total, "substitutions": substitutions, "deletions": deletions, "insertions": insertions}


def string_list(case: dict[str, Any], field: str) -> list[str]:
    value = case.get(field, [])
    if not isinstance(value, list) or any(not isinstance(item, str) or not item.strip() for item in value):
        raise ValueError(f"{case.get('id', '<unknown>')}: {field} must contain non-empty strings")
    return value


def term_result(value: str, hypothesis: list[str]) -> dict[str, Any]:
    expected = tokens(value)
    if not expected:
        raise ValueError(f"expected value {value!r} contains no word tokens")
    present = any(
        hypothesis[index : index + len(expected)] == expected
        for index in range(len(hypothesis) - len(expected) + 1)
    )
    return {"value": value, "present": present}


def evaluate_case(case: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(case, dict):
        raise ValueError("each case must be a JSON object")
    case_id, reference, hypothesis = case.get("id"), case.get("reference"), case.get("hypothesis")
    if not isinstance(case_id, str) or not case_id.strip():
        raise ValueError("each case needs a non-empty string id")
    if not isinstance(reference, str) or not isinstance(hypothesis, str):
        raise ValueError(f"{case_id}: reference and hypothesis must be strings")
    reference_words, hypothesis_words = tokens(reference), tokens(hypothesis)
    counts = edit_counts(reference_words, hypothesis_words)
    expectations = {
        field: [term_result(item, hypothesis_words) for item in string_list(case, field)]
        for field in ("expected_terms", "expected_names", "expected_numbers")
    }
    measurements: dict[str, float | None] = {}
    for field in MEASUREMENTS:
        value = case.get(field)
        if value is not None and (
            isinstance(value, bool)
            or not isinstance(value, (int, float))
            or (isinstance(value, float) and not math.isfinite(value))
            or value < 0
        ):
            raise ValueError(f"{case_id}: {field} must be a finite non-negative number or null")
        measurements[field] = value
    return {
        "id": case_id,
        "reference_words": len(reference_words),
        **counts,
        "wer": counts["errors"] / len(reference_words) if reference_words else None,
        **expectations,
        **measurements,
    }


def evaluate(document: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(document, dict) or not isinstance(document.get("cases"), list):
        raise ValueError("top-level JSON must contain a cases array")
    results = [evaluate_case(case) for case in document["cases"]]
    ids = [result["id"] for result in results]
    if len(ids) != len(set(ids)):
        raise ValueError("case ids must be unique")
    totals = {
        key: sum(result[key] for result in results)
        for key in ("reference_words", "errors", "substitutions", "deletions", "insertions")
    }
    expectation_counts = {}
    for field in ("expected_terms", "expected_names", "expected_numbers"):
        entries = [entry for result in results for entry in result[field]]
        expectation_counts[field] = {"expected": len(entries), "missing": sum(not entry["present"] for entry in entries)}
    measurement_summary = {}
    for field in MEASUREMENTS:
        values = [result[field] for result in results if result[field] is not None]
        measurement_summary[field] = {
            "reported_cases": len(values),
            "missing_cases": len(results) - len(values),
            "mean": sum(values) / len(values) if values else None,
        }
    return {
        "provenance": "offline evaluation of user-supplied references and transcripts; no audio or provider verification",
        "cases": results,
        "aggregate": {
            "case_count": len(results),
            **totals,
            "wer": totals["errors"] / totals["reference_words"] if totals["reference_words"] else None,
            **expectation_counts,
            "measurements": measurement_summary,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="UTF-8 JSON corpus results")
    parser.add_argument("--output", type=Path, help="write the JSON report instead of printing it")
    args = parser.parse_args()
    try:
        document = json.loads(
            args.input.read_text(encoding="utf-8"),
            parse_constant=lambda value: (_ for _ in ()).throw(ValueError(f"non-finite JSON number: {value}")),
        )
        report = evaluate(document)
        rendered = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + "\n"
        if args.output:
            with args.output.open("x", encoding="utf-8") as output:
                output.write(rendered)
        else:
            sys.stdout.write(rendered)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
