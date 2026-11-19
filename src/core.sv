module pipelined_core(
    input clk, rst,
    input [31:0] instr, mem_load_data,
    output logic [31:0] pc, mem_addr, mem_write_data,
    output logic [1:0] mem_byte,
    output logic mem_read, mem_write
);
import rv32i::*;
logic [31:0] PC_in, funct_in1, funct_in2, reg_write_data;
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
logic mul_D, div_D;
logic [1:0] mext_funct_D;
logic [31:0] csr_imm_D;
logic [11:0] csr_addr_D;
logic [2:0] csr_op_D;
logic csr_write_D, csr_wen_D, mret_D, trap_D;
logic valid_D, ecall_D, ebreak_D, unidentified_D;
logic jump_fire_D, jump_misaligned_D;
logic sw_data_forward1_D, sw_data_forward2_D;

// EX stage
logic [31:0] PC_out_E, rs1_data_E, rs2_data_E, imm_E, funct_out_E;
logic [4:0] rs1_E, rs2_E, rd_E;
logic [3:0] funct_op_E;
logic [1:0] Mresult_E, mem_byte_E;
logic reg_write_E, mem_write_E, mem_read_E, sign_ext_E, 
      branch_E, branch_condition_E, jump_E, jalr_E, lui_E, Ma_E, Mb_E;
logic valid_E, ecall_E, ebreak_E, unidentified_E;
logic mul_E, div_E;
logic [1:0] mext_funct_E;
logic [31:0] alu_out, mul_out, div_out;
logic [31:0] csr_imm_E, csr_operand, csr_write_data, csr_out_E;
logic [11:0] csr_addr_E;
logic [2:0] csr_op_E;
logic csr_write_E, csr_wen_E, mret_E, illegal_E, trap_E, no_count_flag_E;
logic jump_misaligned_E, PC_misaligned_E, mem_misaligned, misaligned_E;
logic [31:0] mepc_E, mcause_E, mtval_E;
logic mul_busy, mul_done, div_busy, div_done;
logic rs1_forward1_E, rs2_forward1_E, mem1_forward1_E, mem2_forward1_E;
logic sw_data_forward1_E, sw_data_forward2_E;

// MEM stage
logic [31:0] funct_out_M, PC_out_M, imm_M, rs2_data_M, mem_load_data_M, next_PC_M;
logic [4:0] rd_M;
logic [1:0] Mresult_M, mem_byte_M;
logic reg_write_M, mem_write_M, mem_read_M, sign_ext_M, branch_M, jump_M, jalr_M, lui_M;
logic valid_M, ecall_M, ebreak_M, unidentified_M;
logic rs1_forward1_M, rs2_forward1_M, mem1_forward1_M, mem2_forward1_M;
logic rs1_forward2_M, rs2_forward2_M, mem1_forward2_M, mem2_forward2_M;
logic sw_data_forward1_M, sw_data_forward2_M;
logic mret_M, illegal_M;
logic misaligned_M, mem_misaligned_M, trap_M, no_count_flag_M;
logic [31:0] mepc_M, mcause_M, mtval_M;

//WB stage
logic [31:0] funct_out_W, PC_out_W, imm_W, mem_load_data_W, next_PC_W;
logic [4:0] rd_W;
logic [1:0] Mresult_W;
logic reg_write_W, branch_W, jump_W, jalr_W, lui_W;
logic valid_W, ecall_W, ebreak_W, unidentified_W;
logic mem1_forward1_W, mem2_forward1_W;
logic rs1_forward2_W, rs2_forward2_W, mem1_forward2_W, mem2_forward2_W;
logic mret_W, illegal_W, trap_W, sc;
logic misaligned_W, no_count_flag_W;
logic [31:0] mepc_W, mcause_W, mtval_W;
logic [31:0] mepc_in, mcause_in, mtval_in, mtvec_out, mepc_out;

PC program_counter(
    .clk(clk),.rst(rst),.stall(stall_if),.PC_in(PC_in),.PC_write(PC_write),
    .PC_out(PC_out_F)
);


