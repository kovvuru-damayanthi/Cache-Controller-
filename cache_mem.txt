module cache_mem(
    input clk,
    input we,
    input [3:0] index,
    input [31:0] wdata,
    output reg [31:0] rdata
);

reg [31:0] data_mem [0:15];

always @(posedge clk)
begin
    if(we)
        data_mem[index] <= wdata;

    rdata <= data_mem[index];
end

endmodule
