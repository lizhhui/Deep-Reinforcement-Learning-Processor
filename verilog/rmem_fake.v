// rmem_fake: a fake results memory
// Author: Frank Peng
// Create Date: Mar.27, 2018

module rmem_fake
#(parameter
	DATA_WIDTH = 8,
	ADDR_WIDTH = 6, // depth = 64, 176B
  TOTAL_OUTPUT_WIDTH = DATA_WIDTH*2+6
	)
(
  // inputs
  input clk, 
  input in_wr_en,
  input [ADDR_WIDTH-1:0] in_wr_addr,
  input [TOTAL_OUTPUT_WIDTH-1:0] in_wr_data, 
  input in_rd_en,   
  input [ADDR_WIDTH-1:0] in_rd_addr, 
    
  //output
  output wire [TOTAL_OUTPUT_WIDTH-1:0] out_rd_data
);


// Here for the fake memory, only 2 will be implemented
reg [TOTAL_OUTPUT_WIDTH-1:0] REG [0:1];

// Read behavior
assign out_rd_data = in_rd_en? REG[in_rd_addr] : 0;


// Write behavior
always @ (posedge clk) begin
 	if(in_wr_en) REG[in_wr_addr] <= in_wr_data;
end

endmodule