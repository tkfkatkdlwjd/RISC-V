module tb_cpu;
    logic clk = 0;
    logic rst;
    always #5 clk = ~clk;

    top dut (.clk(clk), .rst(rst));

    integer i;
    string  hexfile;
    bit     dump;

    initial begin
        if (!$value$plusargs("HEX=%s", hexfile)) hexfile = "../programs/prog.hex";
        dump = $test$plusargs("DUMP");

        $readmemh(hexfile, dut.memory.memory);
        rst = 1;
        repeat (3) @(posedge clk);
        rst = 0;
    end

    // rv32ui 종료 판정: ecall 시점에 gp(x3) 확인
    always @(posedge clk) begin
        if (!rst && dut.core.ecall) begin
            if (dut.core.register_file.register[3] === 32'd1)
                $display("PASS");
            else
                $display("FAIL: gp=%0d (case %0d)",
                         dut.core.register_file.register[3],
                         dut.core.register_file.register[3] >> 1);

            if (dump) begin
                for (i = 0; i <= 31; i++)
                    $display("x%0d=%h", i, dut.core.register_file.register[i]);
            end
            $finish;
        end
    end

    initial begin
        # 200000;
        $display("TIMEOUT");
        if (dump) begin
            for (i = 0; i <= 31; i++)
                $display("x%0d=%h", i, dut.core.register_file.register[i]);
        end
        $finish;
    end
endmodule