import importlib.util
import os
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "measure-process.py"
SPEC = importlib.util.spec_from_file_location("measure_process", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class MeasureProcessTests(unittest.TestCase):
    def test_foreign_temporary_file_survives_name_collision(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "result.json"
            temporary = output.with_name(f".{output.name}.{os.getpid()}.tmp")
            sentinel = b"belongs to another writer\n"
            temporary.write_bytes(sentinel)

            with self.assertRaises(FileExistsError):
                MODULE.write_result(output, {"status": "completed"})

            self.assertEqual(temporary.read_bytes(), sentinel)
            self.assertFalse(output.exists())

    def test_existing_output_survives_atomic_link(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "result.json"
            sentinel = b"existing final result\n"
            output.write_bytes(sentinel)

            with self.assertRaises(FileExistsError):
                MODULE.write_result(output, {"status": "completed"})

            self.assertEqual(output.read_bytes(), sentinel)
            temporary = output.with_name(f".{output.name}.{os.getpid()}.tmp")
            self.assertFalse(temporary.exists())

    def test_parse_cpu_time_formats(self):
        cases = {
            "01:02": 62.0,
            "1:02:03": 3723.0,
            "2-01:02:03.5": 176523.5,
        }
        for value, expected in cases.items():
            with self.subTest(value=value):
                self.assertEqual(MODULE.parse_cpu_time(value), expected)


if __name__ == "__main__":
    unittest.main()
