module PU_tb
#(parameter
	DATA_WIDTH = 8,
	NUM_MAC4 = 16,
	TOTAL_INPUT_WIDTH = NUM_MAC4*4*DATA_WIDTH,
	TOTAL_OUTPUT_WIDTH = DATA_WIDTH*2+6,
	WADDR_WIDTH = 7, // depth = 128, 8KB
	RADDR_WIDTH = 6 // depth = 64, 176B
	)
(
	// inputs
	input clk,
	input rst_n,

	// to MAC_cluster
	input [TOTAL_INPUT_WIDTH-1:0] in_data,
	input in_add_bias, // 1: add bias, 0: no bias
	input in_relu, // 1: w/ relu, 0: w/o relu
	input in_done, // the flag for the last partial sum
	input in_cache_clear,
	input [4:0] in_cache_rd_addr,
	input [4:0] in_cache_wr_addr,

	// to wmem
	input in_w_wr_en,
	input [WADDR_WIDTH-1:0] in_w_wr_addr,
	input [TOTAL_INPUT_WIDTH-1:0] in_w_wr_data,  
	input [WADDR_WIDTH-1:0] in_w_rd_addr,
	input [2:0] in_bias_addr,

	// to rmem
	input in_r_wr_en,
	input [WADDR_WIDTH-1:0] in_r_wr_addr,
	input in_r_rd_en,   
	input [WADDR_WIDTH-1:0] in_r_rd_addr,

	// outputs
	output wire signed [TOTAL_OUTPUT_WIDTH-1:0] out_total_sum,
	output wire signed [TOTAL_OUTPUT_WIDTH-1:0] out_rmem

	);