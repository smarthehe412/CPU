`ifndef ALU
`define ALU
`include "cons.v"
module ALU (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rollback,

    // from Reservation Station
    input wire                alu_en,
    input wire [ `OPCODE_WID] opcode,
    input wire [  `FUNC3_WID] func3, //14-12
    input wire                func7, //30
    input wire [   `DATA_WID] val1,
    input wire [   `DATA_WID] val2,
    input wire [   `DATA_WID] imm, //sext-ed
    input wire [   `ADDR_WID] pc,
    input wire [`ROB_POS_WID] rob_pos,

    // broadcast result
    output reg                result,
    output reg [`ROB_POS_WID] result_rob_pos,
    output reg [   `DATA_WID] result_val,
    output reg                result_jump,
    output reg [   `ADDR_WID] result_pc
);

    wire [`DATA_WID] calc1=val1,
    wire [`DATA_WID] calc2=opcode==`OPCODE_ARITH ? val2 : imm, //is imm or not
    wire [`DATA_WID] res;
    always @(*) begin
        case(func3)
            `FUNC3_ADD:
                if(opcode==`OPCODE_ARITH && func7) res=calc1-calc2; //SUB
                else      res=calc1+calc2; //ADD
            `FUNC3_XOR:   res=calc1^calc2;
            `FUNC3_OR:    res=calc1|calc2;
            `FUNC3_AND:   res=calc1&calc2;
            `FUNC3_SLL:   res=calc1<<calc2[5:0];
            `FUNC3_SRL:
                if(func7) res=$signed(calc1)>>calc2[5:0]; //SRA
                else      res=calc1>>calc2[5:0]; //SRL
            `FUNC3_SLT:   res=$signed(calc1)<$signed(calc2);
            `FUNC3_SLTU:  res=calc1<calc2;
        endcase
    end

    reg is_branch;
    always @(*) begin
        case(func3)
            `FUNC3_BEQ: is_branch=val1==val2;
            `FUNC3_BNE: is_branch=val1!=val2;
            `FUNC3_BLT: is_branch=$signed(val1)<$signed(val2);
            `FUNC3_BGE: is_branch=$signed(val1)>=$signed(val2);
            `FUNC3_BLTU: is_branch=val1<val2;
            `FUNC3_BGEU: is_branch=val1>=val2;
        endcase
    end

    always @(posedge clk) begin
        if(rst||rollback) begin
            result<=0;
            result_rob_pos<=0;
            result_val<=0;
            result_jump<=0;
            result_pc<=0;
        end else if (!rdy) begin
            ;
        end else begin
            case(opcode)
                `OPCODE_ARITH,`OPCODE_ARITHI: result_val<=res;
                `OPCODE_BR:
                    if(is_branch) begin
                        result_jump<=1;
                        result_pc<=pc+imm;
                    end else begin
                        result_jump<=0;
                        result_pc<=pc+4;
                    end
                `OPCODE_LUI: result_val<=imm; //imm shifted
                `OPCODE_AUIPC: result_val<=pc+imm
                `OPCODE_JAL: begin
                    result_jump<=1;
                    result_val<=pc+4;
                    result_pc<=pc+imm;
                end
                `OPCODE_JALR: begin
                    result_jump<=1;
                    result_val<=pc+4;
                    result_pc<=(val1+imm)&(~1);
                end
            endcase
        end
    end
    
endmodule //ALU
 