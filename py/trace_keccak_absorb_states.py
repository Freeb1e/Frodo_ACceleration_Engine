#!/usr/bin/env python3
"""
Trace Keccak-1600 state after each SHAKE256 absorb block for:
    ss = SHAKE256(Pack(B') || Pack(C) || salt || k)

Pack rule for B/C:
    Swap high/low byte in every 16-bit element.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path


def rol64(x: int, n: int) -> int:
    n %= 64
    return ((x << n) & 0xFFFFFFFFFFFFFFFF) | (x >> (64 - n))


def keccak_f1600(state: bytes) -> bytes:
    rc = [
        0x0000000000000001,
        0x0000000000008082,
        0x800000000000808A,
        0x8000000080008000,
        0x000000000000808B,
        0x0000000080000001,
        0x8000000080008081,
        0x8000000000008009,
        0x000000000000008A,
        0x0000000000000088,
        0x0000000080008009,
        0x000000008000000A,
        0x000000008000808B,
        0x800000000000008B,
        0x8000000000008089,
        0x8000000000008003,
        0x8000000000008002,
        0x8000000000000080,
        0x000000000000800A,
        0x800000008000000A,
        0x8000000080008081,
        0x8000000000008080,
        0x0000000080000001,
        0x8000000080008008,
    ]

    a = [[0] * 5 for _ in range(5)]
    for x in range(5):
        for y in range(5):
            idx = (x + 5 * y) * 8
            a[x][y] = int.from_bytes(state[idx : idx + 8], "little")

    for rnd in range(24):
        c = [a[x][0] ^ a[x][1] ^ a[x][2] ^ a[x][3] ^ a[x][4] for x in range(5)]
        d = [c[(x - 1) % 5] ^ rol64(c[(x + 1) % 5], 1) for x in range(5)]
        for x in range(5):
            for y in range(5):
                a[x][y] ^= d[x]

        b = [[0] * 5 for _ in range(5)]
        x, y = 1, 0
        for t in range(24):
            b[y][(2 * x + 3 * y) % 5] = rol64(a[x][y], ((t + 1) * (t + 2) // 2) % 64)
            x, y = y, (2 * x + 3 * y) % 5
        b[0][0] = a[0][0]

        for y in range(5):
            row = [b[x][y] for x in range(5)]
            for x in range(5):
                a[x][y] = row[x] ^ ((~row[(x + 1) % 5]) & row[(x + 2) % 5])

        a[0][0] ^= rc[rnd]

    out = bytearray(200)
    for x in range(5):
        for y in range(5):
            idx = (x + 5 * y) * 8
            out[idx : idx + 8] = a[x][y].to_bytes(8, "little")
    return bytes(out)


def swap_bytes_in_u16_stream(data: bytes) -> bytes:
    if len(data) % 2 != 0:
        raise ValueError("u16 stream length must be even for pack operation")
    out = bytearray(len(data))
    for i in range(0, len(data), 2):
        out[i] = data[i + 1]
        out[i + 1] = data[i]
    return bytes(out)


def shake256_pad(msg: bytes, rate: int = 136) -> bytes:
    m = bytearray(msg)
    m.append(0x1F)
    while len(m) % rate != rate - 1:
        m.append(0x00)
    m.append(0x80)
    return bytes(m)


def state_words_le64_hex(state: bytes) -> list[str]:
    return [f"{int.from_bytes(state[i:i+8], 'little'):016X}" for i in range(0, 200, 8)]


def bytes_words_64_hex(data: bytes) -> list[str]:
    if len(data) % 8 != 0:
        raise ValueError("data length must be multiple of 8 bytes for 64-bit split")
    return [data[i : i + 8].hex().upper() for i in range(0, len(data), 8)]


def trace_absorb_states(msg: bytes, rate: int = 136) -> list[tuple[int, bytes, bytes, bytes]]:
    padded = shake256_pad(msg, rate=rate)
    state = bytes(200)
    traces: list[tuple[int, bytes, bytes, bytes]] = []
    for block_idx in range(len(padded) // rate):
        block = padded[block_idx * rate : (block_idx + 1) * rate]
        st = bytearray(state)
        for i in range(rate):
            st[i] ^= block[i]
        pre_perm = bytes(st)
        state = keccak_f1600(pre_perm)
        post_perm = state
        traces.append((block_idx + 1, block, pre_perm, post_perm))
    return traces


def parse_args() -> argparse.Namespace:
    script_dir = Path(__file__).resolve().parent
    encapref_dir = script_dir / "encapref"

    parser = argparse.ArgumentParser(
        description="Trace Keccak-1600 state after each absorb block for Frodo encap ss path."
    )
    parser.add_argument(
        "--b-file",
        default=str(encapref_dir / "ref_encap_matrix_Bprime.bin"),
        help="Path to B data (default: Bprime).",
    )
    parser.add_argument(
        "--c-file",
        default=str(encapref_dir / "ref_encap_matrix_C.bin"),
        help="Path to C data.",
    )
    parser.add_argument(
        "--salt-file",
        default=str(encapref_dir / "ref_encap_salt.bin"),
        help="Path to salt data (64 bytes).",
    )
    parser.add_argument(
        "--k-file",
        default=None,
        help="Path to k data (32 bytes). If omitted, derive k from SHAKE256(pkh||mu||salt).",
    )
    parser.add_argument(
        "--pkh-file",
        default=str(encapref_dir / "ref_encap_pkh.bin"),
        help="Path to pkh data, used only when --k-file is omitted.",
    )
    parser.add_argument(
        "--mu-file",
        default=str(encapref_dir / "ref_encap_mu.bin"),
        help="Path to mu data, used only when --k-file is omitted.",
    )
    parser.add_argument(
        "--ref-ss-file",
        default=str(encapref_dir / "ref_encap_ss.bin"),
        help="Reference ss file for final check.",
    )
    parser.add_argument(
        "--no-pack-b",
        action="store_true",
        help="Disable B pack (u16 byte-swap).",
    )
    parser.add_argument(
        "--no-pack-c",
        action="store_true",
        help="Disable C pack (u16 byte-swap).",
    )
    parser.add_argument(
        "--out",
        default=str(encapref_dir / "keccak_absorb_states.txt"),
        help="Output text file for state trace.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    b = Path(args.b_file).read_bytes()
    c = Path(args.c_file).read_bytes()
    salt = Path(args.salt_file).read_bytes()

    if args.k_file:
        k = Path(args.k_file).read_bytes()
        k_source = f"file:{args.k_file}"
    else:
        pkh = Path(args.pkh_file).read_bytes()
        mu = Path(args.mu_file).read_bytes()
        k = hashlib.shake_256(pkh + mu + salt).digest(96)[64:96]
        k_source = "derived: SHAKE256(pkh||mu||salt)[64:96]"

    if not args.no_pack_b:
        b = swap_bytes_in_u16_stream(b)
    if not args.no_pack_c:
        c = swap_bytes_in_u16_stream(c)

    msg = b + c + salt + k
    traces = trace_absorb_states(msg, rate=136)
    final_state = traces[-1][3]
    ss_from_state = final_state[:32]
    ss_hashlib = hashlib.shake_256(msg).digest(32)

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    with out_path.open("w", encoding="utf-8") as f:
        f.write("# Keccak-1600 absorb trace for ss path\n")
        f.write(f"# message_len={len(msg)} bytes, blocks={len(traces)}, rate=136\n")
        f.write(f"# B_len={len(b)} C_len={len(c)} salt_len={len(salt)} k_len={len(k)}\n")
        f.write(f"# k_source={k_source}\n")
        f.write(
            f"# pack_b={'off' if args.no_pack_b else 'on'} "
            f"pack_c={'off' if args.no_pack_c else 'on'}\n\n"
        )

        for block_idx, block, pre_perm, post_perm in traces:
            words = state_words_le64_hex(post_perm)
            block_words = bytes_words_64_hex(block)
            f.write(f"[BLOCK {block_idx:03d}]\n")
            f.write(f"block_data={block.hex().upper()}\n")
            f.write("block_data_words_64=\n")
            for i in range(0, len(block_words), 5):
                f.write(" ".join(block_words[i : i + 5]) + "\n")
            f.write(f"state_pre_perm={pre_perm.hex().upper()}\n")
            f.write(f"state_post_perm={post_perm.hex().upper()}\n")
            f.write("state_post_perm_words_le64=\n")
            for i in range(0, 25, 5):
                f.write(" ".join(words[i : i + 5]) + "\n")
            f.write("\n")

        f.write(f"final_ss_from_state={ss_from_state.hex().upper()}\n")
        f.write(f"final_ss_hashlib   ={ss_hashlib.hex().upper()}\n")

        ref_path = Path(args.ref_ss_file)
        if ref_path.exists():
            ref_ss = ref_path.read_bytes()
            f.write(f"ref_ss            ={ref_ss.hex().upper()}\n")
            f.write(f"match_ref_ss      ={str(ss_from_state == ref_ss).lower()}\n")

    print(f"Trace written to: {out_path}")
    print(f"Blocks traced: {len(traces)}")
    print(f"k source: {k_source}")
    print(f"final ss: {ss_from_state.hex()}")

    ref_path = Path(args.ref_ss_file)
    if ref_path.exists():
        ref_ss = ref_path.read_bytes()
        print(f"ref ss : {ref_ss.hex()}")
        print(f"match  : {ss_from_state == ref_ss}")


if __name__ == "__main__":
    main()
