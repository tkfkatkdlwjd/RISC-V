package rv32i;
localparam logic [6:0] OP_OP     = 7'b0110011;
localparam logic [6:0] OP_OPIMM  = 7'b0010011;
localparam logic [6:0] OP_LOAD   = 7'b0000011;
localparam logic [6:0] OP_STORE  = 7'b0100011;
localparam logic [6:0] OP_BRANCH = 7'b1100011;
localparam logic [6:0] OP_JAL    = 7'b1101111;
localparam logic [6:0] OP_JALR   = 7'b1100111;
localparam logic [6:0] OP_LUI    = 7'b0110111;
localparam logic [6:0] OP_AUIPC  = 7'b0010111;

localparam logic [2:0] R_TYPE = 3'd0, I_TYPE = 3'd1, S_TYPE = 3'd2,
                       B_TYPE = 3'd3, U_TYPE = 3'd4, J_TYPE = 3'd5;

localparam logic SRC_A_RS1 = 1'b0, SRC_A_PC  = 1'b1;        //Ma
localparam logic SRC_B_RS2 = 1'b0, SRC_B_IMM = 1'b1;        //Mb
localparam logic [1:0] WB_ALU = 2'd0, WB_MEM = 2'd1, WB_PC4 = 2'd2, WB_IMM = 2'd3;      //Mresult
localparam logic [1:0] ALUOP_ADD = 2'b00, ALUOP_BR = 2'b01, ALUOP_FUNC = 2'b10;

localparam logic [3:0] ADD = 4'd0, SUB = 4'd1, AND = 4'd2, OR = 4'd3, XOR = 4'd4, SLL = 4'd5,       //funct_op
                       SRL = 4'd6, SRA = 4'd7, LESS = 4'd8, LESSU = 4'd9, LESS_EQL = 4'd10,
                       GRT = 4'd11, GRT_EQL = 4'd12, GRT_EQLU = 4'd13, EQL = 4'd14, NOTEQL = 4'd15;

localparam logic [1:0] BYTE1 = 2'b00, BYTE2 = 2'b01, BYTE4 = 2'b10;         //메모리 접근 바이트
localparam logic ZEXT = 0, SEXT = 1;
endpackage
