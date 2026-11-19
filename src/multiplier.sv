module mul_exe(
    //radix_4_booth
    input clk, en, rst,
    input [34:0] A1, Q1,
    input [34:0] M0,
    output logic [69:0] mul_out,
    output logic busy, done
);
/* 첫 계산은 시행된 채로 mul_in */
logic [34:0] A, Q, sum;
logic [34:0] M;
logic [34:0] opnd;
logic neg;

always_comb begin
    case (Q[2:0])
        3'b001, 3'b010 : begin opnd = M;      neg = 1'b0; end
        3'b011         : begin opnd = M << 1; neg = 1'b0; end
        3'b100         : begin opnd = M << 1; neg = 1'b1; end
        3'b101, 3'b110 : begin opnd = M;      neg = 1'b1; end
        default        : begin opnd = '0;     neg = 1'b0; end
    endcase
    sum = A + (opnd ^ {35{neg}}) + neg;
end

logic [4:0] count; 
always_ff @(posedge clk) begin
    if (rst) begin
            A <= 0;
            Q <= 0;
            busy  <= 0;
            done  <= 0;
            count <= 0;
    end
    else begin
        if (!busy && !done && en) begin
            busy <= 1;
            count <= 1;
            M <= M0;
            {A, Q} <= {A1, Q1}; 
        end
        else if (busy) begin
            count <= count + 1;
            {A, Q} <= $signed({sum, Q}) >>> 2;
            if (count == 5'd16) begin   // 이번 엣지가 17번째 스텝
                busy <= 0;
                done <= 1;
                mul_out <= $signed({sum, Q}) >>> 2;
            end
        end
        if (done) done <= 0;
    end
end

endmodule

module multiplier(
    input clk, en, rst,
    input [31:0] in1, in2,
    input [1:0] mul_op,
    output logic [31:0] result,
    output logic busy, done
);
logic [69:0] mul_out;
logic [34:0] A1, Q1, Q0, M;
logic [34:0] opnd0, first;
logic        neg0;

always_comb begin
    case (mul_op)
        2'b00 : begin M = {3'd0,         in1};  Q0 = {2'd0,         in2, 1'b0}; end
        2'b01 : begin M = {{3{in1[31]}}, in1};  Q0 = {{2{in2[31]}}, in2, 1'b0}; end
        2'b10 : begin M = {{3{in1[31]}}, in1};  Q0 = {2'd0,         in2, 1'b0}; end
        2'b11 : begin M = {3'd0,         in1};  Q0 = {2'd0,         in2, 1'b0}; end
        default :;
    endcase

    case (Q0[2:0])
        3'b001, 3'b010 : begin opnd0 = M;      neg0 = 1'b0; end
        3'b011         : begin opnd0 = M << 1; neg0 = 1'b0; end
        3'b100         : begin opnd0 = M << 1; neg0 = 1'b1; end
        3'b101, 3'b110 : begin opnd0 = M;      neg0 = 1'b1; end
        default        : begin opnd0 = '0;     neg0 = 1'b0; end  // 000, 111
    endcase
    first = (opnd0 ^ {35{neg0}}) + neg0;

    A1 = 35'b0;  Q1 = 35'b0;
    if (en) {A1, Q1} = $signed({first, Q0}) >>> 2;
end

mul_exe mul_execution(
    .clk(clk),.en(en),.rst(rst),
    .A1(A1),.Q1(Q1),.M0(M),
    .mul_out(mul_out),.busy(busy),.done(done)
);

logic [1:0] op;     // 연산 중 mul_op가 바뀌어도 결과 선택이 흔들리지 않게 로드 시 저장
always_ff @(posedge clk) begin
    if (!busy && !done && en) op <= mul_op;     // mul_exe의 로드 조건과 동일
end

always_comb begin
    if (op == 2'b00) result = mul_out[32:1];
    else result = mul_out[64:33];
end

endmodule
