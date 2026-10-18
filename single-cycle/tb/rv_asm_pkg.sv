// TB 전용 RV32I 어셈블러 (합성 대상 아님)
//   instr = asm("addi x1, x0, 5");
//   instr = asm("lw a0, -4(sp)");
// 레지스터: x0~x31, ABI 이름(zero, ra, sp, a0, ...)
// 즉시값  : 10진수, 0x 16진수, 음수 가능. branch/jal은 바이트 오프셋
// pseudo  : nop, mv, j, ret
package rv_asm;
import rv32i::*;

// ---------------- 형식별 인코딩 ----------------
function automatic logic [31:0] enc_r(logic [6:0] f7, logic [2:0] f3, logic [4:0] rs1, rs2, rd, logic [6:0] op);
    return {f7, rs2, rs1, f3, rd, op};
endfunction
function automatic logic [31:0] enc_i(logic [11:0] imm, logic [2:0] f3, logic [4:0] rs1, rd, logic [6:0] op);
    return {imm, rs1, f3, rd, op};
endfunction
function automatic logic [31:0] enc_s(logic [11:0] imm, logic [2:0] f3, logic [4:0] rs1, rs2, logic [6:0] op);
    return {imm[11:5], rs2, rs1, f3, imm[4:0], op};
endfunction
function automatic logic [31:0] enc_b(logic [12:0] imm, logic [2:0] f3, logic [4:0] rs1, rs2, logic [6:0] op);
    return {imm[12], imm[10:5], rs2, rs1, f3, imm[4:1], imm[11], op};
endfunction
function automatic logic [31:0] enc_u(logic [19:0] imm, logic [4:0] rd, logic [6:0] op);
    return {imm, rd, op};
endfunction
function automatic logic [31:0] enc_j(logic [20:0] imm, logic [4:0] rd, logic [6:0] op);
    return {imm[20], imm[10:1], imm[11], imm[19:12], rd, op};
endfunction

// ---------------- 파싱 ----------------
typedef string strq_t[$];

// 공백 , ( ) 로 분리, # 뒤는 주석
function automatic strq_t tokenize(string s);
    strq_t t;
    int start = -1;
    for (int i = 0; i <= s.len(); i++) begin
        byte c = (i < s.len()) ? s.getc(i) : " ";
        if (c == "#") c = " ";
        if (c == " " || c == "," || c == "(" || c == ")" || c == "\t") begin
            if (start >= 0) t.push_back(s.substr(start, i - 1));
            start = -1;
            if (i < s.len() && s.getc(i) == "#") break;
        end
        else if (start < 0) start = i;
    end
    return t;
endfunction

// 레지스터 번호, 레지스터가 아니면 -1
function automatic int reg_idx(string r);
    int n;
    if (r.len() >= 2 && r.getc(0) == "x") begin
        for (int i = 1; i < r.len(); i++)
            if (r.getc(i) < "0" || r.getc(i) > "9") return -1;
        n = r.substr(1, r.len() - 1).atoi();
        return (n inside {[0:31]}) ? n : -1;
    end
    case (r)
        "zero" : return 0;   "ra" : return 1;   "sp" : return 2;   "gp" : return 3;   "tp" : return 4;
        "t0" : return 5;     "t1" : return 6;   "t2" : return 7;
        "s0", "fp" : return 8;                  "s1" : return 9;
        "a0" : return 10;    "a1" : return 11;  "a2" : return 12;  "a3" : return 13;
        "a4" : return 14;    "a5" : return 15;  "a6" : return 16;  "a7" : return 17;
        "s2" : return 18;    "s3" : return 19;  "s4" : return 20;  "s5" : return 21;
        "s6" : return 22;    "s7" : return 23;  "s8" : return 24;  "s9" : return 25;
        "s10" : return 26;   "s11" : return 27;
        "t3" : return 28;    "t4" : return 29;  "t5" : return 30;  "t6" : return 31;
        default : return -1;
    endcase
endfunction

function automatic logic [4:0] reg_num(string r, string line);
    int n = reg_idx(r);
    if (n < 0) $fatal(1, "asm: bad register '%s' in \"%s\"", r, line);
    return n[4:0];
endfunction

