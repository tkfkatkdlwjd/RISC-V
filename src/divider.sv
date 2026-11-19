module divider(
    input clk, en, rst,
    input [31:0] in1, in2,
    input [1:0] div_op,
    output logic [31:0] result,
    output logic busy, done
);
logic [32:0] T;
logic [31:0] Q, Q0, R, D, D0;
logic [31:0] zero_div, div_out;
logic sign1, sign2, Qin;
logic [1:0] op;

always_comb begin
    zero_div = in1;  div_out = Q;
    if (~div_op[0] & in1[31]) 
         Q0 = ~in1 + 1;
    else Q0 =  in1    ;
    if (~div_op[0] & in2[31])
         D0 = ~in2 + 1;
    else D0 =  in2    ;

    if (T[32] == 0) Qin = 1;
    else            Qin = 0;

    if (in2 == 0) begin
        case (div_op)
            2'b00 : zero_div = 32'hFFFFFFFF;    //-1
            2'b01 : zero_div = 32'hFFFFFFFF;    //2^32-1
            2'b10 : zero_div = in1;
            2'b11 : zero_div = in1;
            default :;
        endcase
    end
    
    case (op)
            2'b00 : begin
                if (sign1^sign2) div_out = ~Q + 1;
                else             div_out =  Q;
            end
            2'b01 : div_out = Q;
            2'b10 : begin
                if (sign1) div_out = ~R[31:0] + 1;
                else       div_out =  R[31:0]; 
            end 
            2'b11 : div_out = R[31:0];
            default :;
    endcase
end

logic [5:0] count;
assign T = {R, Q[31]} - {1'b0, D};    // D는 절댓값(크기)이라 항상 0 확장
always_ff @(posedge clk) begin
    if (rst) begin
        busy <= 0;
        done <= 0;
        count <= 0;
    end
    else begin
        if (!busy && !done && en) begin
            if (in2 == 0) begin
                result <= zero_div;
                busy <= 0;
                done <= 1;
            end
            else begin
                busy <= 1;
                count <= 0;
                sign1 <= ~div_op[0] & in1[31];
                sign2 <= ~div_op[0] & in2[31];
                op    <= div_op;
                Q <= Q0;
                D <= D0;
                R <= '0;
            end
        end
        else if (busy) begin
            count <= count + 1;
            if (T[32] == 0) begin R <= T[31:0];          Q <= {Q[30:0], Qin}; end
            else            begin R <= {R[30:0], Q[31]}; Q <= {Q[30:0], Qin}; end
            if (count == 6'd32) begin
                result <= div_out;
                busy <= 0;
                done <= 1;
            end
        end
        if (done) begin result <= 0; done <= 0; end
    end
end

endmodule
