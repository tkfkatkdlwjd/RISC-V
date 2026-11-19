module instr_decoder (
    input [31:0] instr,
    output logic [31:0] imm,
    output logic [4:0] rs1, rs2, rd,
    output logic [3:0] funct_op, 
    output logic [1:0] Mresult, mem_byte,
    output logic Ma, Mb, reg_write, mem_write, mem_read, branch, jump, jalr, lui, sign_ext,
    output logic ecall, ebreak, unidentified
);
import rv32i::*;

logic [6:0] funct7;
logic [2:0] funct3;
logic [6:0] opcode;
assign funct7 = instr[31:25];
assign funct3 = instr[14:12];
assign rd = instr[11:7];
assign opcode = instr[6:0];

always_comb begin : main_decoder
    reg_write = 0;   mem_write = 0;   mem_read = 0;
    Ma = SRC_A_RS1; Mb = SRC_B_RS2; funct_op = ADD;
    Mresult = WB_ALU; lui = 0; branch = 0; jump = 0; jalr = 0;
    mem_byte = 0; sign_ext = 0;
    rs1 = '0;  rs2 = '0;  imm = 32'b0;
    case (opcode)
        OP_OP : begin
            unidentified = 0;
            reg_write = 1;
            rs1 = instr[19:15];  rs2 = instr[24:20];
            case (funct3)
                3'b000 : funct_op = funct7[5] ? SUB : ADD;
                3'b001 : funct_op = SLL;
                3'b010 : funct_op = LESS;
                3'b011 : funct_op = LESSU;
                3'b100 : funct_op = XOR;
                3'b101 : funct_op = funct7[5] ? SRA : SRL;
                3'b110 : funct_op = OR;
                3'b111 : funct_op = AND;
                default :;
            endcase
        end
        OP_OPIMM : begin
            unidentified = 0;
            reg_write = 1;
            Mb = SRC_B_IMM;
            rs1 = instr[19:15];
            imm = {{20{instr[31]}},instr[31:20]};
            case (funct3)
                3'b000 : funct_op = ADD;
                3'b010 : funct_op = LESS;
                3'b011 : funct_op = LESSU;
                3'b100 : funct_op = XOR;
                3'b110 : funct_op = OR;
                3'b111 : funct_op = AND;
                3'b001 : begin 
                            funct_op = SLL;
                            imm = {27'd0, instr[24:20]};
                         end
                3'b101 : begin 
                            funct_op = funct7[5] ? SRA : SRL;
                            imm = {27'd0, instr[24:20]};
                         end
                default :;
            endcase
        end
        OP_LOAD : begin
            unidentified = 0;
            reg_write = 1;
            mem_read = 1;
            Mb = SRC_B_IMM;
            Mresult = WB_MEM;
            rs1 = instr[19:15];
            imm = {{20{instr[31]}},instr[31:20]};
            case (funct3)
                3'b000 : begin mem_byte = BYTE1; sign_ext = SEXT; end
                3'b001 : begin mem_byte = BYTE2; sign_ext = SEXT; end
                3'b010 : begin mem_byte = BYTE4;                  end
                3'b100 : begin mem_byte = BYTE1; sign_ext = ZEXT; end
                3'b101 : begin mem_byte = BYTE2; sign_ext = ZEXT; end
                default :;
            endcase
        end
        OP_STORE : begin
            unidentified = 0;
            Mb = SRC_B_IMM;
            mem_write = 1;
            rs1 = instr[19:15];  rs2 = instr[24:20];
            imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            case (funct3)
                3'b000 : begin mem_byte = BYTE1; end
                3'b001 : begin mem_byte = BYTE2; end
                3'b010 : begin mem_byte = BYTE4; end
                default :;
            endcase
        end
        OP_BRANCH : begin
            unidentified = 0;
            branch = 1;
            rs1 = instr[19:15];  rs2 = instr[24:20];
            imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
            case (funct3)
                3'b000 : funct_op = EQL;
                3'b001 : funct_op = NOTEQL;
                3'b100 : funct_op = LESS;
                3'b101 : funct_op = GRT_EQL;
                3'b110 : funct_op = LESSU;
                3'b111 : funct_op = GRT_EQLU;
                default :;
            endcase
        end
        OP_JAL : begin 
            unidentified = 0;
            Ma = SRC_A_PC;
            Mb = SRC_B_IMM;
            reg_write = 1;
            Mresult = WB_PC4;
            jump = 1;
            imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
        end
        OP_JALR : begin
            unidentified = 0;
            Mb = SRC_B_IMM;
            reg_write = 1;
            Mb = SRC_B_IMM;
            Mresult = WB_PC4;
            jalr = 1;
            rs1 = instr[19:15];
            imm = {{20{instr[31]}},instr[31:20]};
        end
        OP_LUI : begin
            unidentified = 0;
            reg_write = 1;
            Mresult = WB_IMM;
            imm = {instr[31:12], 12'd0};
            lui = 1;
        end
        OP_AUIPC : begin
            unidentified = 0;
            reg_write = 1;
            Ma = SRC_A_PC;
            Mb = SRC_B_IMM;
            imm = {instr[31:12], 12'd0};
        end
    endcase
end

always_comb begin
    ecall = 0;
    ebreak = 0;
    if (instr == 32'h00000073) ecall  = 1;
    if (instr == 32'h00100073) ebreak = 1;
end

/*
always_comb begin
    imm = 32'd0;
    case (type_sel)
        I_TYPE : begin
            if (instr[6:0] == OP_OPIMM && (instr[14:12] == 3'b001 || instr[14:12] == 3'b101))
                 imm = {27'd0, instr[24:20]};
            else imm = {{20{instr[31]}},instr[31:20]};
        end
        S_TYPE : imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
        B_TYPE : imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
        U_TYPE : imm = {instr[31:12], 12'd0};
        J_TYPE : imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
        default : ;
    endcase
end
*/
endmodule
