//需要实现单字节读写
//可能接受 ifetch, LSB 的请求
//需要向 ifetch, LSB 与内存输出
//需要提供是否已经读完的标识

`ifndef MEMCTRL
`define MEMCTRL
`include "cons.v"
module MemCtrl (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rollback,

    input  wire [ 7:0] mem_in,
    output reg  [ 7:0] mem_out,
    output reg  [31:0] mem_addr,			
    output reg         mem_rw,

    input  wire                if_en,
    input  wire [   `ADDR_WID] if_pc,
    output reg                 if_done,
    output wire [`IF_DATA_WID] if_data,

    input  wire             lsb_en,
    input  wire             lsb_rw,
    input  wire [`ADDR_WID] lsb_addr,
    input  wire [      2:0] lsb_len,
    input  wire [`DATA_WID] lsb_w_data,
    output reg              lsb_done,
    output reg  [`DATA_WID] lsb_r_data
);
    //for iCache
    reg [7:0] if_data_arr [`MEM_CTRL_IF_DATA_LEN-1:0];

    genvar _i;
    generate
        for(_i=0;_i<`MEM_CTRL_IF_DATA_LEN;_i=_i+1) begin
            assign if_data[_i*8+7:_i*8]=if_data_arr[_i];
        end
    endgenerate

    localparam IDLE=0,IFETCH=1,LOAD=2,STORE=3;
    reg [1:0]               stat;
    reg [`MEM_CTRL_LEN_WID] pos;
    reg [`MEM_CTRL_LEN_WID] len;
    reg [`ADDR_WID]         store_addr;
    
    always @(posedge clk) begin
        if(rst) begin
            stat<=IDLE;
            if_done<=0;
            lsb_done<=0;
            mem_rw<=0;
            mem_addr<=0;
        end else if(!rdy) begin
            if_done<=0;
            lsb_done<=0;
            mem_rw<=0;
            mem_addr<=0;
        end else begin
            case(stat)
                IDLE: begin //remember 1 cycle delay, so if something_done then wait 1 cycle
                    if(if_done||lsb_done||rollback) begin
                        if_done<=0;
                        lsb_done<=0;
                    end else if(lsb_en) begin
                        if(lsb_rw) begin
                            stat<=STORE;
                            store_addr<=lsb_addr;
                        end else begin
                            stat<=LOAD;
                            mem_addr<=lsb_addr;
                            lsb_r_data<=0;
                        end
                        pos<=0;
                        len<={4'b0,lsb_len};
                    end else if(if_en) begin
                        stat<=IFETCH;
                        mem_addr<=if_pc;
                        pos<=0;
                        len<=`MEM_CTRL_IF_DATA_LEN;
                    end
                end
                IFETCH: begin //remember 1 cycle delay
                    if_data_arr[pos-1]<=mem_in; 
                    if(pos+1==len) mem_addr<=0;
                    else mem_addr<=mem_addr+1;
                    if(pos==len) begin
                        mem_addr<=0;
                        mem_rw<=0;
                        if_done<=1;
                        stat<=IDLE;
                        pos<=0;
                    end else begin
                        pos<=pos+1;
                    end
                end
                LOAD: begin //remember 1 cycle delay
                    if (rollback) begin //instruction covered
                        mem_rw<=0;
                        mem_addr<=0;
                        lsb_done<=0;
                        stat<=IDLE;
                        pos<=0;
                    end else begin
                        case (pos)
                            1: lsb_r_data[7:0]<=mem_in;
                            2: lsb_r_data[15:8]<=mem_in;
                            3: lsb_r_data[23:16]<=mem_in;
                            4: lsb_r_data[31:24]<=mem_in;
                        endcase
                        if(pos+1==len) mem_addr<=0;
                        else mem_addr<=mem_addr+1;
                        if(pos==len) begin
                            mem_addr<=0;
                            mem_rw<=0;
                            lsb_done<=1;
                            stat<=IDLE;
                            pos<=0;
                        end else begin
                            pos<=pos+1;
                        end
                    end
                end
                STORE: begin
                    mem_rw<=1;
                    case (pos)
                        0: mem_out<=lsb_w_data[7:0];
                        1: mem_out<=lsb_w_data[15:8];
                        2: mem_out<=lsb_w_data[23:16];
                        3: mem_out<=lsb_w_data[31:24];
                    endcase
                    if(pos==0) mem_addr<=store_addr;
                    else mem_addr<=mem_addr+1;
                    if(pos==len) begin
                        mem_addr<=0;
                        mem_rw<=0;
                        lsb_done<=1;
                        stat<=IDLE;
                        pos<=0;
                    end else begin
                        pos<=pos+1;
                    end
                end 
            endcase
        end
    end
endmodule
`endif