#!/usr/bin/env python3
"""Trims a Wortschatz Leipzig corpus download to the iOS keyboard's word list.

The keyboard ranks suggestions by how common a word is and which word came
before it; iOS's dictionary knows neither. Wortschatz Leipzig (Universität
Leipzig, https://wortschatz.uni-leipzig.de, CC BY) ships per corpus a
`*-words.txt` (id, word, frequency; most frequent first) and a `*-co_n.txt`
(two word ids that stood next to each other, frequency, significance).

  python3 scripts/wortschatz.py CORPUS-words.txt ios/Keyboard/wortschatz-de.txt \\
      [--pairs CORPUS-co_n.txt ios/Keyboard/wortschatz-de-pairs.txt]

Output: one `word<TAB>frequency` per line (and `word word<TAB>frequency` for
pairs), most frequent first. Only words of letters, with an inner hyphen at
most, are kept; numbers, punctuation and markup are left out. Case variants
("die", "Die") stay separate lines. The files are read as UTF-8.
"""
import argparse
import heapq
import sys
from pathlib import Path



def is_word(text):
    """Letters only ("Café" too), with at most one inner hyphen ("E-Mail")."""
    parts = text.split("-")
    return len(parts) <= 2 and all(part.isalpha() for part in parts)


def word_entries(lines):
    for line in lines:
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 3 or not parts[2].isdigit():
            continue
        word_id, word, frequency = parts[0], parts[1], int(parts[2])
        if len(word) <= 30 and is_word(word):
            yield word_id, word, frequency


def read_words(lines, limit):
    """(id → word) and the kept (word, frequency) list, most frequent first.
    Memory grows with `limit`, not with the file."""
    kept = heapq.nlargest(limit, word_entries(lines), key=lambda entry: entry[2])
    return {word_id: word for word_id, word, _ in kept}, [(word, frequency) for _, word, frequency in kept]


def read_pairs(lines, words, limit):
    """Neighbouring kept words with their frequency, most frequent first."""

    def found():
        for line in lines:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3 or not parts[2].isdigit():
                continue
            first, second = words.get(parts[0]), words.get(parts[1])
            if first and second:
                yield f"{first} {second}", int(parts[2])

    return heapq.nlargest(limit, found(), key=lambda pair: pair[1])


def write(rows, path):
    Path(path).write_text("".join(f"{text}\t{frequency}\n" for text, frequency in rows), encoding="utf-8")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("words")
    parser.add_argument("out")
    parser.add_argument("--limit", type=int, default=50_000)
    parser.add_argument("--pairs", nargs=2, metavar=("CO_N", "OUT"))
    parser.add_argument("--pairs-limit", type=int, default=100_000)
    args = parser.parse_args(argv)
    with open(args.words, encoding="utf-8", errors="replace") as handle:
        ids, words = read_words(handle, args.limit)
    if not words:
        # A different column layout skips every line: fail instead of an empty list.
        print(f"No word line could be read from {args.words}", file=sys.stderr)
        return 1
    write(words, args.out)
    print(f"{len(words)} words → {args.out}")
    if args.pairs:
        with open(args.pairs[0], encoding="utf-8", errors="replace") as handle:
            pairs = read_pairs(handle, ids, args.pairs_limit)
        write(pairs, args.pairs[1])
        print(f"{len(pairs)} pairs → {args.pairs[1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