always_comb begin : PC_in_choose
    PC_write = 0;
    PC_in = 0;
    if (trap_W) begin 
        PC_write = 1;
        PC_in = mtvec_out;
    end
    else if (valid_W && mret_W) begin
        PC_write = 1;
        PC_in = mepc_out; 
    end
    else if (branch_E && branch_condition_E) begin
        PC_write = 1;
        PC_in = PC_out_E + imm_E;
    end
    else if (jalr_E) begin
        PC_write = 1;
        PC_in = {funct_out_E[31:1], 1'b0};
    end
    else if (jump_fire_D) begin
        PC_write = 1;
        PC_in = PC_out_D + imm_D;
    end
    
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
    .mul(mul_D),.div(div_D),.mext_funct(mext_funct_D),
    .csr_imm(csr_imm_D),.csr_addr(csr_addr_D),.csr_op(csr_op_D),.csr_write(csr_write_D),.csr_wen(csr_wen_D),.mret(mret_D),
    .ecall(ecall_D),.ebreak(ebreak_D),.unidentified(unidentified_D),.trap(trap_D)
);

reg_file register_file (
    .clk(clk),.write_data(reg_write_data),.rs1(rs1_D),.rs2(rs2_D),.rd(rd_W),.reg_write(reg_write_W && !sc),
    .rs1_data(rs1_data_D),.rs2_data(rs2_data_D)
);

pipereg_id id_ex(
    .clk(clk),.stall(stall_ex),.flush(flush_ex),.valid_D(valid_D),
    .PC_out_D(PC_out_D),.rs1_data_D(rs1_data_D),.rs2_data_D(rs2_data_D),.imm_D(imm_D),
    .rs1_D(rs1_D),.rs2_D(rs2_D),.rd_D(rd_D),.funct_op_D(funct_op_D),.Mresult_D(Mresult_D),
    .reg_write_D(reg_write_D),.mem_write_D(mem_write_D),.mem_read_D(mem_read_D),.mem_byte_D(mem_byte_D),
    .sign_ext_D(sign_ext_D),.branch_D(branch_D),.jump_D(jump_D),.jalr_D(jalr_D),.lui_D(lui_D),.Ma_D(Ma_D),.Mb_D(Mb_D),.ecall_D(ecall_D),.ebreak_D(ebreak_D),.unidentified_D(unidentified_D),
    .sw_data_forward1_D(sw_data_forward1_D),.sw_data_forward2_D(sw_data_forward2_D),
    .mul_D(mul_D),.div_D(div_D),.mext_funct_D(mext_funct_D),
    .csr_imm_D(csr_imm_D),.csr_addr_D(csr_addr_D),.csr_op_D(csr_op_D),.csr_write_D(csr_write_D),.csr_wen_D(csr_wen_D),.mret_D(mret_D),.jump_misaligned_D(jump_misaligned_D),.trap_D(trap_D),

    .valid_E(valid_E),.PC_out_E(PC_out_E),.rs1_data_E(rs1_data_E),.rs2_data_E(rs2_data_E),.imm_E(imm_E),
    .rs1_E(rs1_E),.rs2_E(rs2_E),.rd_E(rd_E),.funct_op_E(funct_op_E),.Mresult_E(Mresult_E),
    .reg_write_E(reg_write_E),.mem_write_E(mem_write_E),.mem_read_E(mem_read_E),.mem_byte_E(mem_byte_E),
    .sign_ext_E(sign_ext_E),.branch_E(branch_E),.jump_E(jump_E),.jalr_E(jalr_E),.lui_E(lui_E),.Ma_E(Ma_E),.Mb_E(Mb_E),.ecall_E(ecall_E),.ebreak_E(ebreak_E),.unidentified_E(unidentified_E),
    .sw_data_forward1_E(sw_data_forward1_E),.sw_data_forward2_E(sw_data_forward2_E),
    .mul_E(mul_E),.div_E(div_E),.mext_funct_E(mext_funct_E),
    .csr_imm_E(csr_imm_E),.csr_addr_E(csr_addr_E),.csr_op_E(csr_op_E),.csr_write_E(csr_write_E),.csr_wen_E(csr_wen_E),.mret_E(mret_E),.jump_misaligned_E(jump_misaligned_E),.trap_E(trap_E)
);

