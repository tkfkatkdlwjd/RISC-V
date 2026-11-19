module pipelined_core(
    input clk, rst,
    input [31:0] instr, mem_load_data,
    output logic [31:0] pc, mem_addr, mem_write_data,
    output logic [1:0] mem_byte,
    output logic mem_read, mem_write
);
import rv32i::*;
logic [31:0] PC_in, funct_in1, funct_in2, write_data_reg;
logic PC_write;
logic stall_if, stall_id, stall_ex, stall_mem, stall_wb;
logic flush_id, flush_ex, flush_mem, flush_wb;

//IF stage
logic [31:0] instr_F, PC_out_F;
assign instr_F = instr;
assign pc = PC_out_F;

// ID stage
logic [31:0] instr_D, PC_out_D, rs1_data_D, rs2_data_D, imm_D;
logic [4:0] rs1_D, rs2_D, rd_D;
logic [3:0] funct_op_D;
logic [1:0] Mresult_D, mem_byte_D;
logic reg_write_D, mem_write_D, mem_read_D, sign_ext_D, branch_D, jump_D, jalr_D, lui_D;
logic Ma_D, Mb_D;
logic valid_D, ecall_D, ebreak_D, unidentified_D;
logic sw_data_forward1_D, sw_data_forward2_D;

// EX stage
logic [31:0] PC_out_E, rs1_data_E, rs2_data_E, imm_E, funct_out_E;
logic [4:0] rs1_E, rs2_E, rd_E;
logic [3:0] funct_op_E;
logic [1:0] Mresult_E, mem_byte_E;
logic reg_write_E, mem_write_E, mem_read_E, sign_ext_E, 
      branch_E, branch_condition_E, jump_E, jalr_E, lui_E, Ma_E, Mb_E;
logic valid_E, ecall_E, ebreak_E, unidentified_E;
logic rs1_forward1_E, rs2_forward1_E, mem1_forward1_E, mem2_forward1_E;
logic sw_data_forward1_E, sw_data_forward2_E;

// MEM stage
logic [31:0] funct_out_M, PC_out_M, imm_M, rs2_data_M, mem_load_data_M;
logic [4:0] rd_M;
logic [1:0] Mresult_M, mem_byte_M;
logic reg_write_M, mem_write_M, mem_read_M, sign_ext_M, branch_M, jump_M, jalr_M, lui_M;
logic valid_M, ecall_M, ebreak_M, unidentified_M;
logic rs1_forward1_M, rs2_forward1_M, mem1_forward1_M, mem2_forward1_M;
logic rs1_forward2_M, rs2_forward2_M, mem1_forward2_M, mem2_forward2_M;
logic sw_data_forward1_M, sw_data_forward2_M;

//WB stage
logic [31:0] funct_out_W, PC_out_W, imm_W, mem_load_data_W;
logic [4:0] rd_W;
logic [1:0] Mresult_W;
logic reg_write_W, branch_W, jump_W, jalr_W, lui_W;
logic valid_W, ecall_W, ebreak_W, unidentified_W;
logic mem1_forward1_W, mem2_forward1_W;
logic rs1_forward2_W, rs2_forward2_W, mem1_forward2_W, mem2_forward2_W;

PC program_counter(
    .clk(clk),.rst(rst),.stall(stall_if),.PC_in(PC_in),.PC_write(PC_write),
    .PC_out(PC_out_F)
);


