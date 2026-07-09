`include "cache_mem.v"
`include "tag_mem.v"
`include "valid_mem.v"
`include "main_memory.v"
module cache_controller #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter INDEX_BITS = 2, // 4 lines
    parameter OFFSET_BITS = 0,
    parameter TAG_BITS = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS
)(
    input clk,
    input rst,
    input cpu_rd,
    input cpu_wr,
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] cpu_wdata,
    output reg [DATA_WIDTH-1:0] cpu_rdata,
    output reg hit,
    output reg ready
);

    localparam INIT = 3'd0;
    localparam IDLE = 3'd1;
    localparam TAG_COMP = 3'd2;
    localparam HIT = 3'd3;
    localparam MISS = 3'd4;
    localparam WAIT_MEM = 3'd5;
    localparam REFILL = 3'd6;

    reg [2:0] state, next_state;
    localparam NUM_LINES = 1 << INDEX_BITS;

    // Cache memories
    reg [TAG_BITS-1:0] tag_mem [0:NUM_LINES-1];
    reg valid_mem [0:NUM_LINES-1];
    reg [DATA_WIDTH-1:0] data_mem [0:NUM_LINES-1];

    // Address breakdown
    wire [INDEX_BITS-1:0] index = addr[INDEX_BITS+OFFSET_BITS-1 : OFFSET_BITS];
    wire [TAG_BITS-1:0] addr_tag = addr[ADDR_WIDTH-1 : INDEX_BITS+OFFSET_BITS];

    // Tag compare
    wire tag_match = (tag_mem[index] == addr_tag) && valid_mem[index];

    // Main memory model
    reg [DATA_WIDTH-1:0] main_memory [0:255];
    reg mem_data_valid;
    reg [DATA_WIDTH-1:0] mem_rdata;
    reg [ADDR_WIDTH-1:0] saved_addr;
    reg [1:0] mem_cnt;

    integer i;
    initial begin
        for(i=0; i<256; i=i+1) main_memory[i] = i;
        for(i=0; i<NUM_LINES; i=i+1) begin
            valid_mem[i] = 1'b0;
            tag_mem[i] = {TAG_BITS{1'b0}};
            data_mem[i] = {DATA_WIDTH{1'b0}};
        end
    end

    // FSM state register
    always @(posedge clk or posedge rst) begin
        if (rst) state <= INIT;
        else state <= next_state;
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case(state)
            INIT: next_state = IDLE;
            IDLE: next_state = (cpu_rd | cpu_wr)? TAG_COMP : IDLE;
            TAG_COMP: next_state = tag_match? HIT : MISS;
            HIT: next_state = IDLE;
            MISS: next_state = WAIT_MEM;
            WAIT_MEM: next_state = mem_data_valid? REFILL : WAIT_MEM;
            REFILL: next_state = IDLE;
            default: next_state = INIT;
        endcase
    end

    // Main memory model - 2 cycle latency
    always @(posedge clk) begin
        if (state == MISS) begin
            mem_cnt <= 2'd2;
            mem_data_valid <= 1'b0;
            saved_addr <= addr;
        end else if (mem_cnt!= 0) begin
            mem_cnt <= mem_cnt - 1'b1;
            if (mem_cnt == 1) begin
                mem_rdata <= main_memory[saved_addr];
                mem_data_valid <= 1'b1;
            end
        end else begin
            mem_data_valid <= 1'b0;
        end
    end

    // Cache control + outputs
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hit <= 1'b0;
            ready <= 1'b0;
            cpu_rdata <= 32'b0;
        end else begin
            hit <= 1'b0;
            ready <= 1'b0;

            case(state)
                IDLE: ready <= 1'b1;

                HIT: begin
                    hit <= 1'b1;
                    ready <= 1'b1;
                    if (cpu_rd)
                        cpu_rdata <= data_mem[index];
                    if (cpu_wr) begin // write-through
                        data_mem[index] <= cpu_wdata;
                        main_memory[addr] <= cpu_wdata; // Fixed line
                    end
                end

                REFILL: begin
                    valid_mem[index] <= 1'b1;
                    tag_mem[index] <= addr_tag;
                    if (cpu_wr) begin
                        data_mem[index] <= cpu_wdata;
                        main_memory[saved_addr] <= cpu_wdata; // Fixed line
                        cpu_rdata <= cpu_wdata;
                    end else begin
                        data_mem[index] <= mem_rdata;
                        cpu_rdata <= mem_rdata;
                    end
                end
            endcase
        end
    end
endmodule

