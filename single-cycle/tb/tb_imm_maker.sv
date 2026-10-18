module tb_imm_maker;
import rv32i::*;

logic [31:0] instr;
logic [2:0] type_sel;
logic [31:0] imm;
logic ecall, ebreak;

imm_maker dut(
    .instr(instr),.type_sel(type_sel),
    .imm(imm),.ecall(ecall),.ebreak(ebreak)
);

integer err = 0, n_test = 0;

// mask : 비교할 비트 (시프트는 shamt만 의미 있음)
task automatic check(string name, logic [31:0] ins, logic [2:0] ts,
                     logic [31:0] exp, logic [31:0] mask = 32'hFFFFFFFF);
    instr = ins;
    type_sel = ts;
    #1;
    n_test++;
    if ((imm & mask) !== (exp & mask) || ecall !== 0 || ebreak !== 0) begin
        err++;
        $display("[%s] instr=%h : imm expected %h, got %h (ecall=%b, ebreak=%b)",
                 name, ins, exp & mask, imm & mask, ecall, ebreak);
    end
endtask

// 즉시값을 먼저 정하고 인코딩한 뒤, 복원 결과를 비교
task automatic test_all(logic [31:0] r);
    logic [4:0] rs1 = r[4:0], rs2 = r[9:5], rd = r[14:10];
    logic [11:0] i12 = r[11:0];
    logic [12:0] b13 = {r[12:1], 1'b0};
    logic [20:0] j21 = {r[20:1], 1'b0};
    logic [19:0] u20 = r[31:12];
    logic [4:0] shamt = r[24:20];

    // I-type : opimm / load / jalr
    for (int f3 = 0; f3 < 8; f3++) begin
        if (f3 == 1 || f3 == 5) continue;
        check("opimm", {i12, rs1, 3'(f3), rd, OP_OPIMM}, I_TYPE, {{20{i12[11]}}, i12});
    end
    check("slli", {7'h00, shamt, rs1, 3'b001, rd, OP_OPIMM}, I_TYPE, {27'd0, shamt}, 32'h1F);
    check("srli", {7'h00, shamt, rs1, 3'b101, rd, OP_OPIMM}, I_TYPE, {27'd0, shamt}, 32'h1F);
    check("srai", {7'h20, shamt, rs1, 3'b101, rd, OP_OPIMM}, I_TYPE, {27'd0, shamt}, 32'h1F);
    check("lb",   {i12, rs1, 3'b000, rd, OP_LOAD}, I_TYPE, {{20{i12[11]}}, i12});
    check("lh",   {i12, rs1, 3'b001, rd, OP_LOAD}, I_TYPE, {{20{i12[11]}}, i12});
    check("lw",   {i12, rs1, 3'b010, rd, OP_LOAD}, I_TYPE, {{20{i12[11]}}, i12});
    check("lbu",  {i12, rs1, 3'b100, rd, OP_LOAD}, I_TYPE, {{20{i12[11]}}, i12});
    check("lhu",  {i12, rs1, 3'b101, rd, OP_LOAD}, I_TYPE, {{20{i12[11]}}, i12});
    check("jalr", {i12, rs1, 3'b000, rd, OP_JALR}, I_TYPE, {{20{i12[11]}}, i12});

    // S-type
    for (int f3 = 0; f3 < 3; f3++)
        check("store", {i12[11:5], rs2, rs1, 3'(f3), i12[4:0], OP_STORE}, S_TYPE, {{20{i12[11]}}, i12});

    // B-type
    for (int f3 = 0; f3 < 8; f3++) begin
        if (f3 == 2 || f3 == 3) continue;
        check("branch", {b13[12], b13[10:5], rs2, rs1, 3'(f3), b13[4:1], b13[11], OP_BRANCH},
              B_TYPE, {{19{b13[12]}}, b13});
    end

    // U-type
    check("lui",   {u20, rd, OP_LUI},   U_TYPE, {u20, 12'd0});
    check("auipc", {u20, rd, OP_AUIPC}, U_TYPE, {u20, 12'd0});

    // J-type
    check("jal", {j21[20], j21[10:1], j21[11], j21[19:12], rd, OP_JAL}, J_TYPE, {{11{j21[20]}}, j21});

    // R-type : 즉시값 없음 -> 0
    check("op", {r[31:7], OP_OP}, R_TYPE, 32'd0);
endtask

task automatic check_sys(string name, logic [31:0] ins, logic exp_ecall, exp_ebreak);
    instr = ins;
    type_sel = I_TYPE;
    #1;
    n_test++;
    if (ecall !== exp_ecall || ebreak !== exp_ebreak) begin
        err++;
        $display("[%s] instr=%h : ecall/ebreak expected %b%b, got %b%b",
                 name, ins, exp_ecall, exp_ebreak, ecall, ebreak);
    end
endtask

initial begin
    instr = 0; type_sel = 0;  #10;

    // 경계값 : 부호 비트 0/1, 비트 패턴
    test_all(32'h00000000);
    test_all(32'hFFFFFFFF);
    test_all(32'hAAAAAAAA);
    test_all(32'h55555555);
    test_all(32'h80000000);
    test_all(32'h7FFFFFFF);

    for (int i = 0; i < 1000; i++)
        test_all($random);

    // ecall / ebreak
    check_sys("ecall",  32'h00000073, 1, 0);
    check_sys("ebreak", 32'h00100073, 0, 1);
    check_sys("csr",    32'h30002073, 0, 0);      // SYSTEM opcode지만 ecall/ebreak 아님
    check_sys("addi",   32'h00000013, 0, 0);      // imm=0인 다른 opcode
    check_sys("addi1",  32'h00100013, 0, 0);      // imm=1인 다른 opcode

    $display("tests : %0d, error : %0d", n_test, err);
    $finish;
end

endmodule
