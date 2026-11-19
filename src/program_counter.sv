module PC (
    input clk, rst,
    input [31:0] PC_in,
    input PC_write, stall,
    output logic [31:0] PC_out
);

(* keep = "true" *) logic [31:0] next_PC;
assign next_PC = PC_out + 4;

always_ff @(posedge clk or posedge rst) begin
    if (rst) PC_out <= '0;
    else begin
        if (PC_write) PC_out <= PC_in;
        else if (!stall) PC_out <= next_PC;
    end
end
endmodule