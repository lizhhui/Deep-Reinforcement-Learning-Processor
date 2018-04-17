// psum_rf: registers for colum partial sum

module psum_rf
#(parameter
	DATA_WIDTH = 8,
	ADDR_WIDTH = 5 // depth = 32
	)
(
  input i_clk, 
  input i_wr_en,
  input [ADDR_WIDTH-1:0] i_wr_addr,
  input [DATA_WIDTH-1:0] i_wr_data,   
  input [ADDR_WIDTH-1:0] i_rd_addr,

  output wire [DATA_WIDTH-1:0] o_rd_data
);


reg [DATA_WIDTH-1:0] REG [0:31];

// Read behavior
assign o_rd_data =  REG[i_rd_addr];


// Write behavior
always @ (posedge i_clk) begin
 	if(i_wr_en) begin
    REG[i_wr_addr] <= i_wr_data;
  end
end

endmodule