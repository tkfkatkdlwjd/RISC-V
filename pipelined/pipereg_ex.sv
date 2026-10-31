module pipereg_ex(
    input clk, stall, flush, valid_E,
    input [31:0] funct_out_E, PC_out_E, imm_E, rs2_data_E,
    input [4:0] rd_E,
    input [1:0] Mresult_E, mem_byte_E,
    input reg_write_E, mem_write_E, mem_read_E, sign_ext_E, branch_E, jump_E, jalr_E, lui_E, ecall_E, ebreak_E, unidentified_E,
    input rs1_forward1_E, rs2_forward1_E, mem1_forward1_E, mem2_forward1_E,
    input sw_data_forward1_E, sw_data_forward2_E,

    output logic valid_M,
    output logic [31:0] funct_out_M, PC_out_M, imm_M, rs2_data_M,
    output logic [4:0] rd_M,
    output logic [1:0] Mresult_M, mem_byte_M,
    output logic reg_write_M, mem_write_M, mem_read_M, sign_ext_M, branch_M, jump_M, jalr_M, lui_M, ecall_M, ebreak_M, unidentified_M,
    output logic rs1_forward1_M, rs2_forward1_M, mem1_forward1_M, mem2_forward1_M,
    output logic sw_data_forward1_M, sw_data_forward2_M
);

always_ff @(posedge clk) begin
    if (flush) begin
        valid_M <= 0;
        reg_write_M <= 0;
        mem_write_M <= 0;
        mem_read_M <= 0;
        branch_M <= 0;
        jump_M <= 0;
        jalr_M <= 0;
        lui_M <= 0;
        ecall_M <= 0;
        ebreak_M <= 0;
        unidentified_M <= 0;
        rs1_forward1_M <= 0;
        rs2_forward1_M <= 0;
        mem1_forward1_M <= 0;
        mem2_forward1_M <= 0;
        sw_data_forward1_M <= 0;
        sw_data_forward2_M <= 0;
    end
    else if (!stall) begin
        valid_M <= valid_E;
        funct_out_M <= funct_out_E;
        PC_out_M <= PC_out_E;
        imm_M <= imm_E;
        rs2_data_M <= rs2_data_E;
        rd_M <= rd_E;
        Mresult_M <= Mresult_E;
        mem_byte_M <= mem_byte_E;
        reg_write_M <= reg_write_E;
        mem_write_M <= mem_write_E;
        mem_read_M <= mem_read_E;
        sign_ext_M <= sign_ext_E;
        branch_M <= branch_E;
        jump_M <= jump_E;
        jalr_M <= jalr_E;
        lui_M <= lui_E;
        ecall_M <= ecall_E;
        ebreak_M <= ebreak_E;
        unidentified_M <= unidentified_E;
        rs1_forward1_M <= rs1_forward1_E;
        rs2_forward1_M <= rs2_forward1_E;
        mem1_forward1_M <= mem1_forward1_E;
        mem2_forward1_M <= mem2_forward1_E;
        sw_data_forward1_M <= sw_data_forward1_E;
        sw_data_forward2_M <= sw_data_forward2_E;
    end
end
endmodule
