module funct_unit (
    input [31:0] in1, in2,
    input [3:0] funct_op,
    output logic [31:0] alu_out
);
import rv32i::*;

always_comb begin
    alu_out = 0;
    case (funct_op)
        ADD : alu_out = in1 + in2;
        SUB : alu_out = in1 - in2;
        AND : alu_out = in1 & in2;
        OR  : alu_out = in1 | in2;
        XOR : alu_out = in1 ^ in2;
        SLL : alu_out = in1 << in2[4:0];
        SRL : alu_out = in1 >> in2[4:0];
        SRA : alu_out = $signed(in1) >>> in2[4:0];
        LESS : alu_out = ($signed(in1) < $signed(in2));
        LESSU : alu_out = (in1 < in2);
        LESS_EQL : alu_out = ($signed(in1) <= $signed(in2));
        GRT : alu_out = ($signed(in1) > $signed(in2));
        GRT_EQL : alu_out = ($signed(in1) >= $signed(in2));
        GRT_EQLU : alu_out = (in1 >= in2);
        EQL : alu_out = (in1 == in2);
        NOTEQL : alu_out = (in1 != in2);
        default :;
    endcase
end
endmodule
