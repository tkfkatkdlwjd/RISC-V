module tb_divider;

logic clk, en, rst;
logic [31:0] in1, in2;
logic [1:0] div_op;
logic [31:0] result;
logic busy, done;

divider dut(
    .clk(clk),.en(en),.rst(rst),.in1(in1),.in2(in2),.div_op(div_op),
    .result(result),.busy(busy),.done(done)
);
always #5 clk = ~clk;

task automatic div_test(input logic [31:0] a, input logic [31:0] b);
    logic [31:0] expected;
    in1 = a;  in2 = b;
    for (int k = 0; k < 4; k++) begin
        integer t = 0;
        rst = 1; #10; rst = 0;
        en = 1;
        div_op = k;
        #10;
        if (b == 0) begin
            case (div_op)
                2'b00 : expected = 32'hFFFFFFFF;
                2'b01 : expected = 32'hFFFFFFFF;
                2'b10 : expected = a;
                2'b11 : expected = a;
                default :;
            endcase
        end
        else if (a == 32'h80000000 && b == 32'hFFFFFFFF && !div_op[0]) begin
            // signed 오버플로(-2^31 / -1): SV의 /, %로는 정의되지 않으므로 스펙 값을 직접 지정
            if (div_op[1]) expected = 32'h0;            // REM
            else           expected = 32'h80000000;     // DIV
        end
        else begin
            case (div_op)
                2'b00 : expected = $signed(a) / $signed(b);
                2'b01 : expected = a / b;
                2'b10 : expected = $signed(a) % $signed(b);
                2'b11 : expected = a % b;
                default :;
            endcase
        end

        en = 0;
        while (!done && t <= 50) begin @(posedge clk); t++; end
        
        if (!done) time_err++;
        if (result !== expected) begin
            err++;
            case (div_op)
                2'b00 : $display("div  : in1 = %d, in2 = %d , expected = %d, calculated = %d", $signed(a), $signed(b), $signed(expected), $signed(result));
                2'b01 : $display("divu : in1 = %d, in2 = %d , expected = %d, calculated = %d", a, b, expected, result);
                2'b10 : $display("rem  : in1 = %d, in2 = %d , expected = %d, calculated = %d", $signed(a), $signed(b), $signed(expected), $signed(result));
                2'b11 : $display("remu : in1 = %d, in2 = %d , expected = %d, calculated = %d", a, b, expected, result);
                default :;
            endcase
        end
        
    end
endtask

integer i, j;
integer err, time_err;
logic [31:0] a, b, c;
initial begin
    clk = 0;
    err = 0;  time_err = 0;
    for (i = 0; i < 10000; i = i + 1) begin
        a = $random;
        b = $random;
        div_test(a, b);
    end
    for (j = 0; j < 100; j = j + 1) begin
        c = $random;
        div_test(c, 32'd0);
    end
    div_test(32'h0000FFFF, 32'hFFFF0000);
    div_test(32'hFFFF0000, 32'h0000FFFF);
    div_test(32'hFFFFFFFF, 32'hFFFFFFFF);
    div_test(32'h00000000, 32'h00000000);
    div_test(32'h80000000, 32'hFFFFFFFF);

    // 경계값
    div_test(32'h80000000, 32'h00000000);   // 음수 / 0
    div_test(32'h00000000, 32'h80000000);   // 0 / -2^31 (제수 절댓값 MSB=1)
    div_test(32'h80000000, 32'h80000000);   // -2^31 / -2^31
    div_test(32'h7FFFFFFF, 32'h80000000);   // 최대 양수 / 최소 음수
    div_test(32'h80000000, 32'h00000001);   // -2^31 / 1
    div_test(32'h7FFFFFFF, 32'hFFFFFFFF);   // 최대 양수 / -1
    div_test(32'hFFFFFFFF, 32'h80000000);   // unsigned 큰 제수
    div_test(32'hFFFFFFFF, 32'hC0000000);   // unsigned 큰 제수
    div_test(32'h00000006, 32'h00000003);   // 나누어떨어짐

    $display("error : %0d", err);
    $display("timing error : %0d", time_err);
    $finish;
end

endmodule

// run: verilator --binary --timing -Wno-fatal ../src/divider.sv tb_divider.sv --top-module tb_divider && ./obj_dir/Vtb_divider
