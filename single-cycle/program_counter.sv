module PC (
    input clk, rst,
    input [31:0] PC_in,
    input PC_write,
    output logic [31:0] PC_out
);

always_ff @(posedge clk or posedge rst) begin
    if (rst) PC_out <= '0;
    else begin
        if (PC_write) PC_out <= PC_in;
        else PC_out <= PC_out + 4;
    end
end
endmodule