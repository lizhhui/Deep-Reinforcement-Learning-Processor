// pmem_fake: a fake synchronous psum memory

module pmem_fake
#(parameter
	PDATA_WIDTH = 16,
	ADDR_WIDTH = 8 // depth = 256, 256B
	)
(
  // inputs
  input i_clk, 
  input i_wr_en,
  input i_rd_en, 
  input [ADDR_WIDTH-1:0] i_wr_addr,
  input [PDATA_WIDTH-1:0] i_wr_data,   
  input [ADDR_WIDTH-1:0] i_rd_addr,
    
  //output
  output wire [PDATA_WIDTH-1:0] o_rd_data
);


// Here for the fake memory, only 16 will be implemented
reg [PDATA_WIDTH-1:0] REG [0:63];
reg [ADDR_WIDTH-1:0] rd_addr;

always @ (posedge i_clk) begin
 	if(i_rd_en) 
     rd_addr <= i_rd_addr;
  else
     rd_addr <= 8'bx;
end

assign o_rd_data = REG[rd_addr];


always @ (posedge i_clk) begin
  if(i_wr_en) 
    // Write behavior
    REG[i_wr_addr] <= i_wr_data;
end

endmodule