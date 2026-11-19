module instr_decoder (
    input [31:0] instr,
    output [4:0] aa, ba, da,
    output logic [3:0] funct_op, 
    output logic [2:0] type_sel,
    output logic [1:0] Mresult, mem_byte,
    output logic Ma, Mb, reg_write, mem_write, mem_read, branch, jump, jalr, sign_ext,
    output logic unidentified
);
import rv32i::*;

logic [6:0] funct7;
logic [2:0] funct3;
logic [6:0] opcode;
assign funct7 = instr[31:25];
assign ba     = instr[24:20];
assign aa     = instr[19:15];
assign funct3 = instr[14:12];
assign da     = instr[11:7];
assign opcode = instr[6:0];

always_comb begin : main_decoder
    type_sel = R_TYPE;  reg_write = 0;  mem_write = 0;  mem_read = 0;
    Ma = SRC_A_RS1; Mb = SRC_B_RS2;  funct_op = ADD;  
    Mresult = WB_ALU;  branch = 0;  jump = 0;  jalr = 0;
    mem_byte = 0; sign_ext = 0;
    case (opcode)
        OP_OP : begin       //
            unidentified = 0;
            type_sel = R_TYPE;
            reg_write = 1;
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
        OP_OPIMM : begin        //
            unidentified = 0;
            type_sel = I_TYPE;
            reg_write = 1;
            Mb = SRC_B_IMM;
            case (funct3)
                3'b000 : funct_op = ADD;
                3'b010 : funct_op = LESS;
                3'b011 : funct_op = LESSU;
                3'b100 : funct_op = XOR;
                3'b110 : funct_op = OR;
                3'b111 : funct_op = AND;
                3'b001 : funct_op = SLL;
                3'b101 : funct_op = funct7[5] ? SRA : SRL;
                default :;
            endcase
        end
        OP_LOAD : begin
            unidentified = 0;
            type_sel = I_TYPE;
            reg_write = 1;
            mem_read = 1;
            Mb = SRC_B_IMM;
            Mresult = WB_MEM;
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
            type_sel = S_TYPE;
            Mb = SRC_B_IMM;
            mem_write = 1;
            case (funct3)
                3'b000 : begin mem_byte = BYTE1; end
                3'b001 : begin mem_byte = BYTE2; end
                3'b010 : begin mem_byte = BYTE4; end
                default :;
            endcase
        end
        OP_BRANCH : begin
            unidentified = 0;
            type_sel = B_TYPE;
            branch = 1;
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
            type_sel = J_TYPE; 
            Ma = SRC_A_PC;
            Mb = SRC_B_IMM;
            reg_write = 1;
            Mresult = WB_PC4;
            jump = 1;
        end
        OP_JALR : begin
            unidentified = 0;
            type_sel = I_TYPE;
            Mb = SRC_B_IMM;
            reg_write = 1;
            Mb = SRC_B_IMM;
            Mresult = WB_PC4;
            jalr = 1;
        end
        OP_LUI : begin
            unidentified = 0;
            type_sel = U_TYPE;
            reg_write = 1;
            Mresult = WB_IMM;
        end
        OP_AUIPC : begin
            unidentified = 0;
            type_sel = U_TYPE;
            reg_write = 1;
            Ma = SRC_A_PC;
            Mb = SRC_B_IMM;
        end
        default: unidentified = 1;
    endcase
end
endmodule
