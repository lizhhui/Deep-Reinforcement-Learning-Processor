// Testbench for PU
module tb_PU();

reg clk, rst_n;
reg in_mac_en;
reg [511:0] in_data;
reg in_add_bias, in_relu, in_done, in_cache_clear, in_cache_wr_en;
reg [4:0] in_cache_rd_addr, in_cache_wr_addr;
reg in_w_wr_en;
reg [6:0] in_w_wr_addr;
reg [511:0] in_w_wr_data;  
reg [6:0] in_w_rd_addr;
reg [2:0] in_bias_addr;

reg in_r_wr_en;
reg [6:0] in_r_wr_addr;
reg in_r_rd_en;   
reg [6:0] in_r_rd_addr;

wire signed [21:0] out_total_sum;
wire signed [21:0] out_rmem;


PU #(
	.DATA_WIDTH(8),
	.NUM_MAC4(16),
	// .TOTAL_INPUT_WIDTH = NUM_MAC4*4*DATA_WIDTH,
	// .TOTAL_OUTPUT_WIDTH = DATA_WIDTH*2+6,
	.WADDR_WIDTH(7),
	.RADDR_WIDTH(6)
	)
PU_inst(
	.clk(clk),
	.rst_n(rst_n),

	// to MAC_cluster
	.in_mac_en(in_mac_en),
	.in_data(in_data),
	.in_add_bias(in_add_bias), // 1: add bias, 0: no bias
	.in_relu(in_relu), // 1: w/ relu, 0: w/o relu
	.in_done(in_done), // the flag for the last partial sum
	.in_cache_clear(in_cache_clear),
	.in_cache_wr_en(in_cache_wr_en),
	.in_cache_rd_addr(in_cache_rd_addr),
	.in_cache_wr_addr(in_cache_wr_addr),

	// to wmem
	.in_w_wr_en(in_w_wr_en),
	.in_w_wr_addr(in_w_wr_addr),
	.in_w_wr_data(in_w_wr_data),  
	.in_w_rd_addr(in_w_rd_addr),
	.in_bias_addr(in_bias_addr),

	// to rmem
	.in_r_wr_en(in_r_wr_en),
	.in_r_wr_addr(in_r_wr_addr),
	.in_r_rd_en(in_r_rd_en),   
	.in_r_rd_addr(in_r_rd_addr),

	// outputs
	.out_total_sum(out_total_sum),
	.out_rmem(out_rmem)

	);

initial begin
	clk = 1'b0;
	rst_n = 1'b1;
	in_cache_clear = 1'b1;
	repeat(2) #10 clk = ~clk;
	rst_n = 1'b0;
	in_cache_clear = 1'b0;
	repeat(2) #10 clk = ~clk;
	rst_n = 1'b1;
	in_cache_clear = 1'b1;
	forever #10 clk = ~clk;
end

initial begin
	in_mac_en = 1'b0;
	in_data = 512'b0;
	in_add_bias = 1'b0;
	in_relu = 1'b0;
	in_done = 1'b0;
	in_cache_wr_en = 1'b0;
	in_cache_rd_addr = 5'b0; 
	in_cache_wr_addr = 5'b0;

	in_w_wr_en = 1'b0;
	in_w_wr_addr = 7'b0;
	in_w_wr_data = 512'b0;  
	in_w_rd_addr = 7'b0;
	in_bias_addr = 3'b0;

	in_r_wr_en = 1'b0;
	in_r_wr_addr = 7'b0;
	in_r_rd_en = 1'b0;   
	in_r_rd_addr = 7'b0;

	#40
	@(posedge clk);
	in_mac_en = 1'b1;
  	in_w_wr_en = 1'b1;
	in_w_wr_addr = 7'b0;
	in_w_wr_data = 512'b1;
	@(posedge clk);
  	in_w_wr_en = 1'b1;
	in_w_wr_addr = 7'b1;
	in_w_wr_data = 512'b1;
	@(posedge clk);
	in_w_wr_en = 1'b0;
	in_data = 512'b1;
	in_cache_wr_en = 1'b1;
	@(posedge clk);
	in_mac_en = 1'b0;
	in_cache_wr_en = 1'b0;


end

endmodule