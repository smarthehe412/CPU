`ifndef IFETCH
`define IFETCH
module IFetch (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rs_nxt_full,
    input wire lsb_nxt_full,
    input wire rob_nxt_full,

    output reg             inst_rdy,
    output reg [`INST_WID] inst,
    output reg [`ADDR_WID] inst_pc,
    output reg             inst_pred_jump,

    output reg                 mc_en,
    output reg  [   `ADDR_WID] mc_pc,
    input  wire                mc_done,
    input  wire [`IF_DATA_WID] mc_data,

    input wire             rob_set_pc_en,
    input wire [`ADDR_WID] rob_set_pc,
    input wire             rob_br,
    input wire             rob_br_jump,
    input wire [`ADDR_WID] rob_br_pc
);

endmodule