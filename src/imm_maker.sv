module imm_maker (
    input [31:0] instr,
    input [2:0] type_sel,
    output logic [31:0] imm,
    output logic ecall, ebreak
);
import rv32i::*;

always_comb begin
    ecall = 0;
    ebreak = 0;
    if (instr[6:0] == 7'b1110011) begin
        if (instr[31:20] == 12'd0) ecall = 1;
        if (instr[31:20] == 12'd1) ebreak = 1;
    end
end

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

endmodule