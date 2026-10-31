module reg_file (
    input clk,
    input [31:0] write_data,
    input [4:0] rs1, rs2, rd,
    input reg_write,
    output logic [31:0] rs1_data, rs2_data
);
logic [31:0] register[1:31] = '{default: 32'd0};

always_ff @(posedge clk) begin
    if (reg_write && (rd != 5'b0)) begin
        register[rd] <= write_data;
    end
end

always_comb begin
    rs1_data = (rs1 == 5'd0) ? 32'd0 : register[rs1];
    rs2_data = (rs2 == 5'd0) ? 32'd0 : register[rs2];
    if (reg_write && rd != 5'b0 && rs1 == rd) rs1_data = write_data;
    if (reg_write && rd != 5'b0 && rs2 == rd) rs2_data = write_data;
end

endmodule
