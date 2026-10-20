#!/usr/bin/env python3
"""Serves a Haylen app to Haylen Runner on the local network with hot reload, and prints the QR code of the link that opens the runner.

It runs "haylen serve <app>" with the options it does not know, which serves the zip of the package and its development server behind the token of the run, and shows its output and its keys as they are. Once the address of the zip shows, it prints the QR code of the link "haylen-runner://open?url=<address>", which the camera of a phone opens in the runner, and which the scanner of the runner reads too. It uses the standard library of Python alone.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import urllib.parse

SCHEME = "haylen-runner"
ESCAPES = re.compile(r"\x1b\[[0-9;]*m")
ADDRESS = re.compile(r"http://\S+/haylen/[0-9a-f]+/app\.zip")


class QrCode:
    """A QR code of a text in byte mode with the error correction level M, which survives a smudge or a glare on the screen it is read from, in the smallest version that holds the text, with the mask of the lowest penalty that ISO/IEC 18004 counts. Its `modules` are rows of dark (`True`) and light modules, without the quiet zone."""

    # The error correction codewords of each block and the number of blocks of every version at the level M, from 1 to 40, with nothing at the index 0.
    ECC_PER_BLOCK = (0, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28)
    BLOCKS = (0, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49)
    # The level M in the format information, and the patterns that the format and the version information follow.
    FORMAT_LEVEL = 0b00
    FORMAT_GENERATOR, FORMAT_MASK = 0x537, 0x5412
    VERSION_GENERATOR = 0x1F25
    BYTE_MODE = 0b0100
    PADDING = (0xEC, 0x11)
    QUIET_ZONE = 4

    def __init__(self, text: str) -> None:
        data = text.encode()
        self.version = next((version for version in range(1, 41) if 4 + QrCode.count_bits(version) + 8 * len(data) <= 8 * QrCode.data_codewords(version)), None)
        if self.version is None:
            raise ValueError(f"The text of {len(data)} bytes is longer than a QR code holds.")
        self.size = 17 + 4 * self.version
        self.modules = [[False] * self.size for _ in range(self.size)]
        self.function = [[False] * self.size for _ in range(self.size)]
        self.draw_function_patterns()
        self.draw_codewords(self.interleave(self.encode(data)))
        best = min(range(8), key=self.masked_penalty)
        self.apply_mask(best)
        self.draw_format(best)

    @staticmethod
    def count_bits(version: int) -> int:
        return 8 if version <= 9 else 16

    @staticmethod
    def raw_modules(version: int) -> int:
        """Counts the modules of a version that hold data and error correction, which is every module outside the function patterns."""
        result = (16 * version + 128) * version + 64
        if version >= 2:
            aligned = version // 7 + 2
            result -= (25 * aligned - 10) * aligned - 55
            if version >= 7:
                result -= 36
        return result

    @staticmethod
    def data_codewords(version: int) -> int:
        return QrCode.raw_modules(version) // 8 - QrCode.ECC_PER_BLOCK[version] * QrCode.BLOCKS[version]

    def alignment_positions(self) -> list[int]:
        if self.version == 1:
            return []
        aligned = self.version // 7 + 2
        step = (self.version * 8 + aligned * 3 + 5) // (aligned * 4 - 4) * 2
        return [6] + [self.size - 7 - index * step for index in range(aligned - 1)][::-1]

    def set_function(self, x: int, y: int, dark: bool) -> None:
        self.modules[y][x] = dark
        self.function[y][x] = True

    def draw_function_patterns(self) -> None:
        """Draws the timing patterns, the three finder patterns with their separators, the alignment patterns, a reserved format area and the version information of version 7 and above."""
        for index in range(self.size):
            self.set_function(6, index, index % 2 == 0)
            self.set_function(index, 6, index % 2 == 0)
        for x, y in ((3, 3), (self.size - 4, 3), (3, self.size - 4)):
            for dy in range(-4, 5):
                for dx in range(-4, 5):
                    if 0 <= x + dx < self.size and 0 <= y + dy < self.size:
                        self.set_function(x + dx, y + dy, max(abs(dx), abs(dy)) not in (2, 4))
        positions = self.alignment_positions()
        corners = {(positions[0], positions[0]), (positions[0], positions[-1]), (positions[-1], positions[0])} if positions else set()
        for x in positions:
            for y in positions:
                if (x, y) in corners:
                    continue
                for dy in range(-2, 3):
                    for dx in range(-2, 3):
                        self.set_function(x + dx, y + dy, max(abs(dx), abs(dy)) != 1)
        self.draw_format(0)
        if self.version >= 7:
            remainder = self.version
            for _ in range(12):
                remainder = (remainder << 1) ^ ((remainder >> 11) * QrCode.VERSION_GENERATOR)
            bits = self.version << 12 | remainder
            for index in range(18):
                dark = bool(bits >> index & 1)
                near, far = index // 3, self.size - 11 + index % 3
                self.set_function(far, near, dark)
                self.set_function(near, far, dark)

    def draw_format(self, mask: int) -> None:
        """Draws both copies of the format information, the level and the mask with their error correction, and the dark module next to the bottom finder."""
        data = QrCode.FORMAT_LEVEL << 3 | mask
        remainder = data
        for _ in range(10):
            remainder = (remainder << 1) ^ ((remainder >> 9) * QrCode.FORMAT_GENERATOR)
        bits = (data << 10 | remainder) ^ QrCode.FORMAT_MASK
        bit = [bool(bits >> index & 1) for index in range(15)]
        for index in range(6):
            self.set_function(8, index, bit[index])
        self.set_function(8, 7, bit[6])
        self.set_function(8, 8, bit[7])
        self.set_function(7, 8, bit[8])
        for index in range(9, 15):
            self.set_function(14 - index, 8, bit[index])
        for index in range(8):
            self.set_function(self.size - 1 - index, 8, bit[index])
        for index in range(8, 15):
            self.set_function(8, self.size - 15 + index, bit[index])
        self.set_function(8, self.size - 8, True)

    def encode(self, data: bytes) -> list[int]:
        """Writes the mode, the length and the bytes of the text, the terminator and the padding into the data codewords of the version."""
        capacity = 8 * QrCode.data_codewords(self.version)
        bits = f"{QrCode.BYTE_MODE:04b}{len(data):0{QrCode.count_bits(self.version)}b}" + "".join(f"{byte:08b}" for byte in data)
        bits += "0" * min(4, capacity - len(bits))
        bits += "0" * (-len(bits) % 8)
        codewords = [int(bits[index : index + 8], 2) for index in range(0, len(bits), 8)]
        codewords += [QrCode.PADDING[index % 2] for index in range(capacity // 8 - len(codewords))]
        return codewords

    @staticmethod
    def multiply(x: int, y: int) -> int:
        """Multiplies two elements of the field GF(256) of the polynomial 0x11D."""
        product = 0
        for index in range(7, -1, -1):
            product = (product << 1) ^ ((product >> 7) * 0x11D)
            product ^= (y >> index & 1) * x
        return product

    @staticmethod
    def divisor(degree: int) -> list[int]:
        """The generator polynomial of Reed-Solomon codes of a degree, without its leading term."""
        result = [0] * (degree - 1) + [1]
        root = 1
        for _ in range(degree):
            for index in range(degree):
                result[index] = QrCode.multiply(result[index], root)
                if index + 1 < degree:
                    result[index] ^= result[index + 1]
            root = QrCode.multiply(root, 0x02)
        return result

    @staticmethod
    def remainder(data: list[int], divisor: list[int]) -> list[int]:
        result = [0] * len(divisor)
        for byte in data:
            factor = byte ^ result.pop(0)
            result.append(0)
            for index, coefficient in enumerate(divisor):
                result[index] ^= QrCode.multiply(coefficient, factor)
        return result

    def interleave(self, data: list[int]) -> list[int]:
        """Splits the data codewords into the blocks of the version, adds the error correction of each block and interleaves the blocks, the short ones first."""
        blocks, ecc = QrCode.BLOCKS[self.version], QrCode.ECC_PER_BLOCK[self.version]
        raw = QrCode.raw_modules(self.version) // 8
        short_blocks, short_length = blocks - raw % blocks, raw // blocks
        divisor = QrCode.divisor(ecc)
        split, start = [], 0
        for index in range(blocks):
            length = short_length - ecc + (0 if index < short_blocks else 1)
            block = data[start : start + length]
            start += length
            split.append((block, QrCode.remainder(block, divisor)))
        result = []
        for index in range(short_length - ecc + 1):
            result += [block[index] for block, _ in split if index < len(block)]
        for index in range(ecc):
            result += [correction[index] for _, correction in split]
        return result

    def draw_codewords(self, codewords: list[int]) -> None:
        """Places the bits of the codewords in the zigzag of two columns from the bottom right corner, skipping the function patterns and the vertical timing pattern."""
        bits = [bool(codeword >> (7 - index) & 1) for codeword in codewords for index in range(8)]
        position = 0
        right = self.size - 1
        while right >= 1:
            if right == 6:
                right = 5
            upward = (right + 1) & 2 == 0
            for vertical in range(self.size):
                y = self.size - 1 - vertical if upward else vertical
                for x in (right, right - 1):
                    if not self.function[y][x] and position < len(bits):
                        self.modules[y][x] = bits[position]
                        position += 1
            right -= 2

    @staticmethod
    def masked(mask: int, x: int, y: int) -> bool:
        return (
            (x + y) % 2 == 0,
            y % 2 == 0,
            x % 3 == 0,
            (x + y) % 3 == 0,
            (x // 3 + y // 2) % 2 == 0,
            x * y % 2 + x * y % 3 == 0,
            (x * y % 2 + x * y % 3) % 2 == 0,
            ((x + y) % 2 + x * y % 3) % 2 == 0,
        )[mask]

    def apply_mask(self, mask: int) -> None:
        """Flips the data modules where the mask pattern holds, and applying the same mask again undoes it."""
        for y in range(self.size):
            for x in range(self.size):
                if not self.function[y][x] and QrCode.masked(mask, x, y):
                    self.modules[y][x] = not self.modules[y][x]

    def masked_penalty(self, mask: int) -> int:
        self.apply_mask(mask)
        self.draw_format(mask)
        score = self.penalty()
        self.apply_mask(mask)
        return score

    def penalty(self) -> int:
        """Counts the four penalties of the standard: runs of five modules or more of one color, blocks of two by two modules of one color, patterns of the rows and columns that look like a finder, and how far the share of dark modules is from half."""
        rows = ["".join("1" if dark else "0" for dark in row) for row in self.modules]
        lines = rows + ["".join(row[x] for row in rows) for x in range(self.size)]
        score = 0
        for line in lines:
            score += sum(len(run) - 2 for run in re.findall(r"0{5,}|1{5,}", line))
            score += 40 * len(re.findall(r"(?=10111010000|00001011101)", "0000" + line + "0000"))
        for y in range(self.size - 1):
            for x in range(self.size - 1):
                if self.modules[y][x] == self.modules[y][x + 1] == self.modules[y + 1][x] == self.modules[y + 1][x + 1]:
                    score += 3
        dark = sum(row.count("1") for row in rows)
        total = self.size * self.size
        return score + 10 * ((abs(dark * 20 - total * 10) + total - 1) // total - 1)

    def lines(self, color: bool) -> list[str]:
        """Draws the code with its quiet zone in half blocks, two rows of modules to a line of text. With color the modules are black on white. Without it the light modules are the blocks, which reads on a terminal with light text on a dark background."""
        size = self.size + 2 * QrCode.QUIET_ZONE
        dark = [[0 <= y - QrCode.QUIET_ZONE < self.size and 0 <= x - QrCode.QUIET_ZONE < self.size and self.modules[y - QrCode.QUIET_ZONE][x - QrCode.QUIET_ZONE] for x in range(size)] for y in range(size + 1)]
        result = []
        for y in range(0, size, 2):
            if color:
                text = "".join(" ▄▀█"[2 * upper + lower] for upper, lower in zip(dark[y], dark[y + 1]))
                result.append(f"\x1b[30;107m{text}\x1b[0m")
            else:
                result.append("".join(" ▄▀█"[2 * (not upper) + (not lower)] for upper, lower in zip(dark[y], dark[y + 1])))
        return result


def runner_link(address: str) -> str:
    """The link that opens Haylen Runner with the address of the zip of an app."""
    return f"{SCHEME}://open?url={urllib.parse.quote(address, safe='')}"


def shows_color(stream) -> bool:
    """Tells whether a stream prints color, by the same rule as the command haylen: never with "NO_COLOR", always with "FORCE_COLOR", and otherwise on a terminal that is not "dumb"."""
    if os.environ.get("NO_COLOR"):
        return False
    return bool(os.environ.get("FORCE_COLOR")) or (stream.isatty() and os.environ.get("TERM") != "dumb")


def follow(lines, output, color: bool) -> str | None:
    """Prints the lines of the server as they come, and the QR code of the link once the address of the zip shows, and returns that address."""
    address = None
    for line in lines:
        output.write(line)
        output.flush()
        found = ADDRESS.search(ESCAPES.sub("", line))
        if address is None and found:
            address = found[0]
            link = runner_link(address)
            output.write("\n" + "\n".join(QrCode(link).lines(color)) + "\n\n")
            output.write(f"  Scan the code with the camera of the device or the scanner of Haylen Runner, or open the link {link}\n\n")
            output.flush()
    return address


def main(arguments: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Serve a Haylen app to Haylen Runner with hot reload, and print the QR code of the link that opens the runner. Every other option goes to \"haylen serve\", such as \"--port\" and \"--host\".")
    parser.add_argument("app", help="The folder of the Haylen app.")
    parser.add_argument("--haylen", default="haylen", help="The command haylen of a checkout of Haylen, \"haylen\" on the path by default.")
    options, rest = parser.parse_known_args(arguments)
    command = shutil.which(options.haylen)
    if command is None:
        print(f'The command "{options.haylen}" is not on the path. Put the root of a checkout of Haylen on the path, or name its command haylen with "--haylen".', file=sys.stderr)
        return 1
    color = shows_color(sys.stdout)
    environment = {**os.environ, "FORCE_COLOR": "1"} if color else {**os.environ, "NO_COLOR": "1"}
    # The server reads its keys from the terminal, which it shares with this script.
    with subprocess.Popen([command, "serve", options.app, *rest], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", env=environment) as server:
        try:
            follow(server.stdout, sys.stdout, color)
        except KeyboardInterrupt:
            server.terminate()
        return server.wait()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