function automatic int imm_val(string s, string line);
    bit neg = 0;
    int v;
    if (s.len() > 0 && s.getc(0) == "-") begin neg = 1; s = s.substr(1, s.len() - 1); end
    if (s.len() == 0) $fatal(1, "asm: bad immediate in \"%s\"", line);
    if (s.len() > 2 && s.substr(0, 1) == "0x") begin
        string h = s.substr(2, s.len() - 1);
        for (int i = 0; i < h.len(); i++)
            if (!(h.getc(i) inside {["0":"9"], ["a":"f"]})) $fatal(1, "asm: bad immediate '%s' in \"%s\"", s, line);
        v = h.atohex();
    end
    else begin
        for (int i = 0; i < s.len(); i++)
            if (s.getc(i) < "0" || s.getc(i) > "9") $fatal(1, "asm: bad immediate '%s' in \"%s\"", s, line);
        v = s.atoi();
    end
    return neg ? -v : v;
endfunction

function automatic void range_chk(int v, int lo, int hi, string line);
    if (v < lo || v > hi) $fatal(1, "asm: immediate %0d out of range [%0d, %0d] in \"%s\"", v, lo, hi, line);
endfunction

function automatic void nargs(strq_t t, int n, string line);
    if (t.size() != n + 1) $fatal(1, "asm: expected %0d operands in \"%s\"", n, line);
endfunction

