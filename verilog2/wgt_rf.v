// wgt_rf
// for a row

module wgt_rf
#(parameter
  DATA_WIDTH = 8,
	NUM_ROW = 6,
  TOTAL_WIDTH = DATA_WIDTH*NUM_ROW
	)
(
  input i_clk, 
  input i_wr_en,
  input [TOTAL_WIDTH-1:0] i_wgt_row,  

  output reg [TOTAL_WIDTH-1:0] o_wgt_row
);


  // Write behavior
  always @ (posedge i_clk) begin
    if(i_wr_en) begin
      o_wgt_row <= i_wgt_row;
    end
  end

endmodule