import importlib.util
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / "wortschatz.py"
SPEC = importlib.util.spec_from_file_location("wortschatz", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

WORDS = [
    "1\t!\t900\n",
    "2\tdie\t800\n",
    "3\tund\t700\n",
    "4\t2024\t650\n",
    "5\twas\t600\n",
    "6\tE-Mail\t500\n",
    "7\t<br>\t450\n",
    "8\twes\t5\n",
    "9\tübermorgen\t40\n",
    "10\tkaputt\n",
]
PAIRS = ["3\t5\t300\t12.5\n", "2\t3\t100\t3.1\n", "1\t3\t999\t1.0\n", "3\t8\t1\t0.1\n"]


class WortschatzTests(unittest.TestCase):
    def test_keeps_words_of_letters_most_frequent_first(self):
        _, words = MODULE.read_words(WORDS, 100)
        self.assertEqual(
            words, [("die", 800), ("und", 700), ("was", 600), ("E-Mail", 500), ("übermorgen", 40), ("wes", 5)])

    def test_keeps_only_the_most_frequent(self):
        ids, words = MODULE.read_words(WORDS, 2)
        self.assertEqual(words, [("die", 800), ("und", 700)])
        self.assertEqual(ids, {"2": "die", "3": "und"})

    def test_pairs_need_both_words_kept(self):
        ids, _ = MODULE.read_words(WORDS, 3)
        self.assertEqual(MODULE.read_pairs(PAIRS, ids, 10), [("und was", 300), ("die und", 100)])

    def test_pairs_keep_only_the_most_frequent(self):
        ids, _ = MODULE.read_words(WORDS, 100)
        self.assertEqual(MODULE.read_pairs(PAIRS, ids, 1), [("und was", 300)])

    def test_words_longer_than_thirty_letters_are_left_out(self):
        _, words = MODULE.read_words(["1\t" + "a" * 30 + "\t9\n", "2\t" + "b" * 31 + "\t8\n"], 10)
        self.assertEqual(words, [("a" * 30, 9)])

    def test_malformed_pair_lines_are_skipped(self):
        ids, _ = MODULE.read_words(WORDS, 100)
        lines = ["3\t5\n", "3\t5\tviele\n", "3\t5\t7\n"]
        self.assertEqual(MODULE.read_pairs(lines, ids, 10), [("und was", 7)])

    def test_words_of_other_letters_are_kept(self):
        _, words = MODULE.read_words(["1\tCafé\t9\n", "2\tVarieté\t8\n", "3\tCrème\t7\n"], 10)
        self.assertEqual(words, [("Café", 9), ("Varieté", 8), ("Crème", 7)])

    def test_two_hyphens_are_left_out(self):
        _, words = MODULE.read_words(["1\tDo-it-yourself\t9\n", "2\t-ab\t8\n", "3\tab\t7\n"], 10)
        self.assertEqual(words, [("ab", 7)])

    def test_pairs_memory_grows_with_the_limit_not_the_file(self):
        import tracemalloc
        ids = {str(i): f"w{i}" for i in range(1000)}
        lines = (f"{i % 1000}\t{(i * 7) % 1000}\t{i + 1}\t1.0\n" for i in range(200_000))
        tracemalloc.start()
        pairs = MODULE.read_pairs(lines, ids, 10)
        _, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        self.assertEqual([frequency for _, frequency in pairs], list(range(200_000, 199_990, -1)))
        self.assertLess(peak, 5_000_000)

    def test_words_memory_grows_with_the_limit_not_the_file(self):
        import tracemalloc
        lines = (f"{i}\twort\t{i + 1}\n" for i in range(200_000))
        tracemalloc.start()
        ids, _ = MODULE.read_words(lines, 10)
        _, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        self.assertEqual(len(ids), 10)
        self.assertLess(peak, 5_000_000)

    def test_main_fails_when_no_word_line_can_be_read(self):
        with tempfile.TemporaryDirectory() as folder:
            words = Path(folder, "words.txt")
            words.write_text("1\tdie\tdie\t800\n2\tund\tund\t700\n", encoding="utf-8")
            status = MODULE.main([str(words), str(Path(folder, "out.txt"))])
            self.assertEqual(status, 1)
            self.assertFalse(Path(folder, "out.txt").exists())

    def test_main_writes_tab_separated_files(self):
        with tempfile.TemporaryDirectory() as folder:
            words, co_n = Path(folder, "words.txt"), Path(folder, "co_n.txt")
            words.write_text("".join(WORDS), encoding="utf-8")
            co_n.write_text("".join(PAIRS), encoding="utf-8")
            out, pairs_out = Path(folder, "out.txt"), Path(folder, "pairs.txt")
            status = MODULE.main([str(words), str(out), "--limit", "3", "--pairs", str(co_n), str(pairs_out)])
            self.assertEqual(status, 0)
            self.assertEqual(out.read_text(encoding="utf-8"), "die\t800\nund\t700\nwas\t600\n")
            self.assertEqual(pairs_out.read_text(encoding="utf-8"), "und was\t300\ndie und\t100\n")


if __name__ == "__main__":
    unittest.main()
