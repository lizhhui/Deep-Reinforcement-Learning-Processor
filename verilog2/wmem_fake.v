// wmem_fake: a fake weights memory

module wmem_fake
#(parameter
  DATA_WIDTH = 8,
	ROW_NUM = 6,
	ADDR_WIDTH = 7, // depth = 128, 0.75 KB
	ROW_WGT_WIDTH = DATA_WIDTH*ROW_NUM
	)
(
  input i_clk, 
  input i_wr_en,
  input [ADDR_WIDTH-1:0] i_wr_addr,
  input [ROW_WGT_WIDTH-1:0] i_wr_data, 
  input i_rd_en,   
  input [ADDR_WIDTH-1:0] i_rd_addr, 

  output wire [ROW_WGT_WIDTH-1:0] o_bias,
  output reh [ROW_WGT_WIDTH-1:0] o_rd_data
);


// Here for the fake memory, only 4 will be implemented
reg [ROW_WGT_WIDTH-1:0] REG [0:3];

assign o_bias = REG[3];

always @ (posedge i_clk) begin
 	if(i_wr_en) REG[i_wr_addr] <= i_wr_data; // Write behavior
  else o_rd_data <= REG[i_rd_addr]; // Read behavior
end

endmodule