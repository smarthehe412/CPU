//需要解析指令
//从 ifetch 获得指令
//为了解析指令，需要查询 regfile（组合逻辑即时通信）
//解析好的指令传送给 rob
//解决即时广播的信息

`ifndef DECODER
`define DECODER
`include "cons.v"

module Decoder (
    input wire rst,
    input wire rdy,

    input wire rollback,

    // from Instruction Fetcher
    input wire             inst_rdy,
    input wire [`INST_WID] inst,
    input wire [`ADDR_WID] inst_pc,
    input wire             inst_pred_jump,

    // issue instruction
    output reg                issue,
    output reg [`ROB_POS_WID] rob_pos,
    output reg [ `OPCODE_WID] opcode,
    output reg                is_store,
    output reg [  `FUNC3_WID] func3,
    output reg                func7,
    output reg [   `DATA_WID] rs1_val,
    output reg [ `ROB_ID_WID] rs1_rob_id,
    output reg [   `DATA_WID] rs2_val,
    output reg [ `ROB_ID_WID] rs2_rob_id,
    output reg [   `DATA_WID] imm,
    output reg [`REG_POS_WID] rd,
    output reg [   `ADDR_WID] pc,
    output reg                pre_jump,
    output reg                is_ready,

    // query in Register File
    output wire [`REG_POS_WID] reg_rs1,
    input  wire [   `DATA_WID] reg_rs1_val,
    input  wire [ `ROB_ID_WID] reg_rs1_rob_id,
    output wire [`REG_POS_WID] reg_rs2,
    input  wire [   `DATA_WID] reg_rs2_val,
    input  wire [ `ROB_ID_WID] reg_rs2_rob_id,

    // query in Reorder Buffer
    output wire [`ROB_POS_WID] rob_rs1_pos,
    input  wire                rob_rs1_ready,
    input  wire [   `DATA_WID] rob_rs1_val,
    output wire [`ROB_POS_WID] rob_rs2_pos,
    input  wire                rob_rs2_ready,
    input  wire [   `DATA_WID] rob_rs2_val,

    output reg  rs_en,
    output reg  lsb_en,

    input wire [`ROB_POS_WID] nxt_rob_pos,

    // handle the broadcast
    // from Reservation Station
    input wire alu_result,
    input wire [`ROB_POS_WID] alu_result_rob_pos,
    input wire [`DATA_WID] alu_result_val,
    // from Load Store Buffer
    input wire lsb_result,
    input wire [`ROB_POS_WID] lsb_result_rob_pos,
    input wire [`DATA_WID] lsb_result_val
);
    //decode rs
    assign reg_rs1=inst[`RS1_RANGE];
    assign reg_rs2=inst[`RS2_RANGE];
    assign rob_rs1_pos=reg_rs1_rob_id[`ROB_POS_WID];
    assign rob_rs2_pos=reg_rs2_rob_id[`ROB_POS_WID];
    always @(*) begin
        //decode
        opcode=inst[`OPCODE_RANGE];
        func3=inst[`FUNC3_RANGE];
        func7=inst[30];
        rd=inst[`RD_RANGE];
        imm=0;
        pc=inst_pc;
        pre_jump=inst_pre_jump;
        rob_pos=nxt_rob_pos;

        issue=0;
        rs_en=0;
        lsb_en=0;
        is_ready=0;
        is_store=0;

        rs1_val=0;
        rs1_rob_id=0;
        rs2_val=0;
        rs2_rob_id=0;

        if(rst||!inst_rdy||rollback||!rdy);
        else begin
            issue=1;
            if(reg_rs1_pos_id[4]==0) begin//flag
                rs1_val=reg_rs1_val;
            end else if(alu_result&&alu_result_rob_pos==rob_rs1_pos) begin
                rs1_val=alu_result_val;
            end else if(lsb_result&&lsb_result_rob_pos==rob_rs1_pos) begin
                rs1_val=lsb_result_val;
            end else begin
                rs1_rob_id=reg_rs1_pos_id;
            end
            if(reg_rs2_pos_id[4]==0) begin//flag
                rs2_val=reg_rs2_val;
            end else if(alu_result&&alu_result_rob_pos==rob_rs2_pos) begin
                rs2_val=alu_result_val;
            end else if(lsb_result&&lsb_result_rob_pos==rob_rs2_pos) begin
                rs2_val=lsb_result_val;
            end else begin
                rs2_rob_id=reg_rs2_pos_id;
            end

            case(opcode)
                `OPCODE_LUI, `OPCODE_AUIPC: begin
                    rs_en=1;
                    rs1_rob_id=0;
                    rs1_val=0;
                    rs2_rob_id=0;
                    rs2_val=0;
                    imm={inst[31:12],12'b0};
                end
                `OPCODE_JAL: begin
                    rs_en=1;
                    rs1_rob_id=0;
                    rs1_val=0;
                    rs2_rob_id=0;
                    rs2_val=0;
                    imm={inst[31],inst[19:12],inst[20],inst[30:21],1'b0};
                end
                `OPCODE_JALR, `OPCODE_ARITHI: begin
                    rs_en=1;
                    rs2_rob_id=0;
                    rs2_val=0;
                    imm={{20{inst[31]}},inst[31:20]};//sext
                end
                `OPCODE_B: begin
                    rs_en=1;
                    rd=0;
                    imm={{19{inst[31]}},inst[31],inst[7],inst[30:25],inst[11:8],1'b0};
                end
                `OPCODE_L: begin
                    lsb_en=1;
                    rs2_rob_id=0;
                    rs2_val=0;
                    imm={{20{inst[31]}},inst[31:20]};//sext
                end
                `OPCODE_S: begin
                    is_store=1;
                    is_ready=1;
                    lsb_en=1;
                    rd=0;
                    imm={{20{inst[31]}},inst[31:25],inst[11:7]};
                end
                `OPCODE_ARITH: begin
                    rs_en=1;
                end
            endcase
        end
    end
endmodule