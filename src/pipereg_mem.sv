module pipereg_mem(
    input clk, stall, flush, valid_M,
    input [31:0] funct_out_M, PC_out_M, next_PC_M, imm_M, mem_load_data_M,
    input [4:0] rd_M,
    input [1:0] Mresult_M,
    input reg_write_M, branch_M, jump_M, jalr_M, lui_M, ecall_M, ebreak_M, unidentified_M,
    input mem1_forward1_M, mem2_forward1_M,
    input rs1_forward2_M, rs2_forward2_M, mem1_forward2_M, mem2_forward2_M,
    input mret_M, illegal_M,
    input misaligned_M, trap_M, no_count_flag_M,
    input [31:0] mepc_M, mcause_M, mtval_M,
    
    output logic valid_W,
    output logic [31:0] funct_out_W, PC_out_W, next_PC_W, imm_W, mem_load_data_W,
    output logic [4:0] rd_W,
    output logic [1:0] Mresult_W,
    output logic reg_write_W, branch_W, jump_W, jalr_W, lui_W, ecall_W, ebreak_W, unidentified_W,
    (* max_fanout = 16 *) output logic mem1_forward1_W,
    (* max_fanout = 16 *) output logic mem2_forward1_W,
    (* max_fanout = 16 *) output logic rs1_forward2_W,
    (* max_fanout = 16 *) output logic rs2_forward2_W,
    (* max_fanout = 16 *) output logic mem1_forward2_W,
    (* max_fanout = 16 *) output logic mem2_forward2_W,
    output logic mret_W, illegal_W,
    output logic misaligned_W, trap_W, no_count_flag_W,
    output logic [31:0] mepc_W, mcause_W, mtval_W
);

always_ff @(posedge clk) begin
    if (flush) begin
        valid_W <= 0;
        reg_write_W <= 0;
        branch_W <= 0;
        jump_W <= 0;
        jalr_W <= 0;
        lui_W <= 0;
        ecall_W <= 0;
        ebreak_W <= 0;
        unidentified_W <= 0;
        mem1_forward1_W <= 0;
        mem2_forward1_W <= 0;
        rs1_forward2_W <= 0;
        rs2_forward2_W <= 0;
        mem1_forward2_W <= 0;
        mem2_forward2_W <= 0;
        mret_W <= 0;
        illegal_W <= 0;
        misaligned_W <= 0;
        trap_W <= 0;
        no_count_flag_W <= 0;
    end
    else if (!stall) begin
        valid_W <= valid_M;
        funct_out_W <= funct_out_M;
        PC_out_W <= PC_out_M;
        next_PC_W <= next_PC_M;
        imm_W <= imm_M;
        mem_load_data_W <= mem_load_data_M;
        rd_W <= rd_M;
        Mresult_W <= Mresult_M;
        reg_write_W <= reg_write_M;
        branch_W <= branch_M;
        jump_W <= jump_M;
        jalr_W <= jalr_M;
        lui_W <= lui_M;
        ecall_W <= ecall_M;
        ebreak_W <= ebreak_M;
        unidentified_W <= unidentified_M;
        mem1_forward1_W <= mem1_forward1_M;
        mem2_forward1_W <= mem2_forward1_M;
        rs1_forward2_W <= rs1_forward2_M;
        rs2_forward2_W <= rs2_forward2_M;
        mem1_forward2_W <= mem1_forward2_M;
        mem2_forward2_W <= mem2_forward2_M;
        mret_W <= mret_M;
        illegal_W <= illegal_M;
        misaligned_W <= misaligned_M;
        trap_W <= trap_M;
        no_count_flag_W <= no_count_flag_M;
        mepc_W <= mepc_M;
        mcause_W <= mcause_M;
        mtval_W <= mtval_M;
    end
end
endmodule
