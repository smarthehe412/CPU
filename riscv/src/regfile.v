//需要存储每个寄存器对指令的依赖
//从 rob 和 decoder 接受更新信息
//接受 decoder 查询一个寄存器的依赖（即时通信）

`ifndef REGFILE
`define REGFILE
`include "cons.v"
module RegFile (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rollback,

    // query from Decoder, combinational
    input  wire [`REG_POS_WID] decode_rs1,
    output reg  [   `DATA_WID] decode_rs1_val,
    output reg  [ `ROB_ID_WID] decode_rs1_rob_id,
    input  wire [`REG_POS_WID] decode_rs2,
    output reg  [   `DATA_WID] decode_rs2_val,
    output reg  [ `ROB_ID_WID] decode_rs2_rob_id,

    // Decoder issue (telling an instruction need register ...)
    input wire                decode,
    input wire [`REG_POS_WID] decode_rd,
    input wire [`ROB_POS_WID] decode_rob_pos,

    // ReorderBuffer commit (telling an instruction is commited)
    input wire                rob_commit,
    input wire [`REG_POS_WID] rob_commit_rd,
    input wire [   `DATA_WID] rob_commit_val,
    input wire [`ROB_POS_WID] rob_commit_rob_pos
);
    reg [`DATA_WID] val[`REG_SIZE-1:0]; //registers
    reg [`ROB_ID_WID] rob_id[`REG_SIZE-1:0];  //{flag, rob_pos}; flag: 0=ready, 1=renamed

    //answer queries from Decoder
    wire is_real=(rob_commit&&rob_commit_rd!=0); //is the commit actually changed registers
    wire is_final=(rob_id[rob_commit_rd]=={1'b1,rob_commit_rob_pos});
    always @(*) begin
        if(is_real&&is_final&&decode_rs1==rob_commit_rd) begin //just commited
            decode_rs1_val=rob_commit_val;
            decode_rs1_rob_id=0;
        end else begin
            decode_rs1_val=val[decode_rs1];
            decode_rs1_rob_id=rob_id[decode_rs1];
        end
        if(is_real&&is_final&&decode_rs2==rob_commit_rd) begin //just commited
            decode_rs2_val=rob_commit_val;
            decode_rs2_rob_id=0;
        end else begin
            decode_rs2_val=val[decode_rs2];
            decode_rs2_rob_id=rob_id[decode_rs2];
        end
    end

    //deal with issue and commit
    integer i;
    always @(posedge clk) begin
        if(rst) begin
            for(i=0;i<32;i=i+1) begin
                val[i]<=0;
                rob_id[i]<=0;
            end
        end else if(rdy) begin
            if(is_real) begin
                val[rob_commit_rd]<=rob_commit_val;
                if(is_final) rob_id[rob_commit_rd]<=0;
            end
            if(decode&&decode_rd!=0) begin
                rob_id[decode_rd]<={1'b1,decode_rob_pos};
            end
            if(rollback) begin
                for(i=0;i<32;i=i+1) rob_id[i]<=0;
            end
        end
    end
endmodule
`endif