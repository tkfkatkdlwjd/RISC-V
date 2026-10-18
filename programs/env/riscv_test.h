#ifndef RISCV_TEST_MIN_H
#define RISCV_TEST_MIN_H

#define RVTEST_RV32U
#define RVTEST_RV64U
#define TESTNUM gp

#define RVTEST_CODE_BEGIN \
    .section .text;       \
    .globl _start;        \
_start:

#define RVTEST_CODE_END \
9999: j 9999b

/* 전부 통과: gp = 1 */
#define RVTEST_PASS \
    li TESTNUM, 1;  \
    ecall;          \
9998: j 9998b

/* 실패: gp = (케이스번호 << 1) | 1 */
#define RVTEST_FAIL        \
    sll TESTNUM, TESTNUM, 1; \
    or  TESTNUM, TESTNUM, 1; \
    ecall;                 \
9997: j 9997b

#define RVTEST_DATA_BEGIN \
    .section .data;       \
    .align 4;

#define RVTEST_DATA_END

#endif