//Load-store buffer
//Load 会在 decode 完成时进入 ROB 和 LSB 排队，ALU 计算完成后可执行，堵塞 ROB，读内存结束后 commit 时更新寄存器
//Store 会在 decode 完成时进入 ROB 和 LSB 排队，在 ROB 时可以直接 commit 不堵塞，在 LSB 内需要等待 ROB commit 且 ALU 计算完成后才可执行

`ifndef LSB
`define LSB
module LSB(
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rollback,
    output wire lsb_full,

    input wire                decode_en,
    input wire [  `FUNC3_WID] decode_func3,
    input wire [   `DATA_WID] decode_rs1_val,
    input wire [ `ROB_ID_WID] decode_rs1_rob_id,
    input wire [   `DATA_WID] decode_rs2_val,
    input wire [ `ROB_ID_WID] decode_rs2_rob_id,
    input wire [   `DATA_WID] decode_imm,
    input wire [`REG_POS_WID] decode_rd,
    input wire [   `ADDR_WID] decode_pc,
    input wire [`ROB_POS_WID] decode_rob_pos,
    input wire                decode_is_store,

    output reg              memc_en,
    output reg              memc_rw,
    output reg  [`ADDR_WID] memc_addr,
    output reg  [      2:0] memc_len,
    output reg  [`DATA_WID] memc_w_data,
    input  wire             memc_done,
    input  wire [`DATA_WID] memc_r_data,

    input wire                rob_commit_store,
    input wire [`ROB_POS_WID] rob_rob_pos,

    input wire                alu_result,
    input wire [`ROB_POS_WID] alu_result_rob_pos,
    input wire [   `DATA_WID] alu_result_val,
    input wire                lsb_result,
    input wire [`ROB_POS_WID] lsb_result_rob_pos,
    input wire [   `DATA_WID] lsb_result_val,

    output reg                result,
    output reg [`ROB_POS_WID] result_rob_pos,
    output reg [   `DATA_WID] result_val
);
    localparam IDLE=0,WAIT=1;
    reg status;

    reg                busy       [`LSB_SIZE-1:0];
    reg                is_store   [`LSB_SIZE-1:0];
    reg [  `FUNC3_WID] func3      [`LSB_SIZE-1:0];
    reg [ `ROB_ID_WID] rs1_rob_id [`LSB_SIZE-1:0];
    reg [   `DATA_WID] rs1_val    [`LSB_SIZE-1:0];
    reg [ `ROB_ID_WID] rs2_rob_id [`LSB_SIZE-1:0];
    reg [   `DATA_WID] rs2_val    [`LSB_SIZE-1:0];
    reg [   `DATA_WID] imm        [`LSB_SIZE-1:0];
    reg [`ROB_POS_WID] rob_pos    [`LSB_SIZE-1:0];
    reg                committed  [`LSB_SIZE-1:0];

    reg [`LSB_POS_WID] head,tail;
    reg [`LSB_ID_WID] checkpoint;
    reg is_empty;
    wire is_solve=!is_empty && (rs1_rob_id[head][4]==0&&rs2_rob_id[head][4]==0) && ((!is_store[head] && !rollback) || committed[head]);
    wire finish= status==WAIT && memc_done;
    wire [`LSB_POS_WID] nxt_head=head+finish;
    wire [`LSB_POS_WID] nxt_tail=tail+decode_en;
    wire is_nxt_empty=(nxt_head==nxt_tail)&&(is_empty||(finish&&!decode_en));
    assign lsb_full=(nxt_head==nxt_tail)&&!is_nxt_empty;
    
    integer i;
    always @(posedge clk) begin
        head<=nxt_head;
        tail<=nxt_tail;
        is_empty<=is_nxt_empty;
        result<=0;
        if(rst||(rollback&&checkpoint==`LSB_NPOS)) begin
            status<=IDLE;
            head<=0;
            tail<=0;
            is_empty<=1;
            result<=0;
            memc_en<=0;
            checkpoint<=`LSB_NPOS;
            for(i=0;i<`LSB_SIZE;i=i+1) begin
                busy[i]<=0;
                is_store[i]<=0;
                func3[i]<=0;
                rs1_rob_id[i]<=0;
                rs1_val[i]<=0;
                rs2_rob_id[i]<=0;
                rs2_val[i]<=0;
                imm[i]<=0;
                rob_pos[i]<=0;
                committed[i]<=0;
            end
        end else if(rollback) begin
            //$display("%h %b %b %b",rob_pos[head],rs1_rob_id[head],rs2_rob_id[head],committed[head]);
            tail<=checkpoint+1;
            for(i=0;i<`LSB_SIZE;i=i+1) begin
                if(!committed[i]) begin
                    busy[i]<=0;
                end
            end
            //clear head
            if(finish) begin
                status<=IDLE;
                memc_en<=0;
                busy[head]<=0;
                committed[head]<=0;
                if(checkpoint[`LSB_POS_WID]==head) begin
                    checkpoint<=`LSB_NPOS;
                    is_empty<=1;
                end
            end
        end else if(rdy) begin
            if(status==IDLE) begin
                memc_en<=0;
                if(is_solve) begin
                    status<=WAIT;
                    memc_en<=1;
                    memc_rw<=is_store[head];
                    memc_addr<=rs1_val[head]+imm[head];
                    case(func3[head])
                        `FUNC3_LB,`FUNC3_LBU: memc_len<=3'h1; 
                        `FUNC3_LH,`FUNC3_LHU: memc_len<=3'h2;
                                   `FUNC3_LW: memc_len<=3'h4;
                    endcase
                    if(is_store[head]) memc_w_data<=rs2_val[head];
                end
            end else begin
                if(memc_done) begin
                    status<=IDLE;
                    memc_en<=0;
                    busy[head]<=0;
                    committed[head]<=0;
                    if(checkpoint[`LSB_POS_WID]==head) checkpoint<=`LSB_NPOS;
                    if(!is_store[head]) begin
                        result<=1;
                        case(func3[head])
                            `FUNC3_LB:  result_val<={{24{memc_r_data[7]}}, memc_r_data[7:0]};
                            `FUNC3_LBU: result_val<={24'b0, memc_r_data[7:0]};
                            `FUNC3_LH:  result_val<={{16{memc_r_data[15]}}, memc_r_data[15:0]};
                            `FUNC3_LHU: result_val<={16'b0, memc_r_data[15:0]};
                            `FUNC3_LW:  result_val<=memc_r_data; 
                        endcase
                        result_rob_pos<=rob_pos[head];
                    end
                end
            end
            if(rob_commit_store) begin
                for(i=0;i<`LSB_SIZE;i=i+1) begin
                    if(busy[i]&&rob_pos[i]==rob_rob_pos) begin
                        committed[i]<=1;
                        checkpoint<={1'b0,i[`LSB_POS_WID]};
                    end
                end
            end
            if(alu_result) begin
                for(i=0;i<`LSB_SIZE;i=i+1) begin
                    if(busy[i]&&rs1_rob_id[i]=={1'b1,alu_result_rob_pos}) begin
                        rs1_val[i]<=alu_result_val;
                        rs1_rob_id[i]<=0;
                    end
                    if(busy[i]&&rs2_rob_id[i]=={1'b1,alu_result_rob_pos}) begin
                        rs2_val[i]<=alu_result_val;
                        rs2_rob_id[i]<=0;
                    end
                end
            end
            if(lsb_result) begin
                for(i=0;i<`LSB_SIZE;i=i+1) begin
                    if(busy[i]&&rs1_rob_id[i]=={1'b1,lsb_result_rob_pos}) begin
                        rs1_val[i]<=lsb_result_val;
                        rs1_rob_id[i]<=0;
                    end
                    if(busy[i]&&rs2_rob_id[i]=={1'b1,lsb_result_rob_pos}) begin
                        rs2_val[i]<=lsb_result_val;
                        rs2_rob_id[i]<=0;
                    end
                end
            end
            if(decode_en) begin
                busy[tail]<=1;
                is_store[tail]<=decode_is_store;
                func3[tail]<=decode_func3;
                rs1_rob_id[tail]<=decode_rs1_rob_id;
                rs1_val[tail]<=decode_rs1_val;
                rs2_rob_id[tail]<=decode_rs2_rob_id;
                rs2_val[tail]<=decode_rs2_val;
                imm[tail]<=decode_imm;
                rob_pos[tail]<=decode_rob_pos;
                committed[tail]<=0;
            end
        end
    end
endmodule
`endif