#!/usr/bin/env python3
"""Trace accumulation steps for B' * S inner products.

This script is for debugging the systolic BS path. It loads B' and S matrices,
then prints/writes per-element inner-product accumulation details.

Default dimensions match FrodoKEM-1344 decap BS step:
- B' shape: 8 x 1344
- S  shape: 1344 x 8
- Output : 8 x 8

Default input files in this repo:
- B' : py/encapref/ref_encap_matrix_Bprime.bin (u16)
- S  : py/ref_matrix_ST_8bit.bin (i8, column-major)

Examples:
    python3 py/bprime_s_accum_trace.py --positions 0,0 3,4

    python3 py/bprime_s_accum_trace.py \
            --mode signed \
            --trace-out output/BprimeS_trace_signed.txt
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import List, Sequence, Tuple


def parse_token(token: str) -> int:
    t = token.strip()
    if not t:
        raise ValueError("empty token")
    if t.lower().startswith("0x"):
        return int(t, 16)
    if any(c in "abcdefABCDEF" for c in t):
        return int(t, 16)
    return int(t, 10)


def twos_to_signed(value: int, bits: int) -> int:
    mask = (1 << bits) - 1
    v = value & mask
    sign = 1 << (bits - 1)
    return v - (1 << bits) if (v & sign) else v


def load_matrix_txt(path: Path) -> List[List[int]]:
    rows: List[List[int]] = []
    with path.open("r", encoding="utf-8") as f:
        for line_no, line in enumerate(f, 1):
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            s = s.replace(",", " ")
            tokens = [x for x in s.split() if x]
            try:
                row = [parse_token(tok) for tok in tokens]
            except ValueError as exc:
                raise ValueError(f"{path}:{line_no} parse error: {exc}") from exc
            rows.append(row)

    if not rows:
        raise ValueError(f"{path}: no matrix data found")

    width = len(rows[0])
    for idx, row in enumerate(rows):
        if len(row) != width:
            raise ValueError(
                f"{path}: row {idx} has width {len(row)}, expected {width}"
            )
    return rows


def dtype_size(dtype_name: str) -> int:
    if dtype_name in ("i8", "u8"):
        return 1
    if dtype_name in ("i16", "u16"):
        return 2
    raise ValueError(f"unsupported dtype: {dtype_name}")


def decode_scalar(raw: bytes, dtype_name: str) -> int:
    if dtype_name == "u8":
        return raw[0]
    if dtype_name == "i8":
        return twos_to_signed(raw[0], 8)
    if dtype_name == "u16":
        return int.from_bytes(raw, byteorder="little", signed=False)
    if dtype_name == "i16":
        return int.from_bytes(raw, byteorder="little", signed=True)
    raise ValueError(f"unsupported dtype: {dtype_name}")


def load_matrix_bin(path: Path, rows: int, cols: int, dtype_name: str, layout: str) -> List[List[int]]:
    raw = path.read_bytes()
    item_size = dtype_size(dtype_name)
    expected = rows * cols * item_size
    if len(raw) != expected:
        raise ValueError(
            f"{path}: size mismatch, got {len(raw)} bytes, expected {expected} bytes"
        )

    vals: List[int] = []
    for i in range(0, len(raw), item_size):
        vals.append(decode_scalar(raw[i:i + item_size], dtype_name))

    mat = [[0 for _ in range(cols)] for _ in range(rows)]
    idx = 0
    if layout == "row":
        for r in range(rows):
            for c in range(cols):
                mat[r][c] = vals[idx]
                idx += 1
    elif layout == "col":
        for c in range(cols):
            for r in range(rows):
                mat[r][c] = vals[idx]
                idx += 1
    else:
        raise ValueError(f"unsupported layout: {layout}")

    return mat


def load_matrix(
    path: Path,
    rows: int,
    cols: int,
    file_format: str,
    dtype_name: str,
    layout: str,
) -> List[List[int]]:
    fmt = file_format
    if fmt == "auto":
        fmt = "bin" if path.suffix.lower() == ".bin" else "txt"

    if fmt == "txt":
        mat = load_matrix_txt(path)
        validate_shape(mat, str(path), (rows, cols))
        return mat

    if fmt == "bin":
        return load_matrix_bin(path, rows, cols, dtype_name, layout)

    raise ValueError(f"unsupported format: {file_format}")


def validate_shape(mat: Sequence[Sequence[int]], name: str, shape: Tuple[int, int]) -> None:
    r, c = shape
    if len(mat) != r:
        raise ValueError(f"{name} row count mismatch: got {len(mat)}, expected {r}")
    if any(len(row) != c for row in mat):
        raise ValueError(f"{name} column count mismatch: expected {c}")


def decode_matrix(
    mat: Sequence[Sequence[int]],
    signed_bits: int | None,
    mask_bits: int | None,
) -> List[List[int]]:
    out: List[List[int]] = []
    for row in mat:
        new_row: List[int] = []
        for v in row:
            x = v
            if mask_bits is not None:
                x &= (1 << mask_bits) - 1
            if signed_bits is not None:
                x = twos_to_signed(x, signed_bits)
            new_row.append(x)
        out.append(new_row)
    return out


def parse_positions(items: Sequence[str], rows: int, cols: int) -> List[Tuple[int, int]]:
    if not items:
        return [(i, j) for i in range(rows) for j in range(cols)]

    pos: List[Tuple[int, int]] = []
    for item in items:
        parts = item.split(",")
        if len(parts) != 2:
            raise ValueError(f"invalid position '{item}', expected row,col")
        i = int(parts[0].strip())
        j = int(parts[1].strip())
        if not (0 <= i < rows and 0 <= j < cols):
            raise ValueError(f"position out of range: ({i},{j}) for {rows}x{cols}")
        pos.append((i, j))
    return pos


def trace_dot(
    b_row: Sequence[int],
    s_col: Sequence[int],
    mode: str,
) -> Tuple[int, List[str]]:
    if len(b_row) != len(s_col):
        raise ValueError("dot dimension mismatch")

    lines: List[str] = []

    if mode == "hw16":
        acc = 0
        for k, (b, s) in enumerate(zip(b_row, s_col)):
            b16 = b & 0xFFFF
            s16 = s & 0xFFFF
            prod = (b16 * s16) & 0xFFFFFFFF
            nxt = (acc + prod) & 0xFFFF
            lines.append(
                f"k={k:4d}  b=0x{b16:04X}  s=0x{s16:04X}  prod=0x{prod:08X}  acc: 0x{acc:04X} -> 0x{nxt:04X}"
            )
            acc = nxt
        return acc, lines

    if mode == "signed":
        acc = 0
        for k, (b, s) in enumerate(zip(b_row, s_col)):
            prod = b * s
            nxt = acc + prod
            lines.append(
                f"k={k:4d}  b={b:7d}  s={s:7d}  prod={prod:11d}  acc: {acc:11d} -> {nxt:11d}"
            )
            acc = nxt
        return acc, lines

    raise ValueError(f"unsupported mode: {mode}")


def transpose(mat: Sequence[Sequence[int]]) -> List[List[int]]:
    if not mat:
        return []
    return [list(col) for col in zip(*mat)]


def main() -> None:
    parser = argparse.ArgumentParser(description="Trace B' * S accumulation step by step")
    parser.add_argument(
        "--bprime",
        type=Path,
        default=Path("py/encapref/ref_encap_matrix_Bprime.bin"),
        help="B' matrix path",
    )
    parser.add_argument(
        "--s",
        type=Path,
        default=Path("py/ref_matrix_ST_8bit.bin"),
        help="S matrix path",
    )

    parser.add_argument("--b-rows", type=int, default=8)
    parser.add_argument("--b-cols", type=int, default=1344)
    parser.add_argument("--s-rows", type=int, default=1344)
    parser.add_argument("--s-cols", type=int, default=8)

    parser.add_argument("--b-format", choices=["auto", "txt", "bin"], default="auto")
    parser.add_argument("--s-format", choices=["auto", "txt", "bin"], default="auto")
    parser.add_argument("--b-dtype", choices=["u8", "i8", "u16", "i16"], default="u16")
    parser.add_argument("--s-dtype", choices=["u8", "i8", "u16", "i16"], default="i8")
    parser.add_argument(
        "--b-layout",
        choices=["row", "col"],
        default="row",
        help="B' storage order in file",
    )
    parser.add_argument(
        "--s-layout",
        choices=["row", "col"],
        default="col",
        help="S storage order in file; for ref_matrix_ST_8bit use col",
    )

    parser.add_argument(
        "--mode",
        choices=["hw16", "signed"],
        default="hw16",
        help="hw16: emulate current RTL unsigned 16-bit wrap; signed: arithmetic integer accumulation",
    )

    parser.add_argument(
        "--b-signed-bits",
        type=int,
        default=None,
        help="decode B' tokens as signed two's complement with given bit-width",
    )
    parser.add_argument(
        "--s-signed-bits",
        type=int,
        default=8,
        help="decode S tokens as signed two's complement with given bit-width (default 8)",
    )
    parser.add_argument(
        "--b-mask-bits",
        type=int,
        default=16,
        help="mask B' tokens to this bit-width before decode (default 16)",
    )
    parser.add_argument(
        "--s-mask-bits",
        type=int,
        default=16,
        help="mask S tokens to this bit-width before decode (default 16)",
    )

    parser.add_argument(
        "--positions",
        nargs="*",
        default=[],
        help="positions to trace, e.g. --positions 0,0 3,4 ; omit to trace all",
    )
    parser.add_argument(
        "--trace-out",
        type=Path,
        default=Path("output/BprimeS_trace.txt"),
        help="output trace file path",
    )
    parser.add_argument(
        "--result-out",
        type=Path,
        default=Path("output/BprimeS_result.txt"),
        help="output result matrix path",
    )

    args = parser.parse_args()

    b_raw = load_matrix(
        path=args.bprime,
        rows=args.b_rows,
        cols=args.b_cols,
        file_format=args.b_format,
        dtype_name=args.b_dtype,
        layout=args.b_layout,
    )
    s_raw = load_matrix(
        path=args.s,
        rows=args.s_rows,
        cols=args.s_cols,
        file_format=args.s_format,
        dtype_name=args.s_dtype,
        layout=args.s_layout,
    )

    if args.b_cols != args.s_rows:
        raise ValueError(f"inner dimension mismatch: {args.b_cols} vs {args.s_rows}")

    b = decode_matrix(b_raw, args.b_signed_bits, args.b_mask_bits)
    s = decode_matrix(s_raw, args.s_signed_bits, args.s_mask_bits)
    s_t = transpose(s)

    positions = parse_positions(args.positions, args.b_rows, args.s_cols)

    result = [[0 for _ in range(args.s_cols)] for _ in range(args.b_rows)]
    trace_lines: List[str] = []

    for i in range(args.b_rows):
        for j in range(args.s_cols):
            val, _ = trace_dot(b[i], s_t[j], args.mode)
            result[i][j] = val

    for i, j in positions:
        val, lines = trace_dot(b[i], s_t[j], args.mode)
        trace_lines.append(f"=== Position ({i},{j}) ===")
        trace_lines.extend(lines)
        trace_lines.append(f"Result ({i},{j}) = {val}")
        trace_lines.append("")

    args.trace_out.parent.mkdir(parents=True, exist_ok=True)
    args.result_out.parent.mkdir(parents=True, exist_ok=True)

    with args.trace_out.open("w", encoding="utf-8") as f:
        f.write("\n".join(trace_lines))

    with args.result_out.open("w", encoding="utf-8") as f:
        for row in result:
            f.write(" ".join(str(x) for x in row) + "\n")

    print("Done.")
    print(f"mode={args.mode}, traced_positions={len(positions)}")
    print(f"trace:  {args.trace_out}")
    print(f"result: {args.result_out}")


if __name__ == "__main__":
    main()
