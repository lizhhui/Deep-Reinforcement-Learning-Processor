module drlp_relu
#(parameter DATA_WIDTH = 16)
(
	input [DATA_WIDTH-1:0] i_data0,
	input [DATA_WIDTH-1:0] i_data1,
	input i_relu,
	output wire [DATA_WIDTH-1:0] o_data0,
	output wire [DATA_WIDTH-1:0] o_data1
	);
	
	assign o_data0 = ((i_relu==1)&&(i_data0[15]==1))?0:i_data0;
	assign o_data1 = ((i_relu==1)&&(i_data1[15]==1))?0:i_data1;

endmodule