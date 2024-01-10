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
    output reg  [   `DATA_WID] decode_val1,
    output reg  [ `ROB_ID_WID] decode_rely1,
    input  wire [`REG_POS_WID] decode_rs2,
    output reg  [   `DATA_WID] decode_val2,
    output reg  [ `ROB_ID_WID] decode_rely2,

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
    reg [`ROB_ID_WID] rely[`REG_SIZE-1:0];  //{flag, rob_id}; flag: 0=ready, 1=renamed

    //answer queries from Decoder
    reg is_real=(rob_commit&&rob_commit_rd!=5'b0); //is the commit actually changed registers
    reg is_final=(rely[rob_commit_rd]=={1'b1,rob_commit_rob_pos});
    always @(*) begin
        if(is_real&&is_final&&decode_rs1==rob_commit_rd) begin //just commited
            decode_val1=rob_commit_val;
            decode_rely1=5'b0;
        end else begin
            decode_val1=val[decode_rs1];
            decode_rely1=rely[decode_rs1];
        end
        if(is_real&&is_final&&decode_rs2==rob_commit_rd) begin //just commited
            decode_val2=rob_commit_val;
            decode_rely2=5'b0;
        end else begin
            decode_val2=val[decode_rs2];
            decode_rely2=rely[decode_rs2];
        end
    end

    //deal with issue and commit
    integer i;
    always @(posedge clk) begin
        if(rst) begin
            for(i=0;i<32;i=i+1) begin
                val[i]<=32'b0;
                rob_id[i]<=5'b0;
            end
        end else if(rdy) begin
            if(is_real) begin
                val[rob_commit_rd]<=rob_commit_val;
                if(is_final) rely[rob_commit_rd]<=5'b0;
            end
            if(decode&&decode_rd!=5'b0) begin
                rely[decode_rd]<={1'b1,decode_rob_pos};//last assignment works
            end
            if (rollback) begin
                for(i=0;i<32;i=i+1) rely[i]<=5'b0;
            end
        end
    end
endmodule
`endif