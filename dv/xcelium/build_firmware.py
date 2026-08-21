#!/usr/bin/env python3
"""Generate the fixed, dependency-free RV32I boot-ROM image.

The matching readable source is firmware.S.  Keeping this tiny encoder in the
tree makes the normal simulation flow independent of an installed RISC-V SDK.
"""

from pathlib import Path


def u(rd, imm20):
    return (imm20 << 12) | (rd << 7) | 0x37


def i(rd, rs1, imm, funct3=0, opcode=0x13):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def s(rs2, rs1, imm, funct3=2):
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | ((imm & 0x1F) << 7) | 0x23


def b(rs1, rs2, offset, funct3=0):
    assert offset % 2 == 0
    imm = offset & 0x1FFF
    return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | 0x63


def jal(rd, offset):
    imm = offset & 0x1FFFFF
    return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | (((imm >> 11) & 1) << 20) | (((imm >> 12) & 0xFF) << 12) | (rd << 7) | 0x6F


# Exact instruction sequence documented in firmware.S.
program = [
    u(1, 0x10000), u(2, 0x40000),
    u(3, 0x11223), i(3, 3, 0x344), s(3, 1, 0),
    u(3, 0x55667), i(3, 3, 0x788), s(3, 1, 4),
    i(4, 1, 32), s(1, 2, 0), s(4, 2, 4),
    i(5, 0, 8), s(5, 2, 8), i(5, 0, 1), s(5, 2, 12),
    i(6, 2, 16, funct3=2, opcode=0x03), i(6, 6, 2, funct3=7),
    b(6, 0, -8),
    u(7, 0x600D0), i(7, 7, 1), s(7, 1, 64),
    0x0000006F,
]

# MAC vector: 4x4 with non-constant byte weights and row activations.
# The independently modeled systolic schedule produces [5,13,14,12].
program += [u(8, 0x40011), i(9, 1, 0x080), i(10, 1, 0x0C0), i(11, 1, 0x100)]
weights = [1, 2, 3, 4, 2, 1, 2, 1, 1, 3, 1, 2, 2, 2, 1, 1]
program += [instruction for value, ioff in [(value, 0x080 + 4*i) for i, value in enumerate(weights)]
            for instruction in (i(3, 0, value), s(3, 1, ioff))]
activations = [1, 2, 3, 4]
program += [instruction for value, ioff in [(value, 0x0C0 + 4*i) for i, value in enumerate(activations)]
            for instruction in (i(3, 0, value), s(3, 1, ioff))]
program += [s(9, 8, 0x20), s(10, 8, 0x24), s(11, 8, 0x28),
            i(12, 0, 0x404), s(12, 8, 0x08), i(12, 0, 0x040), s(12, 8, 0x2C),
            i(12, 0, 0x010), s(12, 8, 0x30), i(12, 0, 0x00F), s(12, 8, 0x10),
            i(12, 0, 1), s(12, 8, 0x00)]

poll = len(program)
program += [i(6, 8, 0x04, funct3=2, opcode=0x03), i(6, 6, 2, funct3=7), 0]
poll_branch = len(program) - 1
branch_patches = []
for offset, expected in [(0, 5), (4, 13), (8, 14), (12, 12)]:
    program += [i(6, 11, offset, funct3=2, opcode=0x03), i(12, 0, expected), 0]
    branch_patches.append((len(program) - 1, expected))
program += [0]
pass_jump = len(program) - 1
fail_label = len(program)
program += [u(7, 0xBAD00), i(7, 7, 1), s(7, 1, 0x144), 0]
fail_loop = len(program) - 1
pass_label = len(program)
program += [u(7, 0x600D0), i(7, 7, 2), s(7, 1, 0x140), 0]
pass_loop = len(program) - 1

program[poll_branch] = b(6, 0, (poll - poll_branch) * 4)
for index, _ in branch_patches:
    program[index] = b(6, 12, (fail_label - index) * 4, funct3=1)
program[pass_jump] = jal(0, (pass_label - pass_jump) * 4)
program[fail_loop] = jal(0, (fail_label - fail_loop) * 4)
program[pass_loop] = jal(0, (pass_label - pass_loop) * 4)
words = [0] * (0x80 // 4) + program

image = Path(__file__).with_name("firmware.hex")
image.write_text("".join(f"{word:08x}\n" for word in words), encoding="ascii")
