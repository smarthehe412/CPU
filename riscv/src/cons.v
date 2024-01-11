//from 1024th
`ifndef CONS
`define CONS

`define REG_SIZE 32
`define ROB_SIZE 16
`define RS_SIZE 16
`define RS_NPOS 5'd16
`define BP_SIZE 256
`define LSB_SIZE 16
`define LSB_NPOS 5'd16
`define BHT_SIZE 256

`define INST_WID 31:0
`define DATA_WID 31:0
`define ADDR_WID 31:0
`define ROB_POS_WID 3:0
`define REG_POS_WID 4:0
`define RS_POS_WID 3:0
`define LSB_POS_WID 3:0
// rob_id = {flag, rob_pos}
// flag: 0 = ready, 1 = renamed
`define ROB_ID_WID 4:0
`define RS_ID_WID 4:0
`define LSB_ID_WID 4:0  

// Instruction Cache
// total size = BLK_NUM * BLK_SIZE * INST_SIZE Bytes = 1024 Bytes
`define ICACHE_BLK_NUM 16
`define ICACHE_BLK_SIZE 64  // Bytes (16 instructions)
`define ICACHE_BLK_WID 511:0  // ICACHE_BLK_SIZE*8 - 1 : 0
`define ICACHE_BS_RANGE 5:2
`define ICACHE_BS_WID 3:0
`define ICACHE_IDX_RANGE 9:6
`define ICACHE_IDX_WID 3:0
`define ICACHE_TAG_RANGE 31:10
`define ICACHE_TAG_WID 21:0
`define BP_IDX_RANGE 9:2
`define BP_IDX_WID 7:0
`define BHT_IDX_RANGE 9:2
`define BHT_IDX_WID 7:0

`define MEM_CTRL_LEN_WID 6:0  // 2^6 = 64 = ICACHE_BLK_SIZE
`define MEM_CTRL_IF_DATA_LEN 64  // ICACHE_BLK_SIZE
`define IF_DATA_WID 511:0  // = ICACHE_BLK_WID
`define INST_SIZE 4

// RISC-V
`define OPCODE_WID 6:0
`define OPCODE_RANGE 6:0
`define FUNC3_WID 2:0
`define RD_RANGE 11:7
`define FUNC3_RANGE 14:12
`define RS1_RANGE 19:15
`define RS2_RANGE 24:20

`define OPCODE_L      7'b0000011
`define OPCODE_S      7'b0100011
`define OPCODE_ARITHI 7'b0010011
`define OPCODE_ARITH  7'b0110011
`define OPCODE_LUI    7'b0110111
`define OPCODE_AUIPC  7'b0010111
`define OPCODE_JAL    7'b1101111
`define OPCODE_JALR   7'b1100111
`define OPCODE_B      7'b1100011

`define FUNC3_ADD  3'h0
`define FUNC3_SUB  3'h0
`define FUNC3_XOR  3'h4
`define FUNC3_OR   3'h6
`define FUNC3_AND  3'h7
`define FUNC3_SLL  3'h1
`define FUNC3_SRL  3'h5
`define FUNC3_SRA  3'h5
`define FUNC3_SLT  3'h2
`define FUNC3_SLTU 3'h3

`define FUNC1_ADD 1'b0
`define FUNC1_SUB 1'b1
`define FUNC1_SRL 1'b0
`define FUNC1_SRA 1'b1

`define FUNC3_ADDI  3'h0
`define FUNC3_XORI  3'h4
`define FUNC3_ORI   3'h6
`define FUNC3_ANDI  3'h7
`define FUNC3_SLLI  3'h1
`define FUNC3_SRLI  3'h5
`define FUNC3_SRAI  3'h5
`define FUNC3_SLTI  3'h2
`define FUNC3_SLTUI 3'h3

`define FUNC1_SRLI 1'b0
`define FUNC1_SRAI 1'b1

`define FUNC3_LB  3'h0
`define FUNC3_LH  3'h1
`define FUNC3_LW  3'h2
`define FUNC3_LBU 3'h4
`define FUNC3_LHU 3'h5

`define FUNC3_SB 3'h0
`define FUNC3_SH 3'h1
`define FUNC3_SW 3'h2

`define FUNC3_BEQ  3'h0
`define FUNC3_BNE  3'h1
`define FUNC3_BLT  3'h4
`define FUNC3_BGE  3'h5
`define FUNC3_BLTU 3'h6
`define FUNC3_BGEU 3'h7

`endif
