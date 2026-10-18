module tb_instr_decoder;
import rv32i::*;
import rv_asm::*;      // enc_r/i/s/b/u/j

logic [31:0] instr;
logic [4:0] aa, ba, da;
logic [3:0] funct_op;
logic [2:0] type_sel;
logic [1:0] Mresult, mem_byte;
logic Ma, Mb, reg_write, mem_write, mem_read, branch, jump, jalr, sign_ext;
logic unidentified;

instr_decoder dut(
    .instr(instr),
    .aa(aa),.ba(ba),.da(da),.funct_op(funct_op),.type_sel(type_sel),.Mresult(Mresult),.Ma(Ma),.Mb(Mb),
    .reg_write(reg_write),.mem_write(mem_write),.mem_read(mem_read),.mem_byte(mem_byte),.sign_ext(sign_ext),
    .branch(branch),.jump(jump),.jalr(jalr),.unidentified(unidentified)
);

// 기대값 묶음
typedef struct {
    logic [3:0] funct_op;
    logic [2:0] type_sel;
    logic [1:0] Mresult, mem_byte;
    logic Ma, Mb, reg_write, mem_write, mem_read, branch, jump, jalr, sign_ext;
    logic unidentified;
} ctrl_t;

// 디코더의 기본값과 동일
function automatic ctrl_t base();
    ctrl_t c;
    c.funct_op = ADD;       c.type_sel = R_TYPE;
    c.Mresult = WB_ALU;     c.mem_byte = BYTE1;
    c.Ma = SRC_A_RS1;       c.Mb = SRC_B_RS2;
    c.reg_write = 0; c.mem_write = 0; c.mem_read = 0;
    c.branch = 0; c.jump = 0; c.jalr = 0; c.sign_ext = 0;
    c.unidentified = 0;
    return c;
endfunction

integer err = 0, n_test = 0;

`define CMP(sig) \
    if (sig !== exp.sig) begin \
        $display("[%s] instr=%h : %s expected %0d, got %0d", name, ins, `"sig`", exp.sig, sig); \
        bad = 1; \
    end

task automatic check(string name, logic [31:0] ins, ctrl_t exp);
    logic bad = 0;
    instr = ins;
    #1;
    n_test++;
    // 레지스터 주소는 항상 고정 위치에서 뽑힘
    if (aa !== ins[19:15]) begin $display("[%s] instr=%h : aa expected %0d, got %0d", name, ins, ins[19:15], aa); bad = 1; end
    if (ba !== ins[24:20]) begin $display("[%s] instr=%h : ba expected %0d, got %0d", name, ins, ins[24:20], ba); bad = 1; end
    if (da !== ins[11:7])  begin $display("[%s] instr=%h : da expected %0d, got %0d", name, ins, ins[11:7], da);  bad = 1; end
    `CMP(funct_op)
    `CMP(type_sel)
    `CMP(Mresult)
    `CMP(mem_byte)
    `CMP(Ma)
    `CMP(Mb)
    `CMP(reg_write)
    `CMP(mem_write)
    `CMP(mem_read)
    `CMP(branch)
    `CMP(jump)
    `CMP(jalr)
    `CMP(sign_ext)
    `CMP(unidentified)
    if (bad) err++;
endtask

// ---------------- 명령어 그룹별 테스트 ----------------
task automatic test_op(logic [4:0] rs1, rs2, rd);
    ctrl_t e = base();
    e.type_sel = R_TYPE; e.reg_write = 1;
    e.funct_op = ADD;   check("add",  enc_r(7'h00, 3'b000, rs1, rs2, rd, OP_OP), e);
    e.funct_op = SUB;   check("sub",  enc_r(7'h20, 3'b000, rs1, rs2, rd, OP_OP), e);
    e.funct_op = SLL;   check("sll",  enc_r(7'h00, 3'b001, rs1, rs2, rd, OP_OP), e);
    e.funct_op = LESS;  check("slt",  enc_r(7'h00, 3'b010, rs1, rs2, rd, OP_OP), e);
    e.funct_op = LESSU; check("sltu", enc_r(7'h00, 3'b011, rs1, rs2, rd, OP_OP), e);
    e.funct_op = XOR;   check("xor",  enc_r(7'h00, 3'b100, rs1, rs2, rd, OP_OP), e);
    e.funct_op = SRL;   check("srl",  enc_r(7'h00, 3'b101, rs1, rs2, rd, OP_OP), e);
    e.funct_op = SRA;   check("sra",  enc_r(7'h20, 3'b101, rs1, rs2, rd, OP_OP), e);
    e.funct_op = OR;    check("or",   enc_r(7'h00, 3'b110, rs1, rs2, rd, OP_OP), e);
    e.funct_op = AND;   check("and",  enc_r(7'h00, 3'b111, rs1, rs2, rd, OP_OP), e);
