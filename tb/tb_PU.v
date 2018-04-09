// Testbench for PU
module tb_PU
#(parameter
	DATA_WIDTH = 8,
	NUM_MAC4 = 16,
	TOTAL_INPUT_WIDTH = NUM_MAC4*4*DATA_WIDTH,
	TOTAL_OUTPUT_WIDTH = DATA_WIDTH*2+6,
	WADDR_WIDTH = 7, // depth = 128, 8KB
	RADDR_WIDTH = 6 // depth = 64, 176B
	)
(

	);

reg clk, rst_n;
reg [TOTAL_INPUT_WIDTH-1:0] in_data;
reg in_add_bias, in_relu, in_done, in_cache_clear;
reg [4:0] in_cache_rd_addr, in_cache_wr_addr;
reg in_w_wr_en;
reg [WADDR_WIDTH-1:0] in_w_wr_addr;
reg [TOTAL_INPUT_WIDTH-1:0] in_w_wr_data;  
reg [WADDR_WIDTH-1:0] in_w_rd_addr;
reg [2:0] in_bias_addr;

reg in_r_wr_en;
reg [WADDR_WIDTH-1:0] in_r_wr_addr;
reg in_r_rd_en;   
reg [WADDR_WIDTH-1:0] in_r_rd_addr;

wire signed [TOTAL_OUTPUT_WIDTH-1:0] out_total_sum;
wire signed [TOTAL_OUTPUT_WIDTH-1:0] out_rmem;


PU PU_inst(
	.clk(clk),
	.rst_n(rst_n),

	// to MAC_cluster
	.in_data(in_data),
	.in_add_bias(in_add_bias), // 1: add bias, 0: no bias
	.in_relu(in_relu), // 1: w/ relu, 0: w/o relu
	.in_done(in_done), // the flag for the last partial sum
	.in_cache_clear(in_cache_clear),
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

endmodule