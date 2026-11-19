module pipereg_id(
    input clk, stall, flush, valid_D,
    input [31:0] PC_out_D, rs1_data_D, rs2_data_D, imm_D,
    input [4:0] rs1_D, rs2_D, rd_D,
    input [3:0] funct_op_D,
    input [1:0] Mresult_D, mem_byte_D,
    input reg_write_D, mem_write_D, mem_read_D, sign_ext_D, branch_D, jump_D, jalr_D, lui_D,
    input Ma_D, Mb_D, ecall_D, ebreak_D, unidentified_D,
    input sw_data_forward1_D, sw_data_forward2_D,
    input mul_D, div_D,
    input [1:0] mext_funct_D,
    input [31:0] csr_imm_D,
    input [11:0] csr_addr_D,
    input [2:0] csr_op_D,
    input csr_write_D, csr_wen_D, mret_D, jump_misaligned_D, trap_D,

    output logic valid_E,
    output logic [31:0] PC_out_E, rs1_data_E, rs2_data_E, imm_E,
    output logic [4:0] rs1_E, rs2_E, rd_E,
    output logic [3:0] funct_op_E,
    output logic [1:0] Mresult_E, mem_byte_E,
    output logic reg_write_E, mem_write_E, mem_read_E, sign_ext_E, branch_E, jump_E, jalr_E, lui_E,
    output logic Ma_E, Mb_E, ecall_E, ebreak_E, unidentified_E,
    output logic sw_data_forward1_E, sw_data_forward2_E,
    output logic mul_E, div_E,
    output logic [1:0] mext_funct_E,
    output logic [31:0] csr_imm_E,
    output logic [11:0] csr_addr_E,
    output logic [2:0] csr_op_E,
    output logic csr_write_E, csr_wen_E, mret_E, jump_misaligned_E, trap_E
);
always_ff @(posedge clk) begin
    if (flush) begin
        valid_E <= 0;
        reg_write_E <= 0;
        mem_write_E <= 0;
        mem_read_E <= 0;
        branch_E <= 0;
        jump_E <= 0;
        jalr_E <= 0;
        lui_E <= 0;
        ecall_E <= 0;
        ebreak_E <= 0;
        unidentified_E <= 0;
        sw_data_forward1_E <= 0;
        sw_data_forward2_E <= 0;
        mul_E <= 0;
        div_E <= 0;
        csr_write_E <= 0;
        csr_wen_E <= 0;
        jump_misaligned_E <= 0;
        mret_E <= 0;
        trap_E <= 0;
    end
    else if (!stall) begin
        valid_E <= valid_D;
        PC_out_E <= PC_out_D;
        rs1_data_E <= rs1_data_D;
        rs2_data_E <= rs2_data_D;
        imm_E <= imm_D;
        rs1_E <= rs1_D;
        rs2_E <= rs2_D;
        rd_E <= rd_D;
        funct_op_E <= funct_op_D;
        Mresult_E <= Mresult_D;
        reg_write_E <= reg_write_D;
        mem_write_E <= mem_write_D;
        mem_read_E <= mem_read_D;
        mem_byte_E <= mem_byte_D;
        sign_ext_E <= sign_ext_D;
        branch_E <= branch_D;
        jump_E <= jump_D;
        jalr_E <= jalr_D;
        lui_E <= lui_D;
        Ma_E <= Ma_D;
        Mb_E <= Mb_D;
        ecall_E <= ecall_D;
        ebreak_E <= ebreak_D;
        unidentified_E <= unidentified_D;
        sw_data_forward1_E <= sw_data_forward1_D;
        sw_data_forward2_E <= sw_data_forward2_D;
        mul_E <= mul_D;
        div_E <= div_D;
        mext_funct_E <= mext_funct_D;
        csr_imm_E <= csr_imm_D;
        csr_addr_E <= csr_addr_D;
        csr_op_E <= csr_op_D;
        csr_write_E <= csr_write_D;
        csr_wen_E <= csr_wen_D;
        jump_misaligned_E <= jump_misaligned_D;
        mret_E <= mret_D;
        trap_E <= trap_D;
    end
end


endmodule

