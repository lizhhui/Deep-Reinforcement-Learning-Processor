// nn_img_bf: a fake synchronous image buffer

module nn_img_bf
#(parameter
	DATA_WIDTH = 8,
	ADDR_WIDTH = 10, // depth = 1024, 4KB
  TOTAL_DATA_WIDTH = DATA_WIDTH*6
	)
(
  input i_clk, 
  input i_wr_en,
  input [ADDR_WIDTH-1:0] i_wr_addr0,
  input [TOTAL_DATA_WIDTH-1:0] i_wr_data0, 
  // input [ADDR_WIDTH-1:0] i_wr_addr1,
  // input [TOTAL_DATA_WIDTH-1:0] i_wr_data1, 
  input i_rd_en,   
  input [ADDR_WIDTH-1:0] i_rd_addr0,
  // input [ADDR_WIDTH-1:0] i_rd_addr1, 

  output reg [TOTAL_DATA_WIDTH-1:0] o_rd_data0
  // output wire [TOTAL_DATA_WIDTH-1:0] o_rd_data1
);


// Here for the fake memory, only 16 will be implemented
reg [TOTAL_DATA_WIDTH-1:0] REG [0:15];


always @ (posedge i_clk) begin
 	if(i_wr_en) begin
    // Write behavior
    REG[i_wr_addr0] <= i_wr_data0;
  end
  else begin
    // Read behavior
    o_rd_data0 = REG[i_rd_addr0];
  end
end

endmodule