endtask

task automatic test_opimm(logic [11:0] imm, logic [4:0] rs1, rd);
    ctrl_t e = base();
    logic [4:0] shamt = imm[4:0];
    e.type_sel = I_TYPE; e.reg_write = 1; e.Mb = SRC_B_IMM;
    e.funct_op = ADD;   check("addi",  enc_i(imm, 3'b000, rs1, rd, OP_OPIMM), e);
    e.funct_op = LESS;  check("slti",  enc_i(imm, 3'b010, rs1, rd, OP_OPIMM), e);
    e.funct_op = LESSU; check("sltiu", enc_i(imm, 3'b011, rs1, rd, OP_OPIMM), e);
    e.funct_op = XOR;   check("xori",  enc_i(imm, 3'b100, rs1, rd, OP_OPIMM), e);
    e.funct_op = OR;    check("ori",   enc_i(imm, 3'b110, rs1, rd, OP_OPIMM), e);
    e.funct_op = AND;   check("andi",  enc_i(imm, 3'b111, rs1, rd, OP_OPIMM), e);
    e.funct_op = SLL;   check("slli",  enc_i({7'h00, shamt}, 3'b001, rs1, rd, OP_OPIMM), e);
    e.funct_op = SRL;   check("srli",  enc_i({7'h00, shamt}, 3'b101, rs1, rd, OP_OPIMM), e);
    e.funct_op = SRA;   check("srai",  enc_i({7'h20, shamt}, 3'b101, rs1, rd, OP_OPIMM), e);
endtask

task automatic test_load(logic [11:0] imm, logic [4:0] rs1, rd);
    ctrl_t e = base();
    e.type_sel = I_TYPE; e.reg_write = 1; e.mem_read = 1;
    e.Mb = SRC_B_IMM; e.Mresult = WB_MEM; e.funct_op = ADD;
    e.mem_byte = BYTE1; e.sign_ext = SEXT; check("lb",  enc_i(imm, 3'b000, rs1, rd, OP_LOAD), e);
    e.mem_byte = BYTE2; e.sign_ext = SEXT; check("lh",  enc_i(imm, 3'b001, rs1, rd, OP_LOAD), e);
    e.mem_byte = BYTE4; e.sign_ext = SEXT; check("lw",  enc_i(imm, 3'b010, rs1, rd, OP_LOAD), e);
    e.mem_byte = BYTE1; e.sign_ext = ZEXT; check("lbu", enc_i(imm, 3'b100, rs1, rd, OP_LOAD), e);
    e.mem_byte = BYTE2; e.sign_ext = ZEXT; check("lhu", enc_i(imm, 3'b101, rs1, rd, OP_LOAD), e);
endtask

task automatic test_store(logic [11:0] imm, logic [4:0] rs1, rs2);
    ctrl_t e = base();
    e.type_sel = S_TYPE; e.mem_write = 1; e.Mb = SRC_B_IMM; e.funct_op = ADD;
    e.mem_byte = BYTE1; check("sb", enc_s(imm, 3'b000, rs1, rs2, OP_STORE), e);
    e.mem_byte = BYTE2; check("sh", enc_s(imm, 3'b001, rs1, rs2, OP_STORE), e);
    e.mem_byte = BYTE4; check("sw", enc_s(imm, 3'b010, rs1, rs2, OP_STORE), e);
endtask

task automatic test_branch(logic [12:0] imm, logic [4:0] rs1, rs2);
    ctrl_t e = base();
    e.type_sel = B_TYPE; e.branch = 1;
    e.Ma = SRC_A_PC; e.Mb = SRC_B_IMM;      // 현재 디코더 구현 기준
    e.funct_op = EQL;      check("beq",  enc_b(imm, 3'b000, rs1, rs2, OP_BRANCH), e);
    e.funct_op = NOTEQL;   check("bne",  enc_b(imm, 3'b001, rs1, rs2, OP_BRANCH), e);
    e.funct_op = LESS;     check("blt",  enc_b(imm, 3'b100, rs1, rs2, OP_BRANCH), e);
    e.funct_op = GRT_EQL;  check("bge",  enc_b(imm, 3'b101, rs1, rs2, OP_BRANCH), e);
    e.funct_op = LESSU;    check("bltu", enc_b(imm, 3'b110, rs1, rs2, OP_BRANCH), e);
    e.funct_op = GRT_EQLU; check("bgeu", enc_b(imm, 3'b111, rs1, rs2, OP_BRANCH), e);
endtask

task automatic test_jump_upper(logic [31:0] r, logic [4:0] rs1, rd);
    ctrl_t e;

    e = base();
    e.type_sel = J_TYPE; e.reg_write = 1; e.jump = 1;
    e.Ma = SRC_A_PC; e.Mb = SRC_B_IMM; e.Mresult = WB_PC4;
    check("jal", enc_j({r[20:1], 1'b0}, rd, OP_JAL), e);

    e = base();
    e.type_sel = I_TYPE; e.reg_write = 1; e.jalr = 1;
    e.Mb = SRC_B_IMM; e.Mresult = WB_PC4;
    check("jalr", enc_i(r[11:0], 3'b000, rs1, rd, OP_JALR), e);

    e = base();
    e.type_sel = U_TYPE; e.reg_write = 1; e.Mresult = WB_IMM;
    check("lui", enc_u(r[31:12], rd, OP_LUI), e);

    e = base();
    e.type_sel = U_TYPE; e.reg_write = 1;
    e.Ma = SRC_A_PC; e.Mb = SRC_B_IMM;
    check("auipc", enc_u(r[31:12], rd, OP_AUIPC), e);
endtask

task automatic test_all(logic [31:0] r, logic [4:0] rs1, rs2, rd);
    test_op(rs1, rs2, rd);
    test_opimm(r[11:0], rs1, rd);
    test_load(r[11:0], rs1, rd);
    test_store(r[11:0], rs1, rs2);
    test_branch({r[12:1], 1'b0}, rs1, rs2);
    test_jump_upper(r, rs1, rd);
endtask

// 정의되지 않은 opcode -> unidentified = 1 (나머지 출력은 기본값)
task automatic test_unidentified(logic [31:0] ins);
    ctrl_t e = base();
    e.unidentified = 1;
    check("unknown", ins, e);
endtask

initial begin
    instr = 0;  #10;

    test_all(32'h00000000, 5'd0,  5'd0,  5'd0);
    test_all(32'hFFFFFFFF, 5'd31, 5'd31, 5'd31);
    test_all(32'hAAAAAAAA, 5'd10, 5'd21, 5'd5);
    test_all(32'h55555555, 5'd21, 5'd10, 5'd26);

    for (int i = 0; i < 200; i++)
        test_all($random, $random, $random, $random);

    // 정의된 opcode가 아닌 것 전부
    for (int op = 0; op < 128; op++) begin
        if (op inside {OP_OP, OP_OPIMM, OP_LOAD, OP_STORE, OP_BRANCH,
                       OP_JAL, OP_JALR, OP_LUI, OP_AUIPC}) continue;
        test_unidentified({$random} & 32'hFFFFFF80 | op);
        // 직전이 unknown이어도 unidentified가 0으로 돌아와야 함 (래치 확인)
        test_load($random, $random, $random);
    end

    $display("tests : %0d, error : %0d", n_test, err);
    $finish;
end

endmodule
