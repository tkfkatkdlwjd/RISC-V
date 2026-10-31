module pipereg_if(
    input clk, stall, flush,
    input [31:0] instr_F, PC_out_F,
    output logic valid_D,
    output logic [31:0] instr_D, PC_out_D
);
always_ff @(posedge clk) begin
    if (flush) begin
        valid_D <= 0;
        instr_D <= 32'h00000013;
    end
    else if(!stall) begin
        valid_D <= 1;
        instr_D <= instr_F;
        PC_out_D <= PC_out_F;
    end
end

endmodule

