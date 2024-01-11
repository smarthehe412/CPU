// RISCV32I CPU top module
// port modification allowed for debugging purposes
`include "ALU.v"
`include "cons.v"
`include "decoder.v"
`include "ifetch.v"
`include "LSB.v"
`include "memctrl.v"
`include "regfile.v"
`include "ROB.v"
`include "RS.v"

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

//broadcast wires
wire rollback;
wire rs_full;
wire rob_full;
wire lsb_full;

wire                alu_result;
wire [`ROB_POS_WID] alu_result_rob_pos;
wire [`DATA_WID]    alu_result_val;
wire                alu_result_jump;
wire [   `ADDR_WID] alu_result_pc;

wire                lsb_result;
wire [`ROB_POS_WID] lsb_result_rob_pos;
wire [`DATA_WID]    lsb_result_val;

wire                decode;
wire [ `OPCODE_WID] opcode;
wire [  `FUNC3_WID] func3;
wire                func1;
wire [   `DATA_WID] rs1_val;
wire [ `ROB_ID_WID] rs1_rob_id;
wire [   `DATA_WID] rs2_val;
wire [ `ROB_ID_WID] rs2_rob_id;
wire [   `DATA_WID] imm;
wire [`REG_POS_WID] rd;
wire [   `ADDR_WID] pc;
wire [`ROB_POS_WID] rob_pos;
wire                pre_jump;
wire                is_store;
wire                is_ready;

//memctrl <-> ifetch
wire                if_to_memc_en;
wire [   `ADDR_WID] if_to_memc_pc;
wire                memc_to_if_done;
wire [`IF_DATA_WID] memc_to_if_data;

//memctrl <-> lsb
wire             lsb_to_memc_en;
wire             lsb_to_memc_rw;
wire [`ADDR_WID] lsb_to_memc_addr;
wire [      2:0] lsb_to_memc_len;
wire [`DATA_WID] lsb_to_memc_w_data;
wire             memc_to_lsb_done;
wire [`DATA_WID] memc_to_lsb_r_data;

// ifetch <-> decoder
wire             if_to_decoder_inst_rdy;
wire [`INST_WID] if_to_decoder_inst;
wire [`ADDR_WID] if_to_decoder_inst_pc;
wire             if_to_decoder_inst_pre_jump;

// ifetch <-> rob
wire             rob_to_if_set_pc_en;
wire [`ADDR_WID] rob_to_if_set_pc;
wire             rob_to_if_br;
wire             rob_to_if_br_jump;
wire [`ADDR_WID] rob_to_if_br_pc;

// decoder <-> regfile
wire [`REG_POS_WID] decoder_to_reg_rs1;
wire [   `DATA_WID] reg_to_decoder_rs1_val;
wire [ `ROB_ID_WID] reg_to_decoder_rs1_rob_id;
wire [`REG_POS_WID] decoder_to_reg_rs2;
wire [   `DATA_WID] reg_to_decoder_rs2_val;
wire [ `ROB_ID_WID] reg_to_decoder_rs2_rob_id;

// decoder <-> rob
wire [`ROB_POS_WID] decoder_to_rob_rs1_pos;
wire                rob_to_decoder_rs1_ready;
wire [   `DATA_WID] rob_to_decoder_rs1_val;
wire [`ROB_POS_WID] decoder_to_rob_rs2_pos;
wire                rob_to_decoder_rs2_ready;
wire [   `DATA_WID] rob_to_decoder_rs2_val;
wire [`ROB_POS_WID] rob_to_decoder_nxt_pos;

// decoder <-> rs
wire decoder_to_rs_en;

// decoder <-> lsb
wire decoder_to_lsb_en;

// regfile <-> rob
wire                rob_to_reg_commit;
wire [`REG_POS_WID] rob_to_reg_commit_rd;
wire [   `DATA_WID] rob_to_reg_commit_val;
wire [`ROB_POS_WID] rob_to_reg_commit_rob_pos;

// rob <-> lsb
wire                rob_to_lsb_commit_store;
wire [`ROB_POS_WID] rob_to_lsb_rob_pos;

