.section .text
.globl _start
_start:
    addi x1, x0, 5
    addi x2, x0, 3
    add  x3, x1, x2
    sub  x4, x1, x2
    slli x5, x1, 20
    or   x6, x5, x3

    addi x7, x0, 128        # 10000000
    li x8, 32768            # 1000000000000000
    li x9, 1000000          # 11110100001001000000
    addi x10, x0, 500

    sw   x7, 0(x10)
    sh   x7, 4(x10)
    sb   x7, 8(x10)
    lw   x11, 0(x10)
    lh   x12, 4(x10)
    lhu  x13, 4(x10)
    lb   x14, 8(x10)
    lbu  x15, 8(x10)

    sw   x8, 12(x10)
    sh   x8, 16(x10)
    sb   x8, 20(x10)
    lw   x16, 12(x10)
    lh   x17, 16(x10)
    lhu  x18, 16(x10)
    lb   x19, 20(x10)
    lbu  x20, 20(x10)

    sw   x9, 24(x10)
    sh   x9, 28(x10)
    sb   x9, 32(x10)
    lw   x21, 24(x10)
    lh   x22, 28(x10)
    lhu  x23, 28(x10)
    lb   x24, 32(x10)
    lbu  x25, 32(x10)

    # 분기 테스트 : 기대값 x26 = 6, x27 = 8, x31 = 0

    # taken
    beq  x1, x1, b1         # 5 == 5
    j    fail
b1: addi x26, x26, 1
    bne  x1, x2, b2         # 5 != 3 
    j    fail
b2: addi x26, x26, 1
    blt  x14, x15, b3       # -128 < 128 
    j    fail
b3: addi x26, x26, 1
    bltu x15, x14, b4       # 128 < 0xffffff80
    j    fail
b4: addi x26, x26, 1
    bge  x15, x14, b5       # 128 >= -128
    j    fail
b5: addi x26, x26, 1
    bgeu x14, x15, b6       # 0xffffff80 >= 128
    j    fail
b6: addi x26, x26, 1

    # not taken
    beq  x1, x2, fail 
    bne  x1, x1, fail   
    blt  x15, x14, fail 
    bltu x14, x15, fail
    bge  x14, x15, fail   
    bgeu x15, x14, fail    

    addi x27, x0, 0
loop:
    addi x27, x27, 1
    blt  x27, x3, loop      # x3 : 4'b1000

    # auipc / 복귀주소 테스트 : 통과할 때마다 x26 += 1 → 최종 기대값 x26 = 10, x31 = 0
    # 기대 주소는 lui + addi (%hi/%lo)로 PC와 무관하게 만들어 비교
a1: auipc x28, 0                    # x28 = a1
    lui  x29, %hi(a1)
    addi x29, x29, %lo(a1)
    bne  x28, x29, fail
    addi x26, x26, 1
a2: auipc x28, 1                    # x28 = a2 + 0x1000
    lui  x29, %hi(a2 + 0x1000)
    addi x29, x29, %lo(a2 + 0x1000)
    bne  x28, x29, fail
    addi x26, x26, 1

    jal  x28, func                  # x28 = r1 (jal 다음 주소)
r1: lui  x29, %hi(r1)
    addi x29, x29, %lo(r1)
    bne  x28, x29, fail
    addi x26, x26, 1
    lui  x29, %hi(f1 + 4)           # x30 = f1 + 4 (jalr 다음 주소)
    addi x29, x29, %lo(f1 + 4)
    bne  x30, x29, fail
    addi x26, x26, 1

done:
    jal  x0, done

fail:
    addi x31, x0, 1     # x31에 1
    j    done

func:
f1: jalr x30, 0(x28)                # x28 로 복귀
