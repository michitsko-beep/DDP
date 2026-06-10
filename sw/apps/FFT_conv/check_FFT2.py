import numpy as np
import re

print("--- Python Checker & Vector Printer Started ---")

INPUT_FILE = "fft_test_in.txt"
OUTPUT_FILE = "fft_test_out.txt"

DEBUG_PRINT = True
DEBUG_COUNT = 16
TOLERANCE = 2


def read_numbers_from_file(filename):
    """
    Supports:
    1. Hex byte format:
       53 09 46 1c a8 ff ...

    2. Decimal format:
       83 9 70 28 -88 ...

    Lines starting with # are ignored.
    """
    with open(filename, "r") as f:
        text = f.read()

    values = []

    for line in text.splitlines():
        line = line.strip()

        if not line:
            continue

        if line.startswith("#"):
            continue

        parts = line.split()

        for p in parts:
            p = p.strip().replace(",", "")

            # Hex byte, for example: 53, 09, a8, ff
            if re.fullmatch(r"[0-9a-fA-F]{2}", p):
                values.append(int(p, 16))

            # Decimal signed/unsigned
            elif re.fullmatch(r"-?\d+", p):
                values.append(int(p, 10))

    return values


def to_int8(v):
    v = int(v) & 0xFF

    if v >= 128:
        return v - 256

    return v


def q15_mul(a, b):
    t = np.int64(a) * np.int64(b)
    t += np.int64(1 << 14)
    return np.int32(t >> 15)


def complex_mul(a, b):
    ar = np.int32(a[0])
    ai = np.int32(a[1])
    br = np.int32(b[0])
    bi = np.int32(b[1])

    re = np.int32(q15_mul(ar, br) - q15_mul(ai, bi))
    im = np.int32(q15_mul(ar, bi) + q15_mul(ai, br))

    return np.array([re, im], dtype=np.int32)


def bit_reverse(i, bits):
    r = 0

    for _ in range(bits):
        r = (r << 1) | (i & 1)
        i >>= 1

    return r


def fft_fixed_scaled(inp, inverse=False):
    A = np.array(inp, dtype=np.int32).copy()
    N = A.shape[0]

    if N <= 0 or (N & (N - 1)) != 0:
        raise RuntimeError(f"FFT length must be power of two, got N={N}")

    bits = int(np.log2(N))

    # Bit reversal
    B = np.zeros_like(A, dtype=np.int32)

    for i in range(N):
        B[bit_reverse(i, bits)] = A[i]

    A = B

    length = 2

    while length <= N:
        half = length // 2

        for block_start in range(0, N, length):
            for j in range(half):
                angle = -2.0 * np.pi * j / length

                if inverse:
                    angle = -angle

                # Same as Python reference:
                # int() truncates toward zero.
                w_re = np.int32(int(np.cos(angle) * 32768))
                w_im = np.int32(int(np.sin(angle) * 32768))

                w = np.array([w_re, w_im], dtype=np.int32)

                u = A[block_start + j].copy()
                v = complex_mul(A[block_start + j + half], w)

                add_re = np.int32(u[0] + v[0])
                add_im = np.int32(u[1] + v[1])
                sub_re = np.int32(u[0] - v[0])
                sub_im = np.int32(u[1] - v[1])

                # Scaled FFT: divide by 2 every butterfly stage
                A[block_start + j, 0] = np.int32(add_re >> 1)
                A[block_start + j, 1] = np.int32(add_im >> 1)

                A[block_start + j + half, 0] = np.int32(sub_re >> 1)
                A[block_start + j + half, 1] = np.int32(sub_im >> 1)

        length *= 2

    return A.astype(np.int32)


# ============================================================
# Read files
# ============================================================

in_nums = read_numbers_from_file(INPUT_FILE)
hw_nums = read_numbers_from_file(OUTPUT_FILE)

if len(in_nums) == 0:
    raise RuntimeError(f"No numbers found in {INPUT_FILE}")

if len(hw_nums) == 0:
    raise RuntimeError(f"No numbers found in {OUTPUT_FILE}")

if len(in_nums) % 2 != 0:
    raise RuntimeError(
        f"{INPUT_FILE} has odd number of values: {len(in_nums)}. "
        "Expected C followed by X."
    )

# fft_test_in.txt contains:
# C[0..N-1] followed by X[0..N-1]
N = len(in_nums) // 2

if N <= 0 or (N & (N - 1)) != 0:
    raise RuntimeError(f"N must be power of two, got N={N}")

if len(hw_nums) < N:
    raise RuntimeError(
        f"{OUTPUT_FILE} has only {len(hw_nums)} numbers, "
        f"but expected at least {N}. "
        "Check that the accelerator dumped N bytes."
    )

c = np.array([to_int8(v) for v in in_nums[:N]], dtype=np.int32)
x = np.array([to_int8(v) for v in in_nums[N:2 * N]], dtype=np.int32)
hw = np.array([to_int8(v) for v in hw_nums[:N]], dtype=np.int32)