// rs <-> alu
wire                rs_to_alu_en;
wire [ `OPCODE_WID] rs_to_alu_opcode;
wire [  `FUNC3_WID] rs_to_alu_func3;
wire                rs_to_alu_func1;
wire [   `DATA_WID] rs_to_alu_val1;
wire [   `DATA_WID] rs_to_alu_val2;
wire [   `DATA_WID] rs_to_alu_imm;
wire [   `ADDR_WID] rs_to_alu_pc;
wire [`ROB_POS_WID] rs_to_alu_rob_pos;

ALU t_ALU(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .rollback(rollback),
    .alu_en(rs_to_alu_en),
    .opcode(rs_to_alu_opcode),
    .func3(rs_to_alu_func3),
    .func1(rs_to_alu_func1),
    .val1(rs_to_alu_val1),
    .val2(rs_to_alu_val2),
    .imm(rs_to_alu_imm),
    .pc(rs_to_alu_pc),
    .rob_pos(rs_to_alu_rob_pos),
    .result(alu_result),
    .result_rob_pos(alu_result_rob_pos),
    .result_val(alu_result_val),
    .result_jump(alu_result_jump),
    .result_pc(alu_result_pc)
);

Decoder t_Decoder(
    .rst(rst_in),
    .rdy(rdy_in),
    .rollback(rollback),
    .if_inst_rdy(if_to_decoder_inst_rdy),
    .if_inst(if_to_decoder_inst),
    .if_inst_pc(if_to_decoder_inst_pc),
    .if_inst_pre_jump(if_to_decoder_inst_pre_jump),
    .decode(decode),
    .opcode(opcode),
    .func3(func3),
    .func1(func1),
    .rs1_val(rs1_val),
    .rs1_rob_id(rs1_rob_id),
    .rs2_val(rs2_val),
    .rs2_rob_id(rs2_rob_id),
    .imm(imm),
    .rd(rd),
    .pc(pc),
    .rob_pos(rob_pos),
    .pre_jump(pre_jump),
    .is_store(is_store),
    .is_ready(is_ready),
    .reg_rs1(decoder_to_reg_rs1),
    .reg_rs1_val(reg_to_decoder_rs1_val),
    .reg_rs1_rob_id(reg_to_decoder_rs1_rob_id),
    .reg_rs2(decoder_to_reg_rs2),
    .reg_rs2_val(reg_to_decoder_rs2_val),
    .reg_rs2_rob_id(reg_to_decoder_rs2_rob_id),
    .rob_rs1_pos(decoder_to_rob_rs1_pos),
    .rob_rs1_ready(rob_to_decoder_rs1_ready),
    .rob_rs1_val(rob_to_decoder_rs1_val),
    .rob_rs2_pos(decoder_to_rob_rs2_pos),
    .rob_rs2_ready(rob_to_decoder_rs2_ready),
    .rob_rs2_val(rob_to_decoder_rs2_val),
    .rob_nxt_pos(rob_to_decoder_nxt_pos),
    .rs_en(decoder_to_rs_en),
    .lsb_en(decoder_to_lsb_en),
    .alu_result(alu_result),
    .alu_result_rob_pos(alu_result_rob_pos),
    .alu_result_val(alu_result_val),
    .lsb_result(lsb_result),
    .lsb_result_rob_pos(lsb_result_rob_pos),
    .lsb_result_val(lsb_result_val)
);

IFetch t_IFetch(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .rs_full(rs_full),
    .lsb_full(lsb_full),
    .rob_full(rob_full),
    .decode_inst_rdy(if_to_decoder_inst_rdy),
    .decode_inst(if_to_decoder_inst),
    .decode_inst_pc(if_to_decoder_inst_pc),
    .decode_inst_pre_jump(if_to_decoder_inst_pre_jump),
    .memc_en(if_to_memc_en),
    .memc_pc(if_to_memc_pc),
    .memc_done(memc_to_if_done),
    .memc_data(memc_to_if_data),
    .rob_set_pc_en(rob_to_if_set_pc_en),
    .rob_set_pc(rob_to_if_set_pc),
    .rob_br(rob_to_if_br),
    .rob_br_jump(rob_to_if_br_jump),
    .rob_br_pc(rob_to_if_br_pc)
);

LSB t_LSB(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .rollback(rollback),
    .lsb_full(lsb_full),
    .decode(decode),
    .decode_func3(func3),
    .decode_func1(func1),
    .decode_rs1_val(rs1_val),
    .decode_rs1_rob_id(rs1_rob_id),
    .decode_rs2_val(rs2_val),
    .decode_rs2_rob_id(rs2_rob_id),
    .decode_imm(imm),
    .decode_rd(rd),
    .decode_pc(pc),
    .decode_rob_pos(rob_pos),
    .decode_is_store(is_store),
    .memc_en(lsb_to_memc_en),
    .memc_rw(lsb_to_memc_rw),
    .memc_addr(lsb_to_memc_addr),
    .memc_len(lsb_to_memc_len),
    .memc_w_data(lsb_to_memc_w_data),
    .memc_done(memc_to_lsb_done),
    .memc_r_data(memc_to_lsb_r_data),
    .rob_commit_store(rob_to_lsb_commit_store),
    .rob_rob_pos(rob_to_lsb_rob_pos),
    .alu_result(alu_result),
    .alu_result_rob_pos(alu_result_rob_pos),
    .alu_result_val(alu_result_val),
    .lsb_result(lsb_result),
    .lsb_result_rob_pos(lsb_result_rob_pos),
    .lsb_result_val(lsb_result_val),
    .result(lsb_result),
    .result_rob_pos(lsb_result_rob_pos),
    .result_val(lsb_result_val)
);

MemCtrl t_MemCtrl(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .rollback(rollback),
    .mem_in(mem_din),
    .mem_out(mem_dout),
    .mem_addr(mem_a),			
    .mem_rw(mem_wr),
    .if_en(if_to_memc_en),
    .if_pc(if_to_memc_pc),
    .if_done(memc_to_if_done),
    .if_data(memc_to_if_data),
    .lsb_en(lsb_to_memc_en),
    .lsb_rw(lsb_to_memc_rw),
    .lsb_addr(lsb_to_memc_addr),
    .lsb_len(lsb_to_memc_len),
    .lsb_w_data(lsb_to_memc_w_data),
    .lsb_done(memc_to_lsb_done),
    .lsb_r_data(memc_to_lsb_r_data)
);

RegFile t_RegFile(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .rollback(rollback),
    .decode_rs1(decoder_to_reg_rs1),
    .decode_rs1_val(reg_to_decoder_rs1_val),
    .decode_rs1_rob_id(reg_to_decoder_rs1_rob_id),
    .decode_rs2(decoder_to_reg_rs2),
    .decode_rs2_val(reg_to_decoder_rs2_val),
    .decode_rs2_rob_id(reg_to_decoder_rs2_rob_id),
    .decode(decode),
    .decode_rd(rd),
    .decode_rob_pos(rob_pos),
    .rob_commit(rob_to_reg_commit),
    .rob_commit_rd(rob_to_reg_commit_rd),
    .rob_commit_val(rob_to_reg_commit_val),
    .rob_commit_rob_pos(rob_to_reg_commit_rob_pos)
);

ROB t_ROB(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .rollback(rollback),
    .rob_full(rob_full),
    .if_set_pc_en(rob_to_if_set_pc_en),
    .if_set_pc(rob_to_if_set_pc),
    .if_br(rob_to_if_br),
    .if_br_jump(rob_to_if_br_jump),
    .if_br_pc(rob_to_if_br_pc),
    .decode(decode),
    .decode_opcode(opcode),
    .decode_is_store(is_store),
    .decode_rd(rd),
    .decode_pc(pc),
    .decode_pre_jump(pre_jump),
    .decode_is_ready(is_ready),
    .decode_rs1_pos(decoder_to_rob_rs1_pos),
    .decode_rs1_ready(rob_to_decoder_rs1_ready),
    .decode_rs1_val(rob_to_decoder_rs1_val),
    .decode_rs2_pos(decoder_to_rob_rs2_pos),
    .decode_rs2_ready(rob_to_decoder_rs2_ready),
    .decode_rs2_val(rob_to_decoder_rs2_val),
    .decode_nxt_pos(rob_to_decoder_nxt_pos),
    .reg_commit(rob_to_reg_commit),
    .reg_commit_rd(rob_to_reg_commit_rd),
    .reg_commit_val(rob_to_reg_commit_val),
    .reg_commit_rob_pos(rob_to_reg_commit_rob_pos),
    .lsb_commit_store(rob_to_lsb_commit_store),
    .lsb_rob_pos(rob_to_lsb_rob_pos),
    .alu_result(alu_result),
    .alu_result_rob_pos(alu_result_rob_pos),
    .alu_result_val(alu_result_val),
    .alu_result_jump(alu_result_jump),
    .alu_result_pc(alu_result_pc),
    .lsb_result(lsb_result),
    .lsb_result_rob_pos(lsb_result_rob_pos),
    .lsb_result_val(lsb_result_val)
);

RS t_RS(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .rollback(rollback),
    .rs_full(rs_full),
    .decode(decode),
    .decode_rob_pos(rob_pos),
    .decode_opcode(opcode),
    .decode_func3(func3),
    .decode_func1(func1),
    .decode_rs1_val(rs1_val),
    .decode_rs1_rob_id(rs1_rob_id),
    .decode_rs2_val(rs2_val),
    .decode_rs2_rob_id(rs2_rob_id),
    .decode_imm(imm),
    .decode_pc(pc),
    .alu_en(rs_to_alu_en),
    .alu_opcode(rs_to_alu_opcode),
    .alu_func3(rs_to_alu_func3),
    .alu_func1(rs_to_alu_func1),
    .alu_val1(rs_to_alu_val1),
    .alu_val2(rs_to_alu_val2),
    .alu_imm(rs_to_alu_imm),
    .alu_pc(rs_to_alu_pc),
    .alu_rob_pos(rs_to_alu_rob_pos),
    .alu_result(alu_result),
    .alu_result_rob_pos(alu_result_rob_pos),
    .alu_result_val(alu_result_val),
    .lsb_result(lsb_result),
    .lsb_result_rob_pos(lsb_result_rob_pos),
    .lsb_result_val(lsb_result_val)
);

endmodule