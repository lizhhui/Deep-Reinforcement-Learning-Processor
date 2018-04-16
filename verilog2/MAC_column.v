// MAC_column

module MAC_column
#(parameter
	DATA_WIDTH = 8,
	COLUMN_NUM = 6,
	COLUMN_DATA_WIDTH = DATA_WIDTH*COLUMN_NUM,
	OUT_WIDTH = 2*DATA_WIDTH,
	COLUMN_OUT_WIDTH = OUT_WIDTH+3
	)
(
	input [COLUMN_DATA_WIDTH-1:0] i_img_column,
	input signed [COLUMN_DATA_WIDTH-1:0] i_wgt_column,
	// input signed [OUT_WIDTH-1:0] i_psum_column,

	output wire signed [COLUMN_OUT_WIDTH-1:0] o_psum_column
	);


	wire signed [OUT_WIDTH-1:0] MAC_psum[0:COLUMN_NUM-1];

	generate
		genvar i;
		for (i = 0; i < COLUMN_NUM; i = i + 1)
		begin: one_MAC_colum
			mult mult_inst(
				.i_img(i_img_column[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH]),
				.i_wgt(i_wgt_column[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH]),
				.o_psum(MAC_psum[i])
				);
		end
	endgenerate

	assign  o_psum_column = MAC_psum[0]+MAC_psum[1]+MAC_psum[2]+MAC_psum[3]+MAC_psum[4]+MAC_psum[5];
		
endmodule