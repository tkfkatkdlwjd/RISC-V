module tb_core;

logic clk = 0;
logic rst;

top dut(.clk(clk),.rst(rst));
always #5 clk = ~clk;

integer i;
integer cycle = 0;
string  hexfile;
bit     dump, trace;
bit     use_tohost;               // +TOHOST=<hex addr> : 공식 riscv-tests 판정 방식
logic [31:0] tohost_addr;
bit     use_faillog;
logic [31:0] faillog_addr;

task automatic dump_regs();
    if (dump) begin
        for (i = 1; i <= 31; i++)
            $display("x%0d=%b", i, dut.core.register_file.register[i]);
    end
endtask

initial begin
    if (!$value$plusargs("HEX=%s", hexfile)) hexfile = "../programs/prog.hex";
    dump  = $test$plusargs("DUMP");
    trace = $test$plusargs("TRACE");
    use_tohost = $value$plusargs("TOHOST=%h", tohost_addr);
    use_faillog = $value$plusargs("FAILLOG=%h", faillog_addr);

    $readmemh(hexfile, dut.memory_16k.memory);
    rst = 1;
    repeat (3) @(posedge clk);
    rst = 0;
end

always @(posedge clk) if (!rst) cycle++;

// +TRACE: retire 순서대로 PC와 레지스터 쓰기 출력 (단일 사이클과 비교용)
always @(posedge clk) begin
    if (!rst && trace && dut.core.valid_W === 1'b1) begin
        if (dut.core.reg_write_W && dut.core.rd_W != 0)
            $display("[%0d] PC=%h  x%0d <= %h", cycle, dut.core.PC_out_W, dut.core.rd_W, dut.core.reg_write_data);
        else
            $display("[%0d] PC=%h", cycle, dut.core.PC_out_W);
    end
end

always @(posedge clk) begin
    if (!rst && use_faillog && dut.core.mem_write === 1'b1 && dut.core.mem_addr == faillog_addr)
        $display("  fail: case %0d  (check PC=%h)", dut.core.mem_write_data, dut.core.register_file.register[25] - 32'd4);
end

// 공식 env 종료 판정: tohost에 0이 아닌 값 store (1 = PASS, (case<<1)|1 = FAIL)
always @(posedge clk) begin
    if (!rst && use_tohost && dut.core.mem_write === 1'b1 && dut.core.mem_addr == tohost_addr
        && dut.core.mem_write_data != 0) begin
        if (dut.core.mem_write_data == 32'd1)
            $display("PASS (%0d cycles)", cycle);
        else
            $display("FAIL: tohost=%0d (case %0d)", dut.core.mem_write_data, dut.core.mem_write_data >> 1);
        dump_regs();
        $finish;
    end
end

// rv32ui 종료 판정: ecall이 WB에 도달했을 때 gp(x3) 확인 (+TOHOST 없을 때만)
always @(posedge clk) begin
    if (!rst && !use_tohost && dut.core.valid_W === 1'b1 && dut.core.ecall_W) begin
        if (dut.core.register_file.register[3] === 32'd1)
            $display("PASS (%0d cycles)", cycle);
        else
            $display("FAIL: gp=%0d (case %0d)",
                        dut.core.register_file.register[3],
                        dut.core.register_file.register[3] >> 1);
        dump_regs();
        $finish;
    end
end

initial begin
    # 2000000;
    $display("TIMEOUT");
    dump_regs();
    $finish;
end

endmodule
