// PE
// Author: Huwan Peng
// Create Date: Mar.26, 2018

module PE
#(parameter
	DATA_WIDTH = 8,
	NUM_MAC4 = 16,
	TOTAL_INPUT_WIDTH = NUM_MAC4*4*DATA_WIDTH,
	TOTAL_OUTPUT_WIDTH = DATA_WIDTH*2+6
	)
(
	// inputs
	input clk,
	input rst_n,
	input [TOTAL_INPUT_WIDTH-1:0] in_data,
	input [TOTAL_INPUT_WIDTH-1:0] in_weights,
	input signed [DATA_WIDTH-1:0] in_bias,

	// outputs
	output reg signed [DATA_WIDTH*2+4:0] out_psum_0,
	output reg signed [DATA_WIDTH*2+4:0] out_psum_1,
	output reg signed [DATA_WIDTH*2+4:0] out_psum_2,
	output reg signed [DATA_WIDTH*2+4:0] out_psum_3,
	output reg signed [TOTAL_OUTPUT_WIDTH-1:0] out_total_sum

	);

wire signed [DATA_WIDTH*2+2:0] result[0:NUM_MAC4-1];

generate
	genvar i;
	for (i = 0; i < NUM_MAC4; i = i + 1)
	begin:MAC4_cluster
		MAC_4x8 MAC(
			.a0(in_data[i*4*DATA_WIDTH+DATA_WIDTH-1:i*4*DATA_WIDTH]),
			.a1(in_data[i*4*DATA_WIDTH+2*DATA_WIDTH-1:i*4*DATA_WIDTH+DATA_WIDTH]),
			.a2(in_data[i*4*DATA_WIDTH+3*DATA_WIDTH-1:i*4*DATA_WIDTH+2*DATA_WIDTH]),
			.a3(in_data[i*4*DATA_WIDTH+4*DATA_WIDTH-1:i*4*DATA_WIDTH+3*DATA_WIDTH]),
			.b0(in_weights[i*4*DATA_WIDTH+DATA_WIDTH-1:i*4*DATA_WIDTH]),
			.b1(in_weights[i*4*DATA_WIDTH+2*DATA_WIDTH-1:i*4*DATA_WIDTH+DATA_WIDTH]),
			.b2(in_weights[i*4*DATA_WIDTH+3*DATA_WIDTH-1:i*4*DATA_WIDTH+2*DATA_WIDTH]),
			.b3(in_weights[i*4*DATA_WIDTH+4*DATA_WIDTH-1:i*4*DATA_WIDTH+3*DATA_WIDTH]),
			// input sel, 
			.result(result[i])
			);
	end
endgenerate


wire signed [DATA_WIDTH*2+4:0] psum_0, psum_1, psum_2, psum_3;

assign psum_0 = result[0] + result[1] + result[2] + result[3];
assign psum_1 = result[4] + result[5] + result[6] + result[7];
assign psum_2 = result[8] + result[9] + result[10] + result[11];
assign psum_3 = result[12] + result[13] + result[14] + result[15];

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		// reset
		out_total_sum <= 0;
	end
	else begin
		out_total_sum <= psum_0 + psum_1 + psum_2 + psum_3 + in_bias;
		out_psum_0 <= psum_0;
		out_psum_1 <= psum_1;
		out_psum_2 <= psum_2;
		out_psum_3 <= psum_3;
	end
end

endmodule