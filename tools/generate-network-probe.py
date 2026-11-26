#!/usr/bin/env python3
"""Reproduce the immutable MiniOS v1 network probe without external dependencies."""
import argparse
import hashlib
from pathlib import Path

SEED = b"MiniOS network connectivity probe v1\n"
SIZE = 1024 * 1024
NAME = "minios-network-probe-v1-1m.bin"


def payload():
    return hashlib.shake_256(SEED).digest(SIZE)


def generate(directory):
    data = payload()
    digest = hashlib.sha256(data).hexdigest()
    files = {
        NAME: data,
        NAME + ".sha256": (digest + "  " + NAME + "\n").encode("ascii"),
        "README.txt": (
            "MiniOS network connectivity probe v1\n\n"
            "Purpose: test sustained HTTPS transfer for MiniOS network fallback.\n"
            "Size: 1048576 bytes (1 MiB), downloaded in one request.\n"
            "Content: deterministic, poorly compressible synthetic bytes; no user data.\n"
            "Generation: hashlib.shake_256(b'MiniOS network connectivity probe v1\\n').digest(1048576)\n"
            "SHA-256: " + digest + "\n\n"
            "Keep this version immutable. Do not replace it with zeros, text, a redirect,\n"
            "or a compressed representation. Publish changed content under a new version.\n"
            "The dispatcher checks a locally pinned size and SHA-256, not a downloaded hash.\n"
            "A successful 1 MiB transfer does not guarantee an entire ISO will download.\n"
        ).encode("ascii"),
    }
    directory.mkdir(parents=True, exist_ok=True)
    for name, content in files.items():
        target = directory / name
        if target.exists() and target.read_bytes() != content:
            raise ValueError("refusing to replace different versioned content: " + str(target))
        target.write_bytes(content)
    return digest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directories", nargs="+", type=Path, help="output directories")
    args = parser.parse_args()
    for directory in args.directories:
        try:
            digest = generate(directory)
        except (OSError, ValueError) as error:
            parser.exit(1, str(error) + "\n")
        print("{}  {}".format(digest, directory / NAME))


if __name__ == "__main__":
    main()
