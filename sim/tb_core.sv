module tb_core;
    logic clk = 0;
    logic rst;

    top dut(.clk(clk),.rst(rst));
    always #5 clk = ~clk;

    integer i;
    integer cycle = 0;
    string  hexfile;
    bit     dump, trace;

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
                $display("[%0d] PC=%h  x%0d <= %h", cycle, dut.core.PC_out_W, dut.core.rd_W, dut.core.write_data_reg);
            else
                $display("[%0d] PC=%h", cycle, dut.core.PC_out_W);
        end
    end

    // rv32ui 종료 판정: ecall이 WB에 도달했을 때 gp(x3) 확인
    always @(posedge clk) begin
        if (!rst && dut.core.valid_W === 1'b1 && dut.core.ecall_W) begin
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
        # 200000;
        $display("TIMEOUT");
        dump_regs();
        $finish;
    end
endmodule
