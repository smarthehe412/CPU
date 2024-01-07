`ifndef MEMCTRL
`define MEMCTRL
`include "cons.v"
module MemCtrl (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rollback,

    input  wire [ 7:0] mem_in,   // data input bus
    output reg  [ 7:0] mem_out,  // data output bus
    output reg  [31:0] mem_addr,  // address bus (only 17:0 is used)
    output reg         mem_rw,    // write/read signal (1 for write)

    input wire io_buffer_full,  // 1 if uart buffer is full

    // instruction fetch
    input  wire                if_en,
    input  wire [   `ADDR_WID] if_pc,
    output reg                 if_done,
    output wire [`IF_DATA_WID] if_data,

    // Load Store Buffer
    input  wire             lsb_en,
    input  wire             lsb_rw,      // 1 = write
    input  wire [`ADDR_WID] lsb_addr,
    input  wire [      2:0] lsb_len,
    input  wire [`DATA_WID] lsb_w_data,
    output reg              lsb_done,
    output reg  [`DATA_WID] lsb_r_data
)
    //for iCache
    reg [7:0] if_data_arr[`MEM_CTRL_IF_DATA_LEN-1:0];
    genvar _i;
    generate
        for (_i=0;_i<`MEM_CTRL_IF_DATA_LEN;_i=_i+1) begin
            assign if_data[_i*8+7:_i*8]=if_data_arr[_i];
        end
    endgenerate

    localparam IDLE=0,IFETCH=1,LOAD=2,STORE=3;
    reg [1:0]               stat,
    reg [`MEM_CTRL_LEN_WID] pos,
    reg [`MEM_CTRL_LEN_WID] len;

    reg [`ADDR_WID] store_addr;
    
    always @(posedge clk) begin
        if (rst) begin
            stat<=IDLE;
            if_done<=0;
            lsb_done<=0;
            mem_rw<=0;
            mem_addr<=0;
        end else if (!rdy) begin
            if_done<=0;
            lsb_done<=0;
            mem_rw<=0;
            mem_addr<=0;
        end else begin
            case(stat)
                IDLE: begin //remember 1 cycle delay, so if something_done then wait 1 cycle
                    if(if_done||lsb_done) begin
                        if_done<=0;
                        lsb_done<=0;
                    end else if(lsb_en) begin
                        if(lsb_rw) begin
                            stat<=STORE;
                            store_addr<=lsb_addr;
                        end else begin
                            stat<=LOAD;
                            mem_addr<=lsb_addr;
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
                        len<=0;
                    end else begin
                        pos<=pos+1;
                    end
                end
                LOAD: begin //remember 1 cycle delay
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
                        len<=0;
                    end else begin
                        pos<=pos+1;
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
                        len<=0;
                    end else begin
                        pos<=pos+1;
                    end
                end 
            endcase
        end
    end
endmodule