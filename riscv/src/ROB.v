`ifndef ROB
`define ROB
`include "cons.v"
module ROB(
    input wire clk,
    input wire rst,
    input wire rdy,

    output reg rollback,
    output wire rob_full,

    output reg             if_set_pc_en,
    output reg [`ADDR_WID] if_set_pc,
    output reg             if_br,
    output reg             if_br_jump,
    output reg [`ADDR_WID] if_br_pc,

    input wire                decode,
    input wire [ `OPCODE_WID] decode_opcode,
    input wire                decode_is_store,
    input wire [`REG_POS_WID] decode_rd,
    input wire [   `ADDR_WID] decode_pc,
    input wire                decode_pre_jump,
    input wire                decode_is_ready,

    input  wire [`ROB_POS_WID] decode_rs1_pos,
    output wire                decode_rs1_ready,
    output wire [   `DATA_WID] decode_rs1_val,
    input  wire [`ROB_POS_WID] decode_rs2_pos,
    output wire                decode_rs2_ready,
    output wire [   `DATA_WID] decode_rs2_val,
    output wire [`ROB_POS_WID] decode_nxt_pos,

    output reg                reg_commit,
    output reg [`REG_POS_WID] reg_commit_rd,
    output reg [   `DATA_WID] reg_commit_val,
    output reg [`ROB_POS_WID] reg_commit_rob_pos,

    output reg                lsb_commit_store,
    output reg [`ROB_POS_WID] lsb_rob_pos,

    input wire                alu_result,
    input wire [`ROB_POS_WID] alu_result_rob_pos,
    input wire [   `DATA_WID] alu_result_val,
    input wire                alu_result_jump,
    input wire [   `ADDR_WID] alu_result_pc,
    input wire                lsb_result,
    input wire [`ROB_POS_WID] lsb_result_rob_pos,
    input wire [   `DATA_WID] lsb_result_val
);
    reg                ready    [`ROB_SIZE-1:0];
    reg [`REG_POS_WID] rd       [`ROB_SIZE-1:0];
    reg [   `DATA_WID] val      [`ROB_SIZE-1:0];
    reg [   `ADDR_WID] pc       [`ROB_SIZE-1:0];
    reg [ `OPCODE_WID] opcode   [`ROB_SIZE-1:0];
    reg                pre_jump [`ROB_SIZE-1:0];
    reg                is_jump  [`ROB_SIZE-1:0];
    reg [   `ADDR_WID] nxt_pc   [`ROB_SIZE-1:0];

    reg [`ROB_POS_WID] head,tail;
    reg is_empty;
    wire is_commit=!is_empty && ready[head];
    wire [`ROB_POS_WID] nxt_head= head+is_commit; //safe for overflow
    wire [`ROB_POS_WID] nxt_tail= tail+decode;
    wire is_nxt_empty=(nxt_head==nxt_tail)&&(is_empty||(is_commit&&!decode));
    assign rob_full=(nxt_head==nxt_tail)&&!is_nxt_empty;
    assign decode_nxt_pos=tail;

    assign decode_rs1_ready=ready[decode_rs1_pos];
    assign decode_rs1_val=val[decode_rs1_pos];
    assign decode_rs2_ready=ready[decode_rs2_pos];
    assign decode_rs2_val=val[decode_rs2_pos];

    integer i;
    always @(posedge clk) begin
        if(rst||rollback) begin
            head<=0;
            tail<=0;
            is_empty<=1;
            rollback<=0;
            reg_commit<=0;
            if_set_pc_en<=0;
            if_br<=0;
            lsb_commit_store<=0;
            for(i=0;i<`ROB_SIZE;i=i+1) begin
                ready[i]<=0;
                rd[i]<=0;
                val[i]<=0;
                pc[i]<=0;
                opcode[i]<=0;
                pre_jump[i]<=0;
                is_jump[i]<=0;
                nxt_pc[i]<=0;
            end
        end else if(rdy) begin
            head<=nxt_head;
            tail<=nxt_tail;
            is_empty<=is_nxt_empty;
            reg_commit<=0;
            if_set_pc_en<=0;
            if_br<=0;
            lsb_commit_store<=0;
            if(decode) begin
                //if(decode_pc<=32'h00001500) $display("%h %b",decode_pc,decode_opcode);
                ready[tail]<=decode_is_ready;
                rd[tail]<=decode_rd;
                val[tail]<=0;
                pc[tail]<=decode_pc;
                opcode[tail]<=decode_opcode;
                pre_jump[tail]<=decode_pre_jump;
                is_jump[tail]<=0;
                nxt_pc[tail]<=0;
            end
            if(is_commit) begin
                //$display("%h %b",pc[head],opcode[head]);
                reg_commit_rob_pos<=head;
                case(opcode[head])
                    `OPCODE_JALR: begin
                        reg_commit<=1;
                        reg_commit_rd<=rd[head];
                        reg_commit_val<=val[head];
                        rollback<=1;
                        if_set_pc_en<=1;
                        if_set_pc<=nxt_pc[head];
                    end
                    `OPCODE_B: begin
                        if_br<=1;
                        if_br_jump<=is_jump[head];
                        if_br_pc<=pc[head];
                        if(pre_jump[head]!=is_jump[head]) begin
                            rollback<=1;
                            if_set_pc_en<=1;
                            if_set_pc<=nxt_pc[head];
                        end
                    end
                    `OPCODE_S: begin
                        lsb_commit_store<=1;
                        lsb_rob_pos<=head;
                    end
                    default: begin
                        reg_commit<=1;
                        reg_commit_rd<=rd[head];
                        reg_commit_val<=val[head];
                    end
                endcase
            end
            if(alu_result) begin
                ready[alu_result_rob_pos]<=1;
                val[alu_result_rob_pos]<=alu_result_val;
                is_jump[alu_result_rob_pos]<=alu_result_jump;
                nxt_pc[alu_result_rob_pos]<=alu_result_pc;
            end
            if(lsb_result) begin
                ready[lsb_result_rob_pos]<=1;
                val[lsb_result_rob_pos]<=lsb_result_val;
            end
        end
    end
endmodule
`endif