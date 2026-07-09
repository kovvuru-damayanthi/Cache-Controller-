`include "cache_top.v"
module cache_tb;
    reg clk;
    reg rst;
    reg rd;
    reg wr;
    reg [7:0] addr;
    reg [31:0] wdata;

    wire [31:0] rdata;
    wire hit;
    wire ready;

    cache_top DUT(
       .clk(clk),
       .rst(rst),
       .cpu_rd(rd),
       .cpu_wr(wr),
       .addr(addr),
       .wdata(wdata),
       .rdata(rdata),
       .hit(hit),
      .ready(ready)
        // if your top doesn't have ready, remove it
    );

    always #5 clk = ~clk;

    initial begin

        clk = 0; rst = 1; rd = 0; wr = 0; addr = 0; wdata = 0;
        #20 rst = 0;
        #10;

        // Test 1: Read miss, addr 0x12
        @(posedge clk);
        addr <= 8'h12; rd <= 1;
        wait(hit || DUT.DUT.state == 3'd6); // wait for REFILL
        @(posedge clk); rd <= 0;
        $display("T=%0t Read miss 0x12: hit=%b data=%h", $time, hit, rdata);

        #20;

        // Test 2: Read hit, same addr 0x12
        @(posedge clk);
        addr <= 8'h12; rd <= 1;
        @(posedge clk); // hit is 1 cycle
        $display("T=%0t Read hit 0x12: hit=%b data=%h", $time, hit, rdata);
        rd <= 0;

        #20;

        // Test 3: Write miss, addr 0x34
        @(posedge clk);
        addr <= 8'h34; wr <= 1; wdata <= 32'hDEADBEEF;
        wait(DUT.DUT.state == 3'd6); // wait REFILL
        @(posedge clk); wr <= 0;
        $display("T=%0t Write miss 0x34 done", $time);

        #20;

        // Test 4: Read hit after write
        @(posedge clk);
        addr <= 8'h34; rd <= 1;
        @(posedge clk);
        $display("T=%0t Read hit 0x34: hit=%b data=%h", $time, hit, rdata);
        rd <= 0;

        #50;
        $finish;
    end
initial
begin
$fsdbDumpfile("cache_top.fsdb");
$fsdbDumpvars(0, cache_tb);
end
endmodule
