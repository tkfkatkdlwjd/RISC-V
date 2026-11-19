module single_cycle_core (
    input clk, rst,
    input [31:0] instr, mem_load_data,
    output logic [31:0] pc, mem_addr, mem_write_data,
    output logic [1:0] mem_byte,
    output logic mem_read, mem_write
);
import rv32i::*;

logic [31:0] PC_in, PC_out, funct_in1, funct_in2, funct_out, rs1, rs2,
             imm, write_data_reg, write_data_mem;
logic [4:0] aa, ba, da;
logic [3:0] funct_op;
logic [2:0] type_sel;
logic [1:0] Mresult;
logic PC_write, Ma, Mb, reg_write, ecall, ebreak, branch, jump, jalr,
      sign_ext, unidentified;
logic branch_condition;
assign branch_condition = funct_out[0];
assign mem_addr = funct_out;
assign mem_write_data = rs2;

PC program_counter(
    .clk(clk),.rst(rst),.PC_in(PC_in),.PC_write(PC_write),
    .PC_out(PC_out)
);
assign pc = PC_out;

instr_decoder main_decoder(
    .instr(instr),
    .aa(aa),.ba(ba),.da(da),.funct_op(funct_op),.type_sel(type_sel),.Mresult(Mresult),.Ma(Ma),.Mb(Mb),
    .reg_write(reg_write),.mem_write(mem_write),.mem_read(mem_read),.mem_byte(mem_byte),.sign_ext(sign_ext),
    .branch(branch),.jump(jump),.jalr(jalr),.unidentified(unidentified)
);

imm_maker immediate_maker(
    .instr(instr),.type_sel(type_sel),
    .imm(imm),.ecall(ecall),.ebreak(ebreak)
);

reg_file register_file (
    .clk(clk),.write_data(write_data_reg),.aa(aa),.ba(ba),.da(da),.reg_write(reg_write),
    .rs1(rs1),.rs2(rs2)
);

funct_unit function_unit (
    .in1(funct_in1),.in2(funct_in2),.funct_op(funct_op),
    .funct_out(funct_out)
);

always_comb begin : PC_in_choose
    PC_write = 0;
    PC_in = '0;
    if (branch && branch_condition) begin
                    PC_write = 1;  PC_in = PC_out + imm;            end
    if (jump) begin PC_write = 1;  PC_in = funct_out;               end
    if (jalr) begin PC_write = 1;  PC_in = {funct_out[31:1], 1'b0}; end
end

always_comb begin : MUXa_MUXb
    if (Ma) funct_in1 = PC_out;
    else funct_in1 = rs1;
    if (Mb) funct_in2 = imm;
    else funct_in2 = rs2;
end

always_comb begin : MUX_result
    write_data_reg = funct_out;
    case (Mresult)
        WB_ALU : write_data_reg = funct_out;
        WB_IMM : write_data_reg = imm;
        WB_MEM : begin
        case (mem_byte)
            BYTE1 : write_data_reg = sign_ext ? {{24{mem_load_data[7]}}, mem_load_data[7:0]} : {24'd0, mem_load_data[7:0]};
            BYTE2 : write_data_reg = sign_ext ? {{16{mem_load_data[15]}}, mem_load_data[15:0]} : {16'd0, mem_load_data[15:0]};
            BYTE4 : write_data_reg = mem_load_data;
            default : write_data_reg = mem_load_data;
        endcase
        end
        WB_PC4 : write_data_reg = PC_out + 4;
        default:;
    endcase
end
endmodule
