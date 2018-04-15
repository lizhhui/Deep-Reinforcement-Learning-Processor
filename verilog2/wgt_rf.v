// wgt_rf
// for a ROW

module wgt_rf
#(parameter
  DATA_WIDTH = 8,
	ROW_NUM = 6,
  ROW_WGT_WIDTH = DATA_WIDTH*ROW_NUM
	)
(
  input i_clk, 
  input i_wr_en,
  input [ROW_WGT_WIDTH-1:0] i_wgt_row,  

  output reg [ROW_WGT_WIDTH-1:0] o_wgt_row
);


  // Write behavior
  always @ (posedge i_clk) begin
    if(i_wr_en) begin
      o_wgt_row <= i_wgt_row;
    end
  end

endmodule