// ---------------- 어셈블러 ----------------
function automatic logic [31:0] asm(string line);
    strq_t t = tokenize(line.tolower());
    string m;
    logic [6:0] f7 = 7'h00;
    logic [2:0] f3 = 3'b000;
    logic [4:0] rd, rs1, rs2;
    int imm;

    if (t.size() == 0) $fatal(1, "asm: empty line");
    m = t[0];

    case (m)
        // R-type
        "add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and" : begin
            case (m)
                "add"  : f3 = 3'b000;  "sub" : begin f3 = 3'b000; f7 = 7'h20; end
                "sll"  : f3 = 3'b001;  "slt" : f3 = 3'b010;  "sltu" : f3 = 3'b011;
                "xor"  : f3 = 3'b100;  "srl" : f3 = 3'b101;  "sra"  : begin f3 = 3'b101; f7 = 7'h20; end
                "or"   : f3 = 3'b110;  "and" : f3 = 3'b111;
            endcase
            nargs(t, 3, line);
            return enc_r(f7, f3, reg_num(t[2], line), reg_num(t[3], line), reg_num(t[1], line), OP_OP);
        end

        // I-type 산술
        "addi", "slti", "sltiu", "xori", "ori", "andi" : begin
            case (m)
                "addi" : f3 = 3'b000;  "slti" : f3 = 3'b010;  "sltiu" : f3 = 3'b011;
                "xori" : f3 = 3'b100;  "ori"  : f3 = 3'b110;  "andi"  : f3 = 3'b111;
            endcase
            nargs(t, 3, line);
            imm = imm_val(t[3], line);
            range_chk(imm, -2048, 2047, line);
            return enc_i(imm[11:0], f3, reg_num(t[2], line), reg_num(t[1], line), OP_OPIMM);
        end

        // shift 즉시값
        "slli", "srli", "srai" : begin
            case (m)
                "slli" : f3 = 3'b001;  "srli" : f3 = 3'b101;  "srai" : begin f3 = 3'b101; f7 = 7'h20; end
            endcase
            nargs(t, 3, line);
            imm = imm_val(t[3], line);
            range_chk(imm, 0, 31, line);
            return enc_i({f7, imm[4:0]}, f3, reg_num(t[2], line), reg_num(t[1], line), OP_OPIMM);
        end

        // load : lw rd, imm(rs1)  /  lw rd, (rs1)
        "lb", "lh", "lw", "lbu", "lhu" : begin
            case (m)
                "lb" : f3 = 3'b000;  "lh" : f3 = 3'b001;  "lw" : f3 = 3'b010;
                "lbu" : f3 = 3'b100; "lhu" : f3 = 3'b101;
            endcase
            if (t.size() == 3) begin imm = 0; rs1 = reg_num(t[2], line); end
            else begin nargs(t, 3, line); imm = imm_val(t[2], line); rs1 = reg_num(t[3], line); end
            range_chk(imm, -2048, 2047, line);
            return enc_i(imm[11:0], f3, rs1, reg_num(t[1], line), OP_LOAD);
        end

        // store : sw rs2, imm(rs1)
        "sb", "sh", "sw" : begin
            case (m)
                "sb" : f3 = 3'b000;  "sh" : f3 = 3'b001;  "sw" : f3 = 3'b010;
            endcase
            if (t.size() == 3) begin imm = 0; rs1 = reg_num(t[2], line); end
            else begin nargs(t, 3, line); imm = imm_val(t[2], line); rs1 = reg_num(t[3], line); end
            range_chk(imm, -2048, 2047, line);
            return enc_s(imm[11:0], f3, rs1, reg_num(t[1], line), OP_STORE);
        end

        // branch : beq rs1, rs2, offset
        "beq", "bne", "blt", "bge", "bltu", "bgeu" : begin
            case (m)
                "beq" : f3 = 3'b000;  "bne"  : f3 = 3'b001;  "blt"  : f3 = 3'b100;
                "bge" : f3 = 3'b101;  "bltu" : f3 = 3'b110;  "bgeu" : f3 = 3'b111;
            endcase
            nargs(t, 3, line);
            imm = imm_val(t[3], line);
            range_chk(imm, -4096, 4094, line);
            if (imm[0]) $fatal(1, "asm: odd branch offset in \"%s\"", line);
            return enc_b(imm[12:0], f3, reg_num(t[1], line), reg_num(t[2], line), OP_BRANCH);
        end

        // lui / auipc rd, imm20
        "lui", "auipc" : begin
            nargs(t, 2, line);
            imm = imm_val(t[2], line);
            range_chk(imm, 0, 32'hFFFFF, line);
            return enc_u(imm[19:0], reg_num(t[1], line), (m == "lui") ? OP_LUI : OP_AUIPC);
        end

        // jal rd, offset  /  jal offset (rd = ra)
        "jal", "j" : begin
            if (m == "j") begin nargs(t, 1, line); rd = 0; imm = imm_val(t[1], line); end
            else if (t.size() == 2) begin rd = 1; imm = imm_val(t[1], line); end
            else begin nargs(t, 2, line); rd = reg_num(t[1], line); imm = imm_val(t[2], line); end
            range_chk(imm, -(1 << 20), (1 << 20) - 2, line);
            if (imm[0]) $fatal(1, "asm: odd jump offset in \"%s\"", line);
            return enc_j(imm[20:0], rd, OP_JAL);
        end

        // jalr rd, imm(rs1)  /  jalr rd, rs1, imm  /  jalr rs1 (rd = ra)
        "jalr" : begin
            if (t.size() == 2) begin rd = 1; rs1 = reg_num(t[1], line); imm = 0; end
            else if (t.size() == 3) begin rd = reg_num(t[1], line); rs1 = reg_num(t[2], line); imm = 0; end
            else begin
                nargs(t, 3, line);
                rd = reg_num(t[1], line);
                if (reg_idx(t[2]) >= 0) begin rs1 = reg_num(t[2], line); imm = imm_val(t[3], line); end
                else                    begin imm = imm_val(t[2], line); rs1 = reg_num(t[3], line); end
            end
            range_chk(imm, -2048, 2047, line);
            return enc_i(imm[11:0], 3'b000, rs1, rd, OP_JALR);
        end

        // pseudo
        "nop" : begin nargs(t, 0, line); return enc_i(12'd0, 3'b000, 5'd0, 5'd0, OP_OPIMM); end
        "mv"  : begin nargs(t, 2, line); return enc_i(12'd0, 3'b000, reg_num(t[2], line), reg_num(t[1], line), OP_OPIMM); end
        "ret" : begin nargs(t, 0, line); return enc_i(12'd0, 3'b000, 5'd1, 5'd0, OP_JALR); end

        // system
        "ecall"  : begin nargs(t, 0, line); return 32'h00000073; end
        "ebreak" : begin nargs(t, 0, line); return 32'h00100073; end

        default : $fatal(1, "asm: unknown instruction '%s' in \"%s\"", m, line);
    endcase
    return 32'hx;
endfunction

endpackage
