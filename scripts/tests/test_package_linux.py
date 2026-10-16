import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / 'package-linux.sh'


class LinuxPackagePreflightTests(unittest.TestCase):
    def test_help_and_refusal_cases_preserve_existing_content(self):
        self.assertEqual(subprocess.run(['bash', str(SCRIPT), '--help'], capture_output=True).returncode, 0)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'repo'
            (root / 'scripts').mkdir(parents=True)
            (root / 'linux/packaging/arch').mkdir(parents=True)
            for name in ['package-linux.sh', 'package-linux.py']:
                shutil.copyfile(SCRIPT.parent / name, root / 'scripts' / name)
            (root / 'linux/Cargo.toml').write_text('[package]\nname = "opendictate"\nversion = "0.1.0"\n')
            (root / 'linux/packaging/arch/PKGBUILD').write_text('pkgver=0.1.0\n')
            for args in [['init', '-q'], ['add', '.'], ['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture']]:
                subprocess.run(['git', *args], cwd=root, check=True, capture_output=True)
            output = Path(directory) / 'output'
            def package(tag):
                return subprocess.run(['bash', str(root / 'scripts/package-linux.sh'), '--tag', tag, '--output', str(output)], text=True, capture_output=True)
            result = package('linux-v0.2.0-beta.1')
            self.assertEqual(result.returncode, 1)
            self.assertIn('Version mismatch', result.stderr)
            self.assertFalse(output.exists())
            (root / 'dirty.md').write_text('preserve')
            result = package('linux-v0.1.0-beta.2')
            self.assertIn('Checkout is dirty', result.stderr)
            self.assertEqual((root / 'dirty.md').read_text(), 'preserve')
            (root / 'dirty.md').unlink()
            output.mkdir()
            (output / 'keep').write_text('preserve')
            result = package('linux-v0.1.0-beta.2')
            self.assertEqual(result.returncode, 1)
            self.assertIn('already exists', result.stderr)
            self.assertEqual((output / 'keep').read_text(), 'preserve')


if __name__ == '__main__':
    unittest.main()