logic rs1_hit1, rs2_hit1, rs1_hit2, rs2_hit2;
always_comb begin : stall_operation
    rs1_forward1_E = 0;  rs2_forward1_E = 0;
    rs1_forward2_M = 0;  rs2_forward2_M = 0;
    mem1_forward1_E = 0; mem2_forward1_E = 0;
    mem1_forward2_M = 0; mem2_forward2_M = 0;
    rs1_hit1 = reg_write_E && rd_E != 0 && rs1_D == rd_E;
    rs2_hit1 = reg_write_E && rd_E != 0 && rs2_D == rd_E;
    rs1_hit2 = reg_write_M && rd_M != 0 && rs1_D == rd_M && !rs1_hit1;
    rs2_hit2 = reg_write_M && rd_M != 0 && rs2_D == rd_M && !rs2_hit1;

    stall_if = 0; stall_id = 0; stall_ex = 0; stall_mem = 0; stall_wb = 0;
                  flush_id = 0; flush_ex = 0; flush_mem = 0; flush_wb = 0;

    // data harzard
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

    // control_harzard
    if (jalr_E) begin flush_id = 1; flush_ex = 1; end
    if (branch_E && branch_condition_E) begin 
        flush_id = 1; flush_ex = 1;
    end

    // mul/div stall
    if (!(mul_done || div_done) && (mul_E || div_E)) begin
        stall_if = 1; stall_id = 1; stall_ex = 1; flush_mem = 1;
    end

    // jump: stall 판정 이후에 결정 (stall 중에는 JAL을 D에 유지)
    jump_fire_D = jump_D && valid_D && !stall_id;
    if (jump_fire_D) flush_id = 1;

    // csr stall
    if (csr_write_D && (valid_E || valid_M || valid_W)) begin
        stall_if = 1; stall_id = 1;
        if (!stall_ex) flush_ex = 1;
    end

    // trap
    if (trap_W || (mret_W && valid_W)) begin
        stall_if = 1; flush_id = 1; flush_ex = 1; flush_mem = 1; flush_wb = 1;
    end
    else if (!stall_mem && (trap_M || (mret_M && valid_M))) begin
        stall_if = 1; flush_id = 1; flush_ex = 1; flush_mem = 1;
    end
    else if (!stall_ex && (trap_E || (mret_E && valid_E))) begin
        stall_if = 1; flush_id = 1; flush_ex = 1;
    end

    //reset
    if (rst) begin
        flush_id = 1;
        flush_ex = 1;
        flush_mem = 1;
        flush_wb = 1;
    end
end

always_comb begin : funct_in
    if (mem1_forward1_W || mem1_forward2_W) funct_in1 = reg_write_data;  //load->alu, load->store_addr
    else if (rs1_forward1_M) begin
        funct_in1 = funct_out_M;                 //alu->alu
        if (lui_M) funct_in1 = imm_M;            //lui->alu
    end
    else if (rs1_forward2_W) funct_in1 = reg_write_data;
    else if (Ma_E) funct_in1 = PC_out_E;
    else funct_in1 = rs1_data_E;

    if (mem_write_E) funct_in2 = imm_E;     //store의 funct_in2는 항상 imm
    else if (mem2_forward1_W || mem2_forward2_W) funct_in2 = reg_write_data;
    else if (rs2_forward1_M) begin
        funct_in2 = funct_out_M;                 //alu->alu
        if (lui_M) funct_in2 = imm_M;            //lui->alu
    end
    else if (rs2_forward2_W) funct_in2 = reg_write_data;
    else if (Mb_E) funct_in2 = imm_E;
    else funct_in2 = rs2_data_E;
end


funct_unit alu (
    .in1(funct_in1),.in2(funct_in2),.funct_op(funct_op_E),
    .alu_out(alu_out)
);
multiplier mul_function(
    .clk(clk),.en(mul_E),.rst(rst),.in1(funct_in1),.in2(funct_in2),.mul_op(mext_funct_E),
    .result(mul_out),.busy(mul_busy),.done(mul_done)
);
divider div_function(
    .clk(clk),.en(div_E),.rst(rst),.in1(funct_in1),.in2(funct_in2),.div_op(mext_funct_E),
    .result(div_out),.busy(div_busy),.done(div_done)
);

always_comb begin
    funct_out_E = alu_out;
    if (mul_done) funct_out_E = mul_out;
    if (div_done) funct_out_E = div_out;
    if (csr_write_E) funct_out_E = csr_out_E;
end

