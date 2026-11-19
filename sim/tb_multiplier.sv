module tb_multiplier;

logic clk, en, rst;
logic [31:0] in1, in2;
logic [1:0] mul_op;
logic [31:0] result;
logic busy, done;

multiplier dut(
    .clk(clk),.en(en),.rst(rst),.in1(in1),.in2(in2),.mul_op(mul_op),
    .result(result),.busy(busy),.done(done));
always #5 clk = ~clk;


task automatic mul_test(input logic [31:0] a, input logic [31:0] b);
    logic [63:0] temp;
    logic [31:0] expected;
    in1 = a;  in2 = b;
    for (int k = 0; k < 4; k++) begin
        integer t = 0;
        rst = 1; #10; rst = 0;
        en = 1;
        mul_op = k;
        #10;
        case (mul_op)
            2'b00 : temp = (a * b);
            2'b01 : temp = ($signed(a) * $signed(b));
            2'b10 : temp = {{32{a[31]}}, a} * {32'b0, b};
            2'b11 : temp = (a * b);
            default :;
        endcase
        if (mul_op == 2'b00) expected = temp[31:0];
        else expected = temp[63:32];

        en = 0;
        while (!done && t <= 30) begin @(posedge clk); t++; end
        
        if (!done) time_err++;
        if (result !== expected) begin
            err++;
            case (mul_op)
                2'b00 : $display("mul    : in1 = %d, in2 = %d , expected = %d, calculated = %d", a, b, expected, result);
                2'b01 : $display("mulh   : in1 = %d, in2 = %d , expected = %d, calculated = %d", $signed(a), $signed(b), $signed(expected), $signed(result));
                2'b10 : $display("mulhsu : in1 = %d, in2 = %d , expected = %d, calculated = %d", $signed(a), b, $signed(expected), $signed(result));
                2'b11 : $display("mulu   : in1 = %d, in2 = %d , expected = %d, calculated = %d", a, b, expected, result);
                default :;
            endcase
        end
    end
endtask

integer i;
integer err, time_err;
logic [31:0] a, b;
initial begin
    clk = 0;
    err = 0;  time_err = 0;
    for (i = 0; i < 10000; i = i + 1) begin
        a = $random;
        b = $random;
        mul_test(a, b);
    end
    mul_test(32'hAAAAAAAA, 32'h55555555);
    mul_test(32'h66666666, 32'h99999999);
    mul_test(32'h0000FFFF, 32'hFFFF0000);
    mul_test(32'hFFFF0000, 32'h0000FFFF);
    mul_test(32'hFFFFFFFF, 32'hFFFFFFFF);
    $display("error : %0d", err);
    $display("timing error : %0d", time_err);
    $finish;
end

endmodule

// run: verilator --binary --timing -Wno-fatal ../src/multiplier.sv tb_multiplier.sv --top-module tb_multiplier && ./obj_dir/Vtb_multiplier
