module csr_file (
  input  logic clk, rst,
  // CSR 명령 (WB에서 쓰기, EX에서 읽기)
  input  logic [11:0] raddr,
  output logic [31:0] rdata,
  input  logic        we,          // WB에서 commit된 CSR 쓰기
  input  logic [11:0] waddr,
  input  logic [31:0] wdata,       // csr_new
  // trap / mret (WB에서 commit)
  input  logic        trap_valid,
  input  logic [31:0] mepc_in,//trap 명령어의 pc
  input  logic [31:0] mcause_in,//원인
  input  logic [31:0] mtval_in,
  input  logic        mret_valid,
  // 출력
  output logic [31:0] mtvec_out,
  output logic [31:0] mepc_out,
  output logic        illegal      // raddr 기준: 미구현 CSR
);


endmodule
