#!/usr/bin/env python3
"""Minimal MPQ (format v1) writer: stores files uncompressed, unencrypted (flags = EXISTS).
Enough for WoW 3.3.5a patch archives (Interface overrides etc.). Read back with mpyq to verify.

usage: mpq_writer.py out.MPQ <srcdir>      (every file under srcdir is added with its relative path, '\\' separators)
"""
import os, struct, sys

# ---- MPQ crypto table + hashing (Ladik/StormLib algorithm) ----
_crypt = [0] * 0x500
def _init():
    seed = 0x00100001
    for i in range(0x100):
        idx = i
        for _ in range(5):
            seed = (seed * 125 + 3) % 0x2AAAAB; t1 = (seed & 0xFFFF) << 0x10
            seed = (seed * 125 + 3) % 0x2AAAAB; t2 = (seed & 0xFFFF)
            _crypt[idx] = t1 | t2; idx += 0x100
_init()

def mpq_hash(s: str, htype: int) -> int:
    seed1, seed2 = 0x7FED7FED, 0xEEEEEEEE
    for ch in s.upper().replace("/", "\\").encode("latin1"):
        seed1 = (_crypt[(htype << 8) + ch] ^ (seed1 + seed2)) & 0xFFFFFFFF
        seed2 = (ch + seed1 + seed2 + (seed2 << 5) + 3) & 0xFFFFFFFF
    return seed1

def encrypt(data: bytes, key: int) -> bytes:
    seed = 0xEEEEEEEE; out = bytearray(); n = len(data) // 4
    for i in range(n):
        v = struct.unpack_from("<I", data, i * 4)[0]
        seed = (seed + _crypt[0x400 + (key & 0xFF)]) & 0xFFFFFFFF
        c = v ^ ((key + seed) & 0xFFFFFFFF)
        out += struct.pack("<I", c & 0xFFFFFFFF)
        key = (((~key << 0x15) + 0x11111111) | (key >> 0x0B)) & 0xFFFFFFFF
        seed = (v + seed + (seed << 5) + 3) & 0xFFFFFFFF
    return bytes(out)

def write_mpq(out_path: str, files: dict):
    """files: {archive_path_with_backslashes: bytes}"""
    names = list(files.keys()) + ["(listfile)"]
    files = dict(files); files["(listfile)"] = ("\r\n".join(files.keys()) + "\r\n").encode("latin1", "replace")
    hsize = 1
    while hsize < len(names) * 2: hsize <<= 1
    header_size = 32
    data = bytearray(); block = []
    for i, name in enumerate(names):
        content = files[name]
        block.append((header_size + len(data), len(content), len(content), 0x80000000 | 0x01000000))  # EXISTS | SINGLE_UNIT, uncompressed
        data += content
        while len(data) % 4: data += b"\0"
    hash_off = header_size + len(data)
    block_off = hash_off + hsize * 16
    # hash table
    table = [(0xFFFFFFFF, 0xFFFFFFFF, 0xFFFF, 0xFFFF, 0xFFFFFFFF)] * hsize
    for i, name in enumerate(names):
        start = mpq_hash(name, 0) & (hsize - 1); a = mpq_hash(name, 1); b = mpq_hash(name, 2)
        j = start
        while table[j][4] != 0xFFFFFFFF:
            j = (j + 1) & (hsize - 1)
            if j == start: raise RuntimeError("hash table full")
        table[j] = (a, b, 0, 0, i)
    hraw = b"".join(struct.pack("<IIHHI", *e) for e in table)
    braw = b"".join(struct.pack("<IIII", *e) for e in block)
    henc = encrypt(hraw, mpq_hash("(hash table)", 3)); benc = encrypt(braw, mpq_hash("(block table)", 3))
    archive_size = block_off + len(braw)
    header = struct.pack("<4sIIHHIIII", b"MPQ\x1a", header_size, archive_size, 0, 3, hash_off, block_off, hsize, len(block))
    with open(out_path, "wb") as w:
        w.write(header); w.write(data); w.write(henc); w.write(benc)
    return len(names) - 1, archive_size

if __name__ == "__main__":
    out, src = sys.argv[1], sys.argv[2]
    files = {}
    for root, _, fns in os.walk(src):
        for fn in fns:
            p = os.path.join(root, fn); rel = os.path.relpath(p, src).replace("/", "\\")
            files[rel] = open(p, "rb").read()
    n, size = write_mpq(out, files)
    print("wrote", out, n, "files,", size, "bytes")
