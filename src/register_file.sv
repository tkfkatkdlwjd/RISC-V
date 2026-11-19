module reg_file (
    input clk,
    input [31:0] write_data,
    input [4:0] aa, ba, da,
    input reg_write,
    output logic [31:0] rs1, rs2
);
logic [31:0] register[1:31] = '{default: 32'd0};

always_ff @(posedge clk) begin
    if (reg_write && (da != 5'b0)) begin
        register[da] <= write_data;
    end
end

always_comb begin
    rs1 = (aa == 5'd0) ? 32'd0 : register[aa];
    rs2 = (ba == 5'd0) ? 32'd0 : register[ba];
end
endmodule