always_comb begin : PC_in_choose
    PC_write = 0;
    PC_in = 0;
    if (branch_E && branch_condition_E) begin PC_write = 1;  PC_in = PC_out_E + imm_E; end
    else if (jump_D) begin PC_write = 1;  PC_in = PC_out_D + imm_D; end
    if (jalr_E) begin PC_write = 1;  PC_in = {funct_out_E[31:1], 1'b0}; end
end

pipereg_if if_id(
    .clk(clk),.stall(stall_id),.flush(flush_id),.instr_F(instr_F),.PC_out_F(PC_out_F),
    .valid_D(valid_D),.instr_D(instr_D),.PC_out_D(PC_out_D)
);

instr_decoder decoder(
    .instr(instr_D),
    .rs1(rs1_D),.rs2(rs2_D),.rd(rd_D),.funct_op(funct_op_D),.imm(imm_D),.Mresult(Mresult_D),.Ma(Ma_D),.Mb(Mb_D),
    .reg_write(reg_write_D),.mem_write(mem_write_D),.mem_read(mem_read_D),.mem_byte(mem_byte_D),.sign_ext(sign_ext_D),
    .branch(branch_D),.jump(jump_D),.jalr(jalr_D),.lui(lui_D),
    .ecall(ecall_D),.ebreak(ebreak_D),.unidentified(unidentified_D)
);

reg_file register_file (
    .clk(clk),.write_data(write_data_reg),.rs1(rs1_D),.rs2(rs2_D),.rd(rd_W),.reg_write(reg_write_W),
    .rs1_data(rs1_data_D),.rs2_data(rs2_data_D)
);

pipereg_id id_ex(
    .clk(clk),.stall(stall_ex),.flush(flush_ex),.valid_D(valid_D),
    .PC_out_D(PC_out_D),.rs1_data_D(rs1_data_D),.rs2_data_D(rs2_data_D),.imm_D(imm_D),
    .rs1_D(rs1_D),.rs2_D(rs2_D),.rd_D(rd_D),.funct_op_D(funct_op_D),.Mresult_D(Mresult_D),
    .reg_write_D(reg_write_D),.mem_write_D(mem_write_D),.mem_read_D(mem_read_D),.mem_byte_D(mem_byte_D),
    .sign_ext_D(sign_ext_D),.branch_D(branch_D),.jump_D(jump_D),.jalr_D(jalr_D),.lui_D(lui_D),.Ma_D(Ma_D),.Mb_D(Mb_D),.ecall_D(ecall_D),.ebreak_D(ebreak_D),.unidentified_D(unidentified_D),
    .sw_data_forward1_D(sw_data_forward1_D),.sw_data_forward2_D(sw_data_forward2_D),

    .valid_E(valid_E),.PC_out_E(PC_out_E),.rs1_data_E(rs1_data_E),.rs2_data_E(rs2_data_E),.imm_E(imm_E),
    .rs1_E(rs1_E),.rs2_E(rs2_E),.rd_E(rd_E),.funct_op_E(funct_op_E),.Mresult_E(Mresult_E),
    .reg_write_E(reg_write_E),.mem_write_E(mem_write_E),.mem_read_E(mem_read_E),.mem_byte_E(mem_byte_E),
    .sign_ext_E(sign_ext_E),.branch_E(branch_E),.jump_E(jump_E),.jalr_E(jalr_E),.lui_E(lui_E),.Ma_E(Ma_E),.Mb_E(Mb_E),.ecall_E(ecall_E),.ebreak_E(ebreak_E),.unidentified_E(unidentified_E),
    .sw_data_forward1_E(sw_data_forward1_E),.sw_data_forward2_E(sw_data_forward2_E)
);

logic rs1_hit1, rs2_hit1, rs1_hit2, rs2_hit2;
logic branch_accepted;
always_comb begin : harzard
    rs1_forward1_E = 0;  rs2_forward1_E = 0;
    rs1_forward2_M = 0;  rs2_forward2_M = 0;
    mem1_forward1_E = 0; mem2_forward1_E = 0;
    mem1_forward2_M = 0; mem2_forward2_M = 0;
    rs1_hit1 = reg_write_E && rd_E != 0 && rs1_D == rd_E;
    rs2_hit1 = reg_write_E && rd_E != 0 && rs2_D == rd_E;
    rs1_hit2 = reg_write_M && rd_M != 0 && rs1_D == rd_M && !rs1_hit1;
    rs2_hit2 = reg_write_M && rd_M != 0 && rs2_D == rd_M && !rs2_hit1;

    branch_accepted = 0;

    stall_if = 0; stall_id = 0; stall_ex = 0; stall_mem = 0; stall_wb = 0;
                  flush_id = 0; flush_ex = 0; flush_mem = 0; flush_wb = 0;

    //reset
    if (rst) begin
        flush_id = 1;
        flush_ex = 1;
        flush_mem = 1;
        flush_wb = 1;
    end

    //data harzard
    if (rs1_hit1 || rs2_hit1) begin
        if (mem_read_E) begin
            mem1_forward1_E = rs1_hit1;     //load의 rd가 사용
            mem2_forward1_E = rs2_hit1;
            stall_if = 1; stall_id = 1; flush_ex = 1;
        end
        else begin
            rs1_forward1_E = rs1_hit1;
            rs2_forward1_E = rs2_hit1;
        end
    end
    if (rs1_hit2 || rs2_hit2) begin
        if (mem_read_M) begin
            mem1_forward2_M = rs1_hit2;
            mem2_forward2_M = rs2_hit2;
        end
        else begin
            rs1_forward2_M = rs1_hit2;
            rs2_forward2_M = rs2_hit2;
        end
    end

    //control_harzard
    if (jump_D)       flush_id = 1;
    if (jalr_E) begin flush_id = 1; flush_ex = 1; end
    if (branch_E && branch_condition_E) begin 
        flush_id = 1; flush_ex = 1;
    end
end

always_comb begin : funct_in
    if (mem1_forward1_W || mem1_forward2_W) funct_in1 = write_data_reg;  //load->alu, load->store_addr
    else if (rs1_forward1_M) begin
        if (lui_M) funct_in1 = imm_M;   //lui->alu
        else funct_in1 = funct_out_M;   //alu->alu
    end
    else if (rs1_forward2_W) funct_in1 = write_data_reg;
    else if (Ma_E) funct_in1 = PC_out_E;
    else funct_in1 = rs1_data_E;

    if (mem_write_E) funct_in2 = imm_E;     //store의 funct_in2는 항상 imm
    else if (mem2_forward1_W || mem2_forward2_W) funct_in2 = write_data_reg;
    else if (rs2_forward1_M) begin
        if (lui_M) funct_in2 = imm_M;
        else funct_in2 = funct_out_M;
    end
    else if (rs2_forward2_W) funct_in2 = write_data_reg;
    else if (Mb_E) funct_in2 = imm_E;
    else funct_in2 = rs2_data_E;
end


funct_unit function_unit (
    .in1(funct_in1),.in2(funct_in2),.funct_op(funct_op_E),
    .funct_out(funct_out_E)
);

assign branch_condition_E = funct_out_E[0];

pipereg_ex ex_mem(
    .clk(clk),.stall(stall_mem),.flush(flush_mem),.valid_E(valid_E),
    .funct_out_E(funct_out_E),.PC_out_E(PC_out_E),.imm_E(imm_E),.rs2_data_E(rs2_data_E),.rd_E(rd_E),.Mresult_E(Mresult_E),.mem_byte_E(mem_byte_E),
    .reg_write_E(reg_write_E),.mem_write_E(mem_write_E),.mem_read_E(mem_read_E),.sign_ext_E(sign_ext_E),
    .branch_E(branch_E),.jump_E(jump_E),.jalr_E(jalr_E),.lui_E(lui_E),.ecall_E(ecall_E),.ebreak_E(ebreak_E),.unidentified_E(unidentified_E),
    .rs1_forward1_E(rs1_forward1_E),.rs2_forward1_E(rs2_forward1_E),.mem1_forward1_E(mem1_forward1_E),.mem2_forward1_E(mem2_forward1_E),
    .sw_data_forward1_E(sw_data_forward1_E),.sw_data_forward2_E(sw_data_forward2_E),

    .valid_M(valid_M),.funct_out_M(funct_out_M),.PC_out_M(PC_out_M),.imm_M(imm_M),.rs2_data_M(rs2_data_M),.rd_M(rd_M),.Mresult_M(Mresult_M),.mem_byte_M(mem_byte_M),
    .reg_write_M(reg_write_M),.mem_write_M(mem_write_M),.mem_read_M(mem_read_M),
    .sign_ext_M(sign_ext_M),.branch_M(branch_M),.jump_M(jump_M),.jalr_M(jalr_M),.lui_M(lui_M),.ecall_M(ecall_M),.ebreak_M(ebreak_M),.unidentified_M(unidentified_M),
    .rs1_forward1_M(rs1_forward1_M),.rs2_forward1_M(rs2_forward1_M),.mem1_forward1_M(mem1_forward1_M),.mem2_forward1_M(mem2_forward1_M),
    .sw_data_forward1_M(sw_data_forward1_M),.sw_data_forward2_M(sw_data_forward2_M)
);

assign mem_addr = funct_out_M;
assign mem_byte = mem_byte_M;
assign mem_read = mem_read_M;
assign mem_write = mem_write_M;

logic [31:0] write_data_buffer;
always_ff @(posedge clk) begin
    write_data_buffer <= write_data_reg;
end

always_comb begin : memory_harzard
    sw_data_forward1_D = 0; sw_data_forward2_D = 0;
    mem_write_data = rs2_data_M;

    //store data
    if (rs2_hit1 && mem_write_D) sw_data_forward1_D = 1;
    if (rs2_hit2 && mem_write_D) sw_data_forward2_D = 1;
    
    if (sw_data_forward1_M) mem_write_data = write_data_reg;
    if (sw_data_forward2_M) mem_write_data = write_data_buffer;
end

always_comb begin : mem_read_byte
    case (mem_byte_M)
        BYTE1 : mem_load_data_M = sign_ext_M ? {{24{mem_load_data[7]}}, mem_load_data[7:0]} : {24'b0, mem_load_data[7:0]};
        BYTE2 : mem_load_data_M = sign_ext_M ? {{16{mem_load_data[15]}}, mem_load_data[15:0]} : {16'b0, mem_load_data[15:0]};
        BYTE4 : mem_load_data_M = mem_load_data;
        default : mem_load_data_M = mem_load_data;
    endcase
end


pipereg_mem mem_wb(
    .clk(clk),.stall(stall_wb),.flush(flush_wb),.valid_M(valid_M),
    .funct_out_M(funct_out_M),.PC_out_M(PC_out_M),.imm_M(imm_M),.mem_load_data_M(mem_load_data_M),.rd_M(rd_M),.Mresult_M(Mresult_M),
    .reg_write_M(reg_write_M),.branch_M(branch_M),.jump_M(jump_M),.jalr_M(jalr_M),.lui_M(lui_M),.ecall_M(ecall_M),.ebreak_M(ebreak_M),.unidentified_M(unidentified_M),
    .mem1_forward1_M(mem1_forward1_M),.mem2_forward1_M(mem2_forward1_M),
    .rs1_forward2_M(rs1_forward2_M),.rs2_forward2_M(rs2_forward2_M),.mem1_forward2_M(mem1_forward2_M),.mem2_forward2_M(mem2_forward2_M),

    .valid_W(valid_W),.funct_out_W(funct_out_W),.PC_out_W(PC_out_W),.imm_W(imm_W),.mem_load_data_W(mem_load_data_W),.rd_W(rd_W),.Mresult_W(Mresult_W),
    .reg_write_W(reg_write_W),.branch_W(branch_W),.jump_W(jump_W),.jalr_W(jalr_W),.lui_W(lui_W),.ecall_W(ecall_W),.ebreak_W(ebreak_W),.unidentified_W(unidentified_W),
    .mem1_forward1_W(mem1_forward1_W),.mem2_forward1_W(mem2_forward1_W),
    .rs1_forward2_W(rs1_forward2_W),.rs2_forward2_W(rs2_forward2_W),.mem1_forward2_W(mem1_forward2_W),.mem2_forward2_W(mem2_forward2_W)
);
/*
always_comb begin
    if (ecall_W) begin
        mepc_in = PC_out_W;
        mcause_in = 32'd11;
        mtval_in = 0;
    end
    if (ebreak_W) begin
        mepc_in = PC_out_W;
        mcause_in = 32'd3;
        mtval_in = 0;
    end
end
*/
always_comb begin : MUX_result
    write_data_reg = funct_out_W;
    case (Mresult_W)
        WB_ALU : write_data_reg = funct_out_W;
        WB_IMM : write_data_reg = imm_W;
        WB_MEM : write_data_reg = mem_load_data_W;
        WB_PC4 : write_data_reg = PC_out_W + 4;
        default:;
    endcase
end

endmodule


//꼭 mem 단계에서 메모리에 접근해야할까?