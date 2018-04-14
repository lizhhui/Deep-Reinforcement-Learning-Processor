// PE

module PE
#(parameter
	DATA_WIDTH = 8,
	OUT_WIDTH = 2*DATA_WIDTH + 3
	)
(
	input [DATA_WIDTH-1:0] i_img,
	input signed [DATA_WIDTH-1:0] i_wgt,
	input signed [OUT_WIDTH-1:0] i_psum,

	output wire signed [OUT_WIDTH-1:0] o_psum
	);


	assign  o_psum= i_img*i_wgt + i_psum;

endmodule