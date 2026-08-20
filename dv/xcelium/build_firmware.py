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
words = [0] * (0x80 // 4) + program

image = Path(__file__).with_name("firmware.hex")
image.write_text("".join(f"{word:08x}\n" for word in words), encoding="ascii")
