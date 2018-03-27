// PU: A processing unit which consists of MAC_cluster, weigiht memory, and result memory
// Author: Frank Peng
// Create Date: Mar.27, 2018

module PU
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

wire [TOTAL_INPUT_WIDTH-1:0] weights, all_bias;
reg [DATA_WIDTH-1:0] bias;

always @(*) begin
	case(in_bias_addr)
        3'd0: bias = all_bias[DATA_WIDTH-1:0];
        3'd1: bias = all_bias[2*DATA_WIDTH-1:DATA_WIDTH];
        3'd2: bias = all_bias[3*DATA_WIDTH-1:2*DATA_WIDTH];
        3'd3: bias = all_bias[4*DATA_WIDTH-1:3*DATA_WIDTH];
        3'd4: bias = all_bias[5*DATA_WIDTH-1:4*DATA_WIDTH];
        3'd5: bias = all_bias[6*DATA_WIDTH-1:5*DATA_WIDTH];
        3'd6: bias = all_bias[7*DATA_WIDTH-1:6*DATA_WIDTH];
        3'd7: bias = all_bias[8*DATA_WIDTH-1:7*DATA_WIDTH];
        default: bias = 0;
	endcase
end

MAC_cluster mac(
	.clk(clk),
	.rst_n(rst_n),
	.in_data(in_data),
	.in_weights(weights),
	.in_bias(bias),
	.in_add_bias(in_add_bias),
	.in_relu(in_relu), // 1: w/ relu, 0: w/o relu
	.in_done(in_done), // the flag for the last partial sum
	.in_cache_clear(in_cache_clear),
	.in_cache_rd_addr(in_cache_rd_addr),
	.in_cache_wr_addr(in_cache_wr_addr),
	.out_total_sum(out_total_sum)
	);

wmem_fake wmem(
 	.clk(clk), 
 	.in_wr_en(in_w_wr_en),
 	.in_wr_addr(in_w_wr_addr),
 	.in_wr_data(in_w_wr_data), 
 	.in_rd_en(1'b1),   
 	.in_rd_addr(in_r_rd_addr),
 	.out_bias(all_bias),
    .out_rd_data(weights)
	);

rmem_fake rmem(
 	.clk(clk), 
 	.in_wr_en(in_r_wr_en),
 	.in_wr_addr(in_r_wr_addr),
 	.in_wr_data(out_total_sum), 
 	.in_rd_en(in_r_rd_en),   
 	.in_rd_addr(in_r_rd_addr), 
    .out_rd_data(out_rmem)
	);

endmodule