always_comb begin
    if (csr_op_E[2]) csr_operand = {27'b0, csr_imm_E};
    else             csr_operand =  funct_in1;

    case (csr_op_E[1:0])
        2'b01 : csr_write_data =  csr_operand;
        2'b10 : csr_write_data =  csr_operand | csr_out_E;
        2'b11 : csr_write_data = ~csr_operand & csr_out_E;
        default : csr_write_data = csr_operand;
    endcase
end

csr_file csr_file(
    .clk(clk),.rst(rst),.csr_write(csr_write_E),
    .wen(csr_wen_E && !(trap_M || sc)),.trap_valid(trap_W),.mret_valid(valid_W && mret_W),.instr_cnt(valid_W && !trap_W && !no_count_flag_W),
    .wdata(csr_write_data),.mepc_in(mepc_in),.mcause_in(mcause_in),.mtval_in(mtval_in),.addr(csr_addr_E),
    .rdata(csr_out_E),.mtvec_out(mtvec_out),.mepc_out(mepc_out),.illegal(illegal_E),.no_count_flag(no_count_flag_E)
);

assign jump_misaligned_D = jump_fire_D && imm_D[1:0];
assign PC_misaligned_E = jump_misaligned_E || ((jalr_E & funct_out_E[1]) || ((branch_E & branch_condition_E) && imm_E[1:0]));
assign mem_misaligned = (mem_byte_E == BYTE2 && funct_out_E[0]) || (mem_byte_E == BYTE4 && funct_out_E[1:0]);
always_comb begin : misaligned
    mepc_E   = PC_out_E;
    mcause_E = 32'd0;
    mtval_E  = 32'd0;
    if (PC_misaligned_E) begin
        mcause_E = 32'd0;
        mtval_E  = jalr_E ? {funct_out_E[31:1], 1'b0} : PC_out_E + imm_E;
    end
    if (mem_read_E && mem_misaligned) begin
        mcause_E = 32'd4;
        mtval_E  = funct_out_E;
    end
    if (mem_write_E && mem_misaligned) begin
        mcause_E = 32'd6;
        mtval_E  = funct_out_E;
    end
end

assign misaligned_E = PC_misaligned_E | mem_misaligned;


assign branch_condition_E = funct_out_E[0];
pipereg_ex ex_mem(
    .clk(clk),.stall(stall_mem),.flush(flush_mem),.valid_E(valid_E),
    .funct_out_E(funct_out_E),.PC_out_E(PC_out_E),.imm_E(imm_E),.rs2_data_E(rs2_data_E),.rd_E(rd_E),.Mresult_E(Mresult_E),.mem_byte_E(mem_byte_E),
    .reg_write_E(reg_write_E),.mem_write_E(mem_write_E),.mem_read_E(mem_read_E),.sign_ext_E(sign_ext_E),
    .branch_E(branch_E),.jump_E(jump_E),.jalr_E(jalr_E),.lui_E(lui_E),.ecall_E(ecall_E),.ebreak_E(ebreak_E),.unidentified_E(unidentified_E),
    .rs1_forward1_E(rs1_forward1_E),.rs2_forward1_E(rs2_forward1_E),.mem1_forward1_E(mem1_forward1_E),.mem2_forward1_E(mem2_forward1_E),
    .sw_data_forward1_E(sw_data_forward1_E),.sw_data_forward2_E(sw_data_forward2_E),
    .mret_E(mret_E),.illegal_E(illegal_E),
    .misaligned_E(misaligned_E),.mem_misaligned_E(mem_misaligned),.trap_E(trap_E),.no_count_flag_E(no_count_flag_E),.mepc_E(mepc_E),.mcause_E(mcause_E),.mtval_E(mtval_E),

    .valid_M(valid_M),.funct_out_M(funct_out_M),.PC_out_M(PC_out_M),.imm_M(imm_M),.rs2_data_M(rs2_data_M),.rd_M(rd_M),.Mresult_M(Mresult_M),.mem_byte_M(mem_byte_M),
    .reg_write_M(reg_write_M),.mem_write_M(mem_write_M),.mem_read_M(mem_read_M),
    .sign_ext_M(sign_ext_M),.branch_M(branch_M),.jump_M(jump_M),.jalr_M(jalr_M),.lui_M(lui_M),.ecall_M(ecall_M),.ebreak_M(ebreak_M),.unidentified_M(unidentified_M),
    .rs1_forward1_M(rs1_forward1_M),.rs2_forward1_M(rs2_forward1_M),.mem1_forward1_M(mem1_forward1_M),.mem2_forward1_M(mem2_forward1_M),
    .sw_data_forward1_M(sw_data_forward1_M),.sw_data_forward2_M(sw_data_forward2_M),
    .mret_M(mret_M),.illegal_M(illegal_M),
    .misaligned_M(misaligned_M),.mem_misaligned_M(mem_misaligned_M),.trap_M(trap_M),.no_count_flag_M(no_count_flag_M),.mepc_M(mepc_M),.mcause_M(mcause_M),.mtval_M(mtval_M)
);

assign next_PC_M = PC_out_M + 4;

assign mem_addr = funct_out_M;
assign mem_byte = mem_byte_M;
assign mem_read = mem_read_M & !mem_misaligned_M;
assign mem_write = mem_write_M & !mem_misaligned_M & !sc;

logic [31:0] write_data_buffer;
always_ff @(posedge clk) begin
    write_data_buffer <= reg_write_data;
end

always_comb begin : memory_harzard
    sw_data_forward1_D = 0; sw_data_forward2_D = 0;
    mem_write_data = rs2_data_M;

    //store data
    if (rs2_hit1 && mem_write_D) sw_data_forward1_D = 1;
    if (rs2_hit2 && mem_write_D) sw_data_forward2_D = 1;
    
    if (sw_data_forward1_M) mem_write_data = reg_write_data;
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
    .funct_out_M(funct_out_M),.PC_out_M(PC_out_M),.next_PC_M(next_PC_M),.imm_M(imm_M),.mem_load_data_M(mem_load_data_M),.rd_M(rd_M),.Mresult_M(Mresult_M),
    .reg_write_M(reg_write_M),.branch_M(branch_M),.jump_M(jump_M),.jalr_M(jalr_M),.lui_M(lui_M),.ecall_M(ecall_M),.ebreak_M(ebreak_M),.unidentified_M(unidentified_M),
    .mem1_forward1_M(mem1_forward1_M),.mem2_forward1_M(mem2_forward1_M),
    .rs1_forward2_M(rs1_forward2_M),.rs2_forward2_M(rs2_forward2_M),.mem1_forward2_M(mem1_forward2_M),.mem2_forward2_M(mem2_forward2_M),
    .mret_M(mret_M),.illegal_M(illegal_M),
    .misaligned_M(misaligned_M),.trap_M(trap_M),.no_count_flag_M(no_count_flag_M),.mepc_M(mepc_M),.mcause_M(mcause_M),.mtval_M(mtval_M),

    .valid_W(valid_W),.funct_out_W(funct_out_W),.PC_out_W(PC_out_W),.next_PC_W(next_PC_W),.imm_W(imm_W),.mem_load_data_W(mem_load_data_W),.rd_W(rd_W),.Mresult_W(Mresult_W),
    .reg_write_W(reg_write_W),.branch_W(branch_W),.jump_W(jump_W),.jalr_W(jalr_W),.lui_W(lui_W),.ecall_W(ecall_W),.ebreak_W(ebreak_W),.unidentified_W(unidentified_W),
    .mem1_forward1_W(mem1_forward1_W),.mem2_forward1_W(mem2_forward1_W),
    .rs1_forward2_W(rs1_forward2_W),.rs2_forward2_W(rs2_forward2_W),.mem1_forward2_W(mem1_forward2_W),.mem2_forward2_W(mem2_forward2_W),
    .mret_W(mret_W),.illegal_W(illegal_W),
    .misaligned_W(misaligned_W),.trap_W(trap_W),.no_count_flag_W(no_count_flag_W),.mepc_W(mepc_W),.mcause_W(mcause_W),.mtval_W(mtval_W)
);

assign sc = trap_W || (valid_W && mret_W);
always_comb begin : csr_in
    mepc_in   = mepc_W;
    mcause_in = mcause_W;
    mtval_in  = mtval_W;

    if (illegal_W || unidentified_W) begin
        mepc_in   = PC_out_W;
        mcause_in = 32'd2;
        mtval_in  = 32'd0;
    end
    if (ecall_W) begin
        mepc_in   = PC_out_W;
        mcause_in = 32'd11;
        mtval_in  = 32'd0;
    end
    if (ebreak_W) begin
        mepc_in   = PC_out_W;
        mcause_in = 32'd3;
        mtval_in  = 32'd0;
    end
end

always_comb begin : MUX_result
    reg_write_data = funct_out_W;
    case (Mresult_W)
        WB_ALU : reg_write_data = funct_out_W;
        WB_IMM : reg_write_data = imm_W;
        WB_MEM : reg_write_data = mem_load_data_W;
        WB_PC4 : reg_write_data = next_PC_W;
        default:;
    endcase
end

endmodule
