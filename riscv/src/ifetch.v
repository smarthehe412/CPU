//接受指令，做出预测
//在 iCache 存储指令
//向 decoder 输出指令

`ifndef IFETCH
`define IFETCH
`include "cons.v"
module IFetch (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rs_full,
    input wire lsb_full,
    input wire rob_full,

    output reg             decode_inst_rdy,
    output reg [`INST_WID] decode_inst,
    output reg [`ADDR_WID] decode_inst_pc,
    output reg             decode_inst_pre_jump,

    output reg                 memc_en,
    output reg  [   `ADDR_WID] memc_pc,
    input  wire                memc_done,
    input  wire [`IF_DATA_WID] memc_data,

    input wire             rob_set_pc_en,
    input wire [`ADDR_WID] rob_set_pc,
    input wire             rob_br,
    input wire             rob_br_jump,
    input wire [`ADDR_WID] rob_br_pc
);
    localparam IDLE=0, WAIT=1;
    reg [`ADDR_WID] pc;
    reg status;

    // iCache design:
    // Block num 16, Block size 64 (bytes), 4 bytes per instruction, 16 instructions per block 
    // tag = pc[31:10], name a block 
    // index = pc[9:6], block index of pc
    // bs = pc[5:2], in-block index of pc
    // memctrl read a whole block (64 bytes) in one query
    reg icache_is[`ICACHE_BLK_NUM-1:0];
    reg [`ICACHE_TAG_WID] icache_tag[`ICACHE_BLK_NUM-1:0];
    reg [`ICACHE_BLK_WID] icache_data[`ICACHE_BLK_NUM-1:0];

    wire [`ICACHE_BS_WID] pc_bs = pc[`ICACHE_BS_RANGE];
    wire [`ICACHE_IDX_WID] pc_index = pc[`ICACHE_IDX_RANGE];
    wire [`ICACHE_TAG_WID] pc_tag = pc[`ICACHE_TAG_RANGE];
    wire hit = icache_is[pc_index] && (icache_tag[pc_index] == pc_tag);
    wire [`ICACHE_IDX_WID] memc_pc_index = memc_pc[`ICACHE_IDX_RANGE];
    wire [`ICACHE_TAG_WID] memc_pc_tag = memc_pc[`ICACHE_TAG_RANGE];

    wire [`ICACHE_BLK_WID] cur_block_raw = icache_data[pc_index];
    wire [`INST_WID] cur_block[15:0];
    wire [`INST_WID] tmp_inst = cur_block[pc_bs];

    genvar _i;
    generate
        for (_i = 0; _i < `ICACHE_BLK_SIZE / `INST_SIZE; _i = _i + 1) begin
            assign cur_block[_i] = cur_block_raw[_i*32+31:_i*32];
        end
    endgenerate

    // Branch Predictor, size = 256
    reg [`ADDR_WID] pre_pc;
    reg pre_jump;
    reg [1:0] bp[`BP_SIZE-1:0];
    wire [`BP_IDX_WID] bp_index=rob_br_pc[`BP_IDX_RANGE];

    // Branch history
    always @(posedge clk) begin
        if(rst) begin
            for(i=0;i<`BP_SIZE;i=i+1) bp[i]<=0;
        end else if (!rdy) begin
            ;
        end else if (rob_br) begin
            if(rob_br_jump) begin
                if(bp[bp_index]<2'd3) bp[bp_index]<=bp[bp_index]+1;
            end else begin
                if(bp[bp_index]>2'd0) bp[bp_index]<=bp[bp_index]-1;
            end
        end
    end

    // Branch Predictor
    wire [`BHT_IDX_WID] pc_bht_index=pc[`BHT_IDX_RANGE];
    always @(*) begin
        pre_pc=pc+4;
        pre_jump=0;
        case(tmp_inst[`OPCODE_RANGE])
            `OPCODE_JAL: begin
                pre_pc=pc+{{12{tmp_inst[31]}},tmp_inst[19:12],tmp_inst[20],tmp_inst[30:21],1'b0};
                pre_jump=1;
            end
            `OPCODE_B: begin
                if (bp[pc_bht_index]>=2'd2) begin
                    pre_pc=pc+{{20{tmp_inst[31]}},tmp_inst[7],tmp_inst[30:25],tmp_inst[11:8],1'b0};
                    pre_jump=1;
                end
            end
        endcase
    end

    // fetch
    integer i;
    always @(posedge clk) begin
        if(rst) begin
            pc<=0;
            status<=IDLE;
            memc_pc<=0;
            memc_en<=0;
            for(i=0;i<`ICACHE_BLK_NUM;i=i+1) begin
                icache_is[i]<=0;
            end
            decode_inst_rdy<=0;
            status<=IDLE;
        end else if(!rdy) begin
            ;
        end else begin
            //to decoder
            if(rob_set_pc_en) begin
                decode_inst_rdy<=0;
                pc<=rob_set_pc;
            end else begin
                if(hit&&!rob_full&&!lsb_full&&!rs_full) begin
                    decode_inst_rdy<=1;
                    decode_inst<=tmp_inst;
                    decode_inst_pc<=pc;
                    pc<=pre_pc;
                    decode_inst_pre_jump<=pre_jump;
                end else begin
                    decode_inst_rdy<=0;
                end
            end
            if(status==IDLE) begin
               if(!hit) begin //ask memctrl
                   memc_en<=1;
                   memc_pc<={pc[31:6],6'b0};
                   status<=WAIT;
               end 
            end else begin //wait memctrl
                if(memc_done) begin //done
                    memc_en<=0;
                    icache_is[pc_index]<=1;
                    icache_tag[pc_index]<=pc_tag;
                    icache_data[pc_index]<=memc_data;
                    status<=IDLE;
                end
            end
        end
    end
endmodule
`endif