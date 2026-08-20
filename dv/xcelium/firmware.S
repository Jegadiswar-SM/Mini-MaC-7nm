/*
 * Tiny RV32I firmware for the simulation boot ROM (reset PC = 0x00000080).
 *
 * It writes two source words in system SRAM, programs the copy DMA at
 * 0x40000000, polls DMA_STATUS.done, leaves a signature at 0x10000040, and
 * loops forever.  The testbench owns pass/fail; the loop is intentional.
 */
    .section .text
    .globl _start
    .org 0x80
_start:
    lui   x1, 0x10000          /* system SRAM: 0x10000000 */
    lui   x2, 0x40000          /* DMA APB slave: 0x40000000 */

    li    x3, 0x11223344
    sw    x3, 0(x1)
    li    x3, 0x55667788
    sw    x3, 4(x1)

    addi  x4, x1, 32           /* destination: 0x10000020 */
    sw    x1, 0(x2)            /* DMA_SRC */
    sw    x4, 4(x2)            /* DMA_DST */
    addi  x5, x0, 8
    sw    x5, 8(x2)            /* DMA_LEN, bytes */
    addi  x5, x0, 1
    sw    x5, 12(x2)           /* DMA_CTRL.start */
1:
    lw    x6, 16(x2)           /* DMA_STATUS */
    andi  x6, x6, 2            /* done */
    beq   x6, x0, 1b

    li    x7, 0x600d0001
    sw    x7, 64(x1)           /* firmware completion signature */
2:
    jal   x0, 2b
