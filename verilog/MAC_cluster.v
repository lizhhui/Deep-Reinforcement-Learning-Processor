// MAC_cluster
// Author: Frank Peng
// Create Date: Mar.26, 2018

module MAC_cluster
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
	input in_en,
	input [TOTAL_INPUT_WIDTH-1:0] in_data,
	input [TOTAL_INPUT_WIDTH-1:0] in_weights,
	input signed [DATA_WIDTH-1:0] in_bias,
	input in_add_bias, // 1: add bias, 0: no bias
	input in_relu, // 1: w/ relu, 0: w/o relu
	input in_done, // the flag for the last partial sum
	input in_cache_clear,
	input in_cache_wr_en,
	input [4:0] in_cache_rd_addr,
	input [4:0] in_cache_wr_addr,
	input [TOTAL_OUTPUT_WIDTH-1:0] in_psum,

	// outputs
	// output reg signed [DATA_WIDTH*2+4:0] out_psum_0,
	// output reg signed [DATA_WIDTH*2+4:0] out_psum_1,
	// output reg signed [DATA_WIDTH*2+4:0] out_psum_2,
	// output reg signed [DATA_WIDTH*2+4:0] out_psum_3,
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
reg signed [TOTAL_OUTPUT_WIDTH-1:0] total_sum;
// reg signed [TOTAL_OUTPUT_WIDTH-1:0] local_psum;

assign psum_0 = result[0] + result[1] + result[2] + result[3];
assign psum_1 = result[4] + result[5] + result[6] + result[7];
assign psum_2 = result[8] + result[9] + result[10] + result[11];
assign psum_3 = result[12] + result[13] + result[14] + result[15];


// reg [4:0] cache_wr_addr;
// reg [4:0] cache_rd_addr;
reg signed [TOTAL_OUTPUT_WIDTH-1:0] cache_wr_data;
wire signed [TOTAL_OUTPUT_WIDTH-1:0] cache_rd_data;
wire signed [DATA_WIDTH-1:0] bias;

// always@(*) begin
// 	cache_rd_addr = 5'bxxxxx;
// 	cache_wr_addr = in_cache_wr_addr;
// 	cache_rd_addr = in_cache_rd_addr;
// 	// if (in_done) cache_wr_data = 0;
// 	// else cache_wr_data = out_total_sum;
// end
assign bias = in_add_bias? in_bias:0;


always @(*) begin
    if (~in_en) begin
        total_sum = bias + in_psum;
    end
    else begin
    	total_sum = psum_0 + psum_1 + psum_2 + psum_3 + bias + in_psum;
    end
end
// always @(*) begin
//     if (~in_en) begin
//         total_sum = bias + cache_rd_data;
//     end
//     else begin
//     	total_sum = psum_0 + psum_1 + psum_2 + psum_3 + bias + cache_rd_data;
//     end
// end

// assign total_sum = psum_0 + psum_1 + psum_2 + psum_3 + bias + cache_rd_data;

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		// reset
		out_total_sum <= 0;
		// out_psum_0 <= 0;
		// out_psum_1 <= 0;
		// out_psum_2 <= 0;
		// out_psum_3 <= 0;
	end
	else begin
		if (in_done) begin
			if (in_relu) out_total_sum <= (total_sum>0)? total_sum : 0;
			else out_total_sum <= total_sum;
			cache_wr_data <= 0;
		end
		else begin
			out_total_sum <= total_sum;
			cache_wr_data <= total_sum;
		end
		// out_total_sum <= total_sum;
		// out_psum_0 <= psum_0;
		// out_psum_1 <= psum_1;
		// out_psum_2 <= psum_2;
		// out_psum_3 <= psum_3;
	end
end

local_cache lc(
	.rd_data(cache_rd_data),
	.rd_addr(in_cache_rd_addr),
	.wr_addr(in_cache_wr_addr),
	.wr_data(cache_wr_data),
	.wr_en(in_cache_wr_en),
	.clear(in_cache_clear),
	.clk(clk)
	);

endmodule


module local_cache
#(parameter
	DATA_WIDTH = 8,
	NUM_MAC4 = 16,
	TOTAL_INPUT_WIDTH = NUM_MAC4*4*DATA_WIDTH,
	TOTAL_OUTPUT_WIDTH = DATA_WIDTH*2+6
	)
(
   output reg [TOTAL_OUTPUT_WIDTH-1:0] rd_data, // Read output
   input [4:0]       rd_addr, // Read address
   input [4:0]       wr_addr,   // Write address
   input [TOTAL_OUTPUT_WIDTH-1:0]      wr_data,   // Write data
   input             wr_en,     // Write enable (high true)
   input 			 clear,
   input             clk        // Clock	
);

   reg [TOTAL_OUTPUT_WIDTH-1:0] REG [0:31];

   // Read behavior
   // - High Z if the address is greater than 12
   always@ (*) begin
      rd_data = REG[rd_addr];
   end

   // Write behavior
   always @ (posedge clk or negedge clear) begin
   	if (!clear) begin
   		REG[31]<=16'b0;
		REG[30]<=16'b0;
		REG[29]<=16'b0;
		REG[28]<=16'b0;
		REG[27]<=16'b0;
		REG[26]<=16'b0;
		REG[25]<=16'b0;
		REG[24]<=16'b0;
		REG[23]<=16'b0;
		REG[22]<=16'b0;
		REG[21]<=16'b0;
		REG[20]<=16'b0;
		REG[19]<=16'b0;
		REG[18]<=16'b0;
		REG[17]<=16'b0;
		REG[16]<=16'b0;
		REG[15]<=16'b0;
		REG[14]<=16'b0;
		REG[13]<=16'b0;
		REG[12]<=16'b0;
		REG[11]<=16'b0;
		REG[10]<=16'b0;
		REG[9]<=16'b0;
		REG[8]<=16'b0;
		REG[7]<=16'b0;
		REG[6]<=16'b0;
		REG[5]<=16'b0;
		REG[4]<=16'b0;
		REG[3]<=16'b0;
		REG[2]<=16'b0;
		REG[1]<=16'b0;
		REG[0]<=16'b0;
   	end
   	else begin
      if(wr_en) REG[wr_addr] <= wr_data;
    end
   end

endmodule