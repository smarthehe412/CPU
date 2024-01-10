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
    input  wire [`REG_POS_WID] rs1,
    output reg  [   `DATA_WID] val1,
    output reg  [ `ROB_ID_WID] rely1,
    input  wire [`REG_POS_WID] rs2,
    output reg  [   `DATA_WID] val2,
    output reg  [ `ROB_ID_WID] rely2,

    // Decoder issue (telling an instruction need register ...)
    input wire                issue,
    input wire [`REG_POS_WID] issue_rd,
    input wire [`ROB_POS_WID] issue_rob_pos,

    // ReorderBuffer commit (telling an instruction is commited)
    input wire                commit,
    input wire [`REG_POS_WID] commit_rd,
    input wire [   `DATA_WID] commit_val,
    input wire [`ROB_POS_WID] commit_rob_pos
);
    reg [`DATA_WID] val[`REG_SIZE-1:0]; //registers
    reg [`ROB_ID_WID] rely[`REG_SIZE-1:0];  //{flag, rob_id}; flag: 0=ready, 1=renamed

    //answer queries from Decoder
    reg is_real=(commit&&commit_rd!=5'b0); //is the commit actually changed registers
    reg is_final=(rely[commit_rd]=={1'b1,commit_rob_pos});
    always @(*) begin
        if(is_real&&is_final&&rs1==commit_rd) begin //just commited
            val1=commit_val;
            rely1=5'b0;
        end else begin
            val1=val[rs1];
            rely1=rely[rs1];
        end
        if(is_real&&is_final&&rs2==commit_rd) begin //just commited
            val2=commit_val;
            rely2=5'b0;
        end else begin
            val2=val[rs2];
            rely2=rely[rs2];
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
                val[commit_rd]<=commit_val;
                if(is_final) rely[commit_rd]<=5'b0;
            end
            if(issue&&issue_rd!=5'b0) begin
                rely[issue_rd]<={1'b1,issue_rob_pos};//last assignment works
            end
            if (rollback) begin
                for(i=0;i<32;i=i+1) rely[i]<=5'b0;
            end
        end
    end
endmodule