module top(
    input clk, rst
);
logic [31:0] pc, mem_addr, instr, mem_load_data, mem_write_data;
logic [1:0] mem_byte;
logic mem_read, mem_write;

single_cycle_core core(
    .clk(clk),.rst(rst),.instr(instr),.mem_load_data(mem_load_data),
    .pc(pc),.mem_addr(mem_addr),.mem_write_data(mem_write_data),
    .mem_byte(mem_byte),.mem_read(mem_read),.mem_write(mem_write)
);
mem_16k memory(
    .clk(clk),.write_data(mem_write_data),.i_addr(pc),.d_addr(mem_addr),
    .mem_byte(mem_byte),.mem_read(mem_read),.mem_write(mem_write),
    .i_data(instr),.d_data(mem_load_data),.miss_addr()
);

endmodule
