module mem_16k(
    input clk,
    input [31:0] write_data, i_addr, d_addr,
    input [1:0] mem_byte,
    input mem_read, mem_write,
    output logic [31:0] i_data, d_data,
    output miss_addr
);
import rv32i::*;
logic [31:0] memory[0:4095] = '{default: 32'd0};

always_ff @(posedge clk) begin : write
    if (mem_write) begin
        case (mem_byte)
            BYTE1 : memory[d_addr[31:2]][8*d_addr[1:0] +: 8] <= write_data[7:0];
            BYTE2 : memory[d_addr[31:2]][8*d_addr[1:0] +: 16] <= write_data[15:0];
            BYTE4 : memory[d_addr[31:2]] <= write_data;
            default : memory[d_addr[31:2]] <= write_data;
        endcase
    end
end

always_comb begin : read
    i_data = memory[i_addr[31:2]];
    if (mem_read) begin
        case (mem_byte)
            BYTE1 : d_data = memory[d_addr[31:2]][8*d_addr[1:0] +: 8];
            BYTE2 : d_data = memory[d_addr[31:2]][8*d_addr[1:0] +: 16];
            BYTE4 : d_data = memory[d_addr[31:2]];
            default : d_data = memory[d_addr[31:2]];
        endcase
    end
end

always_comb begin
    miss_addr = 0;
    if (|i_addr[1:0] == 1) miss_addr = 1;
    if (mem_byte == BYTE2) miss_addr = d_addr[0] == 0 ? 0 : 1;
    if (mem_byte == BYTE4) miss_addr = |d_addr[1:0] == 0 ? 0 : 1;
end

endmodule