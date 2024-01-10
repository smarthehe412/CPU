//存储未运算的指令
//从 decoder 接受指令
//向 ALU 发送指令
//处理广播

`ifndef RS
`define RS
`include "cons.v"
module RS (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rollback,

    output reg rs_nxt_full, //is full

    // issue instruction
    input wire                issue,
    input wire [`ROB_POS_WID] issue_rob_pos,
    input wire [ `OPCODE_WID] issue_opcode,
    input wire [  `FUNC3_WID] issue_func3,
    input wire                issue_func7,
    input wire [   `DATA_WID] issue_rs1_val,
    input wire [ `ROB_ID_WID] issue_rs1_rob_id,
    input wire [   `DATA_WID] issue_rs2_val,
    input wire [ `ROB_ID_WID] issue_rs2_rob_id,
    input wire [   `DATA_WID] issue_imm,
    input wire [   `ADDR_WID] issue_pc,

    // to ALU
    output reg                alu_en,
    output reg [ `OPCODE_WID] alu_opcode,
    output reg [  `FUNC3_WID] alu_func3,
    output reg                alu_func7,
    output reg [   `DATA_WID] alu_val1,
    output reg [   `DATA_WID] alu_val2,
    output reg [   `DATA_WID] alu_imm,
    output reg [   `ADDR_WID] alu_pc,
    output reg [`ROB_POS_WID] alu_rob_pos,

    // handle the broadcast
    // from Reservation Station
    input wire                alu_result,
    input wire [`ROB_POS_WID] alu_result_rob_pos,
    input wire [   `DATA_WID] alu_result_val,
    // from Load Store Buffer
    input wire                lsb_result,
    input wire [`ROB_POS_WID] lsb_result_rob_pos,
    input wire [   `DATA_WID] lsb_result_val
);
    reg                busy       [`RS_SIZE-1:0];
    reg [ `OPCODE_WID] opcode     [`RS_SIZE-1:0];
    reg [  `FUNC3_WID] func3      [`RS_SIZE-1:0];
    reg                func7      [`RS_SIZE-1:0];
    reg [ `ROB_ID_WID] rs1_rob_id [`RS_SIZE-1:0];
    reg [   `DATA_WID] rs1_val    [`RS_SIZE-1:0];
    reg [ `ROB_ID_WID] rs2_rob_id [`RS_SIZE-1:0];
    reg [   `DATA_WID] rs2_val    [`RS_SIZE-1:0];
    reg [   `ADDR_WID] pc         [`RS_SIZE-1:0];
    reg [   `DATA_WID] imm        [`RS_SIZE-1:0];
    reg [`ROB_POS_WID] rob_pos    [`RS_SIZE-1:0];
    reg                ready      [`RS_SIZE-1:0];

    reg [`RS_ID_WID] tmp_free,tmp_ready;
    //Monitor
    integer i;
    always @(*) begin
        tmp_free=`RS_NPOS;
        tmp_ready=`RS_NPOS;
        rs_nxt_full=1;
        for(i=0;i<`RS_SIZE;i=i+1) begin
            ready[i]=0;
            if(busy[i]) begin
                if(rs1_rob_id[i][4]==0&&rs2_rob_id[i][4]==0) ready[i]=1;
                if(ready[i]) begin
                    tmp_ready=i;
                end
            end else begin
                if(!issue || !tmp_free[4]) rs_nxt_full=0;
                tmp_free=i;
            end
        end
    end

    always @(posedge clk) begin
        if(rst||rollback) begin
            for(i=0;i<`RS_SIZE;i=i+1) begin
                busy[i]<=0;
            end
            alu_en<=0;
        end else if (!rdy) begin
            ;
        end else begin
            if(tmp_ready[4]==0) begin //send to ALU
                alu_en<=1;
                alu_opcode<=opcode[tmp_ready];
                alu_func3<=func3[tmp_ready];
                alu_func7<=func7[tmp_ready];
                alu_val1<=rs1_val[tmp_ready];
                alu_val2<=rs2_val[tmp_ready];
                alu_imm<=imm[tmp_ready];
                alu_pc<=pc[tmp_ready];
                alu_rob_pos<=rob_pos[tmp_ready];
                busy[tmp_ready]<=0; //remember to clear
            end
            if(alu_result) begin //alu broadcast
                for(i=0;i<`RS_SIZE;i=i+1) begin
                    if(rs1_rob_id=={1'b1,alu_result_rob_pos}) begin
                        rs1_val[i]<=alu_result_val;
                        rs1_rob_id[i]<=0;
                    end
                    if(rs2_rob_id=={1'b1,alu_result_rob_pos}) begin
                        rs2_val[i]<=alu_result_val;
                        rs2_rob_id[i]<=0;
                    end
                end
            end
            if(lsb_result) begin //lsb broadcast
                for(i=0;i<`RS_SIZE;i=i+1) begin
                    if(rs1_rob_id=={1'b1,lsb_result_rob_pos}) begin
                        rs1_val[i]<=lsb_result_val;
                        rs1_rob_id[i]<=0;
                    end
                    if(rs2_rob_id=={1'b1,lsb_result_rob_pos}) begin
                        rs2_val[i]<=lsb_result_val;
                        rs2_rob_id[i]<=0;
                    end
                end
            end
            if(issue) begin //new instruction
                opcode[tmp_free]<=issue_opcode;
                func3[tmp_free]<=issue_func3;
                func7[tmp_free]<=issue_func7;
                rs1_rob_id[tmp_free]<=issue_rs1_rob_id;
                rs1_val[tmp_free]<=issue_rs1_val;
                rs2_rob_id[tmp_free]<=issue_rs2_rob_id;
                rs2_val[tmp_free]<=issue_rs2_val;
                pc[tmp_free]<=issue_pc;
                imm[tmp_free]<=issue_imm;
                rob_pos[tmp_free]<=issue_rob_pos;
                busy[tmp_free]<=1; //remember to occupy
            end
        end
    end

    //
endmodule