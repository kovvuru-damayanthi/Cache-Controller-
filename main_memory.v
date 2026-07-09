module main_memory(
    input clk,
    input we,
    input [7:0] addr,
    input [31:0] wdata,
    output reg [31:0] rdata
);

reg [31:0] mem [0:255];

integer i;

initial
begin
    for(i=0;i<256;i=i+1)
        mem[i] = i;
end

always @(posedge clk)
begin
    if(we)
        mem[addr] <= wdata;

    rdata <= mem[addr];
end

endmodule
