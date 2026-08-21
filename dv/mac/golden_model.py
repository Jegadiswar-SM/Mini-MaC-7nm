#!/usr/bin/env python3
"""Independent model of the current 4x4 systolic RTL schedule.

PE arithmetic is signed 8x8 -> signed 16, then sign-extended and added to a
32-bit wrapping accumulator.  Each row receives its captured activation byte
on every feed cycle.  The four feed cycles and four drain cycles are modeled
explicitly so the expected output is not a textbook matrix multiply guess.
"""

MASK32 = 0xffffffff


def signed(value, width):
    value &= (1 << width) - 1
    return value - (1 << width) if value & (1 << (width - 1)) else value


def mac_model(weights, activations):
    rows = cols = 4
    a = [[0] * (cols + 1) for _ in range(rows)]
    acc = [[0] * cols for _ in range(rows + 1)]
    w = [[signed(weights[r * cols + c], 8) for c in range(cols)] for r in range(rows)]

    # PE nonblocking assignments: each PE multiplies the previous a_reg and
    # w_reg, forwards the previous a_reg, and accumulates the previous mul_reg.
    a_reg = [[0] * cols for _ in range(rows)]
    w_reg = [row[:] for row in w]
    mul_reg = [[0] * cols for _ in range(rows)]
    acc_reg = [[0] * cols for _ in range(rows + 1)]
    for _cycle in range(4):
        next_a_reg = [[0] * cols for _ in range(rows)]
        next_w_reg = [row[:] for row in w_reg]
        next_mul = [[0] * cols for _ in range(rows)]
        next_acc = [[0] * cols for _ in range(rows + 1)]
        next_acc[0] = [0] * cols
        for r in range(rows):
            for c in range(cols):
                ain = activations[r]
                if c:
                    ain = a_reg[r][c - 1]
                next_a_reg[r][c] = signed(ain, 8)
                product = signed(a_reg[r][c], 8) * signed(w_reg[r][c], 8)
                next_mul[r][c] = product
                next_acc[r + 1][c] = (acc_reg[r][c] + mul_reg[r][c]) & MASK32
        a_reg, w_reg, mul_reg, acc_reg = next_a_reg, next_w_reg, next_mul, next_acc

    # Drain cycles continue the PE pipeline with zero row inputs.
    for _cycle in range(4):
        next_a_reg = [[0] * cols for _ in range(rows)]
        next_mul = [[0] * cols for _ in range(rows)]
        next_acc = [[0] * cols for _ in range(rows + 1)]
        next_acc[0] = [0] * cols
        for r in range(rows):
            for c in range(cols):
                ain = 0 if c == 0 else a_reg[r][c - 1]
                next_a_reg[r][c] = ain
                product = signed(a_reg[r][c], 8) * signed(w_reg[r][c], 8)
                next_mul[r][c] = product
                next_acc[r + 1][c] = (acc_reg[r][c] + mul_reg[r][c]) & MASK32
        a_reg, mul_reg, acc_reg = next_a_reg, next_mul, next_acc
    return [acc_reg[rows][c] for c in range(cols)]


WEIGHTS = [1, 2, 3, 4, 2, 1, 2, 1, 1, 3, 1, 2, 2, 2, 1, 1]
ACTIVATIONS_A = [1, 2, 3, 4]
ACTIVATIONS_B = [4, 3, 2, 1]
WEIGHTS_B = [2 * x for x in WEIGHTS]


def main():
    result_a = mac_model(WEIGHTS, ACTIVATIONS_A)
    result_b = mac_model(WEIGHTS, ACTIVATIONS_B)
    result_w = mac_model(WEIGHTS_B, ACTIVATIONS_A)
    print("weights:", WEIGHTS)
    print("activations A:", ACTIVATIONS_A)
    print("expected A:", [f"0x{x:08x}" for x in result_a])
    print("activations B:", ACTIVATIONS_B)
    print("expected B:", [f"0x{x:08x}" for x in result_b])
    print("expected weight mutation:", [f"0x{x:08x}" for x in result_w])
    assert result_a != result_b, "activation mutation did not affect result"
    assert result_a != result_w, "weight mutation did not affect result"
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
