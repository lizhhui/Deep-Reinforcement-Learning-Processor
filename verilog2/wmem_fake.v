// wmem_fake: a fake weights memory
// Author: Frank Peng
// Create Date: Mar.27, 2018

module wmem_fake
#(parameter
  DATA_WIDTH = 8,
	NUM_MAC4 = 16,
	ADDR_WIDTH = 7, // depth = 128, 8KB
	TOTAL_INPUT_WIDTH = NUM_MAC4*4*DATA_WIDTH
	)
(
  // inputs
  input clk, 
  input in_wr_en,
  input [ADDR_WIDTH-1:0] in_wr_addr,
  input [TOTAL_INPUT_WIDTH-1:0] in_wr_data, 
  input in_rd_en,   
  input [ADDR_WIDTH-1:0] in_rd_addr, 
    
  //output to MAC_cluster
  output wire [TOTAL_INPUT_WIDTH-1:0] out_bias,
  output wire [TOTAL_INPUT_WIDTH-1:0] out_rd_data
);


// Here for the fake memory, only 2 will be implemented
reg [TOTAL_INPUT_WIDTH-1:0] REG [0:1];

// Read behavior
assign out_rd_data = in_rd_en? REG[in_rd_addr] : 0;
assign out_bias = REG[1];

// Write behavior
always @ (posedge clk) begin
 	if(in_wr_en) REG[in_wr_addr] <= in_wr_data;
end

endmodule