print(f"N detected from input file: {N}")
print(f"Input numbers: {len(in_nums)}")
print(f"Output numbers: {len(hw_nums)}")
print()

# ============================================================
# Extra debug: compare what Python thinks C/X are
# ============================================================

print("===== PY LOADED VECTOR CHECK =====")
print("SUM_C =", int(np.sum(c)))
print("SUM_X =", int(np.sum(x)))

print("----- C/X FIRST 16 -----")
for i in range(min(16, N)):
    print(f"PY_BUF[{i}] c={int(c[i])} x={int(x[i])}")

print("----- C/X AROUND 64 -----")
for i in range(64, min(72, N)):
    print(f"PY_BUF[{i}] c={int(c[i])} x={int(x[i])}")

print("----- C/X AROUND 128 -----")
for i in range(128, min(136, N)):
    print(f"PY_BUF[{i}] c={int(c[i])} x={int(x[i])}")

print("----- C/X AROUND 192 -----")
for i in range(192, min(200, N)):
    print(f"PY_BUF[{i}] c={int(c[i])} x={int(x[i])}")

print("----- C/X LAST 8 -----")
for i in range(max(0, N - 8), N):
    print(f"PY_BUF[{i}] c={int(c[i])} x={int(x[i])}")

print()

# ============================================================
# Prepare complex inputs exactly like HW
# A[:,0] = c << 12
# B[:,0] = x << 12
# imag = 0
# ============================================================

A = np.zeros((N, 2), dtype=np.int32)
B = np.zeros((N, 2), dtype=np.int32)

A[:, 0] = np.int32(c << 12)
A[:, 1] = np.int32(0)

B[:, 0] = np.int32(x << 12)
B[:, 1] = np.int32(0)

# ============================================================
# FFT(C), FFT(X)
# ============================================================

A_f = fft_fixed_scaled(A, inverse=False)
B_f = fft_fixed_scaled(B, inverse=False)

if DEBUG_PRINT:
    print("===== PY INPUT FIRST 16 =====")
    for i in range(min(DEBUG_COUNT, N)):
        print(f"IN[{i}] c={int(c[i])} x={int(x[i])}")

    print("===== PY FFT_C FIRST 16 =====")
    for i in range(min(DEBUG_COUNT, N)):
        print(f"CFFT[{i}] = {int(A_f[i, 0])} , {int(A_f[i, 1])}")

    print("===== PY FFT_X FIRST 16 =====")
    for i in range(min(DEBUG_COUNT, N)):
        print(f"XFFT[{i}] = {int(B_f[i, 0])} , {int(B_f[i, 1])}")

# ============================================================
# Pointwise complex multiplication
# ============================================================

Out = np.zeros((N, 2), dtype=np.int32)

for i in range(N):
    Out[i] = complex_mul(A_f[i], B_f[i])

if DEBUG_PRINT:
    print("===== PY MUL FIRST 16 =====")
    for i in range(min(DEBUG_COUNT, N)):
        print(f"MUL[{i}] = {int(Out[i, 0])} , {int(Out[i, 1])}")

# ============================================================
# IFFT
# ============================================================

Y_complex = fft_fixed_scaled(Out, inverse=True)

if DEBUG_PRINT:
    print("===== PY IFFT FIRST 16 =====")
    for i in range(min(DEBUG_COUNT, N)):
        print(f"IFFT[{i}] = {int(Y_complex[i, 0])} , {int(Y_complex[i, 1])}")

# ============================================================
# Normalize:
# y_ref = ((y_raw * 127) // maxv).astype(int8)
# Python // is floor division.
# ============================================================

y_raw = Y_complex[:, 0].astype(np.int64)

maxv = int(np.max(np.abs(y_raw)))

if maxv == 0:
    maxv = 1

y_ref_i64 = (y_raw * 127) // maxv
y_ref = np.array([to_int8(v) for v in y_ref_i64], dtype=np.int32)

if DEBUG_PRINT:
    print("===== PY NORMALIZE FIRST 16 =====")
    print(f"maxv = {maxv}")

    for i in range(min(DEBUG_COUNT, N)):
        print(
            f"NORM[{i}] raw={int(y_raw[i])} "
            f"ref={int(y_ref[i])}"
        )

# ============================================================
# Compare
# ============================================================

diff = y_ref - hw
abs_diff = np.abs(diff)

max_error = int(np.max(abs_diff))
mismatches = int(np.sum(abs_diff > TOLERANCE))

print()
print("HW  (First 10):", [int(v) for v in hw[:10]])
print("REF (First 10):", [int(v) for v in y_ref[:10]])
print()
print("Max Error:", max_error)
print(f"Mismatches (>{TOLERANCE}): {mismatches} / {N}")
print()
print("Index | HW | REF | DIFF")

for i in range(min(32, N)):
    print(f"{i:5d} | {int(hw[i]):4d} | {int(y_ref[i]):4d} | {int(diff[i]):5d}")

print()

if mismatches == 0:
    print("SUCCESS: MATCH")
else:
    print("STILL DIFFS")