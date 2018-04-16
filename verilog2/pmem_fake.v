// pmem_fake: a fake synchronous psum memory

module pmem_fake
#(parameter
	DATA_WIDTH = 8,
	ADDR_WIDTH = 8, // depth = 256, 256B
  TOTAL_DATA_WIDTH = DATA_WIDTH*3
	)
(
  // inputs
  input i_clk, 
  input i_wr_en,
  input [ADDR_WIDTH-1:0] i_wr_addr0,
  input [DATA_WIDTH-1:0] i_wr_data0, 
  input [ADDR_WIDTH-1:0] i_wr_addr1,
  input [DATA_WIDTH-1:0] i_wr_data1, 
  input i_rd_en,   
  input [ADDR_WIDTH-1:0] i_rd_addr0,
  input [ADDR_WIDTH-1:0] i_rd_addr1, 
    
  //output
  output wire [DATA_WIDTH-1:0] o_rd_data0,
  output wire [DATA_WIDTH-1:0] o_rd_data1
);


// Here for the fake memory, only 16 will be implemented
reg [DATA_WIDTH-1:0] REG [0:15];

// Read behavior
assign o_rd_data0 = i_rd_en? REG[i_rd_addr0] : 0;
assign o_rd_data1 = i_rd_en? REG[i_rd_addr1] : 0;


// Write behavior
always @ (posedge i_clk) begin
 	if(i_wr_en) begin
    REG[i_wr_addr0] <= i_wr_data0;
    REG[i_wr_addr1] <= i_wr_data1;
  end
end

endmodule