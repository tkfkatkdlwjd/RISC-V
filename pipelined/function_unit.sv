module funct_unit (
    input [31:0] in1, in2,
    input [3:0] funct_op,
    output logic [31:0] funct_out
);
import rv32i::*;

always_comb begin
    funct_out = 0;
    case (funct_op)
        ADD : funct_out = in1 + in2;
        SUB : funct_out = in1 - in2;
        AND : funct_out = in1 & in2;
        OR : funct_out = in1 | in2;
        XOR : funct_out = in1 ^ in2;
        SLL : funct_out = in1 << in2[4:0];
        SRL : funct_out = in1 >> in2[4:0];
        SRA : funct_out = $signed(in1) >>> in2[4:0];
        LESS : funct_out = ($signed(in1) < $signed(in2));
        LESSU : funct_out = (in1 < in2);
        LESS_EQL : funct_out = ($signed(in1) <= $signed(in2));
        GRT : funct_out = ($signed(in1) > $signed(in2));
        GRT_EQL : funct_out = ($signed(in1) >= $signed(in2));
        GRT_EQLU : funct_out = (in1 >= in2);
        EQL : funct_out = (in1 == in2);
        NOTEQL : funct_out = (in1 != in2);
        default :;
    endcase
end
endmodule
