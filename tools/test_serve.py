"""Tests of the serve tool of Haylen Runner: its QR encoder and how it follows the output of "haylen serve"."""

import io
import sys
import unittest
import urllib.parse
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import serve  # noqa: E402


class QrCodeTest(unittest.TestCase):
    # The QR code of "Haylen Runner", which the barcode reader of macOS decodes back to the text.
    KNOWN = (
        "#######..#....#######", "#.....#...#...#.....#", "#.###.#.#.#...#.###.#", "#.###.#.##.#..#.###.#", "#.###.#.#...#.#.###.#", "#.....#.#.##..#.....#", "#######.#.#.#.#######",
        "........###..........", "#.#####..###..#####..", "........#...#.....#.#", "####..#...#.#.#..###.", "..#.##.###...#.#.##..", "...#..#####.####.#..#", "........##.#.#.##....",
        "#######....###.#.###.", "#.....#.######.#####.", "#.###.#.#..##.#.#..##", "#.###.#.#....#####...", "#.###.#.#####.#...#..", "#.....#......#...##..", "#######.##.#..#....#.",
    )

    def test_a_code_holds_its_text_in_the_smallest_version(self):
        self.assertEqual(tuple("".join("#" if dark else "." for dark in row) for row in serve.QrCode("Haylen Runner").modules), self.KNOWN)
        self.assertEqual(serve.QrCode("a" * 14).version, 1)
        self.assertEqual(serve.QrCode("a" * 15).version, 2)
        self.assertEqual(serve.QrCode("a" * 2331).version, 40)
        with self.assertRaisesRegex(ValueError, "longer than a QR code holds"):
            serve.QrCode("a" * 2332)

    def test_a_large_code_carries_its_version_in_both_corners(self):
        code = serve.QrCode(serve.runner_link("http://192.168.1.20:8000/haylen/0123456789ab/app.zip") * 3)
        self.assertGreaterEqual(code.version, 7)
        near = [code.modules[index // 3][code.size - 11 + index % 3] for index in range(18)]
        far = [code.modules[code.size - 11 + index % 3][index // 3] for index in range(18)]
        self.assertEqual(near, far)
        self.assertEqual(sum(bit << index for index, bit in enumerate(near)) >> 12, code.version)

    def test_the_terminal_draws_two_rows_of_modules_in_each_line(self):
        code = serve.QrCode("Haylen Runner")
        lines = code.lines(False)
        self.assertEqual(len(lines), (code.size + 2 * serve.QrCode.QUIET_ZONE + 1) // 2)
        self.assertEqual(lines[0], "█" * (code.size + 2 * serve.QrCode.QUIET_ZONE))
        self.assertTrue(all(line.startswith("\x1b[30;107m") for line in code.lines(True)))


class ServeTest(unittest.TestCase):
    ADDRESS = "http://192.168.1.20:8000/haylen/0123456789ab/app.zip"

    def test_the_link_carries_the_address_of_the_zip(self):
        link = serve.runner_link(self.ADDRESS)
        self.assertEqual(link, "haylen-runner://open?url=http%3A%2F%2F192.168.1.20%3A8000%2Fhaylen%2F0123456789ab%2Fapp.zip")
        self.assertEqual(urllib.parse.parse_qs(urllib.parse.urlsplit(link).query)["url"], [self.ADDRESS])

    def test_the_code_follows_the_address_that_the_server_prints_in_color_or_not(self):
        for address_line in (f"  Address     {self.ADDRESS}\n", f"  \x1b[2mAddress\x1b[0m     \x1b[4m{self.ADDRESS}\x1b[0m\n"):
            output = io.StringIO()
            found = serve.follow(["  App         Demo\n", address_line, "  r  Reload what changed\n"], output, False)
            self.assertEqual(found, self.ADDRESS)
            text = output.getvalue()
            self.assertLess(text.index(address_line), text.index("█"))
            self.assertLess(text.index(serve.runner_link(self.ADDRESS)), text.index("  r  Reload what changed"))
        self.assertIsNone(serve.follow(["Error: The folder does not exist.\n"], io.StringIO(), False))


if __name__ == "__main__":
    unittest.main()
