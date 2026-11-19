module tb_function_unit;

import rv32i::*;
logic [31:0] in1, in2;
logic [3:0] funct_op;
logic [31:0] funct_out;
logic [31:0] expected;

funct_unit dut(
    .in1(in1),.in2(in2),.funct_op(funct_op),
    .funct_out(funct_out)
);

integer err = 0;
task automatic check_all_ops(input logic [31:0] a, input logic [31:0] b);
    in1 = a;
    in2 = b;
    for (int k = 0; k < 16; k++) begin
        funct_op = k;
        #10;
        case (funct_op)
            ADD : expected = in1 + in2;
            SUB : expected = in1 - in2;
            AND : expected = in1 & in2;
            OR : expected = in1 | in2;
            XOR : expected = in1 ^ in2;
            SLL : expected = in1 << in2[4:0];
            SRL : expected = in1 >> in2[4:0];
            SRA : expected = $signed(in1) >>> in2[4:0];
            LESS : expected = ($signed(in1) < $signed(in2));
            LESSU : expected = (in1 < in2);
            LESS_EQL : expected = ($signed(in1) <= $signed(in2));
            GRT : expected = ($signed(in1) > $signed(in2));
            GRT_EQL : expected = ($signed(in1) >= $signed(in2));
            GRT_EQLU : expected = (in1 >= in2);
            EQL : expected = (in1 == in2);
            NOTEQL : expected = (in1 != in2);
            default : begin
                expected = 0;
                $display("unidentified operation");
            end
        endcase
        if (funct_out !== expected) begin
            err = err + 1;
            $display("in1 : %d, in2 : %d, op : %b, expected : %d, result : %d",
                      in1, in2, funct_op, expected, funct_out);
        end
    end
endtask

integer i;
initial begin
    in1 = 0; in2 = 0; funct_op = 0;
    #10;
    
    check_all_ops(32'h00000000, 32'h00000000);  // 0, 같음
    check_all_ops(32'h7FFFFFFF, 32'h00000001);  // ADD 부호 오버플로
    check_all_ops(32'hFFFFFFFF, 32'h00000001);  // ADD 캐리, 부호 있음/없음 비교
    check_all_ops(32'h00000000, 32'h00000001);  // SUB 언더플로
    check_all_ops(32'h80000000, 32'h7FFFFFFF);  // signed/unsigned 비교 반전
    check_all_ops(32'h7FFFFFFF, 32'h80000000);  // 위의 반대 순서
    check_all_ops(32'h80000000, 32'h80000000);  // 같음 + MSB 1
    check_all_ops(32'h80000000, 32'h0000001F);  // SRA/SRL 시프트 31
    check_all_ops(32'h80000000, 32'h00000020);  // 시프트량 상위 비트 무시 (32 → 0)
    check_all_ops(32'hAAAAAAAA, 32'h55555555);  // 비트 반대
    check_all_ops(32'h00000005, 32'h00000006);  // 한 칸 차이: <
    check_all_ops(32'h00000006, 32'h00000006);  // ==
    check_all_ops(32'h00000007, 32'h00000006);  // >

    for (i = 0; i < 1000; i = i + 1) begin
        in1 = $random;
        in2 = $random;
        check_all_ops(in1, in2);
    end
    $display("error : %d", err);
    $finish;
end
endmodule
