/*
 * Tiny RV32I firmware for the simulation boot ROM (reset PC = 0x00000080).
 *
 * It writes two source words in system SRAM, programs the copy DMA at
 * 0x40000000, polls DMA_STATUS.done, leaves a signature at 0x10000040, and
 * then runs the real MAC register/DMA path. The generated image writes a
 * 4x4 non-constant weight vector at 0x10000080, activations [1,2,3,4] at
 * 0x100000c0, programs MAC at 0x40011000, and checks result [5,13,14,12]
 * at 0x10000100 before writing the pass signature at 0x10000140.
 * build_firmware.py is the dependency-free instruction encoder for this image.
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

    lui   x8, 0x40011           /* MAC APB: 0x40011000 */
    addi  x9, x1, 0x080         /* weight source */
    addi  x10, x1, 0x0c0        /* activation source */
    addi  x11, x1, 0x100        /* result destination */
    /* build_firmware.py emits the following vector stores: */
    /* weights = [1,2,3,4,2,1,2,1,1,3,1,2,2,2,1,1] */
    /* activations = [1,2,3,4], result = [5,13,14,12] */
    /* The generated image writes each value to x9/x10, then programs:
       DIM=0x00040404, DMA_LEN_WGT=64, DMA_LEN_ACT=16, CORE_EN=0xf,
       WGT_BASE=x9, ACT_BASE=x10, RES_BASE=x11, CTRL.start=1. */
3:
    lw    x6, 4(x8)             /* MAC STATUS */
    andi  x6, x6, 2             /* sticky done */
    beq   x6, x0, 3b
    lw    x6, 0(x11)
    li    x12, 5
    bne   x6, x12, 4f
    lw    x6, 4(x11)
    li    x12, 13
    bne   x6, x12, 4f
    lw    x6, 8(x11)
    li    x12, 14
    bne   x6, x12, 4f
    lw    x6, 12(x11)
    li    x12, 12
    bne   x6, x12, 4f
    li    x7, 0x600d0002
    sw    x7, 0x140(x1)
5:
    jal   x0, 5b
4:
    li    x7, 0xbad00001
    sw    x7, 0x144(x1)
6:
    jal   x0, 6b
