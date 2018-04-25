module nn_relu
#(parameter DATA_WIDTH = 8)
(
	input [DATA_WIDTH-1:0] i_data0,
	input [DATA_WIDTH-1:0] i_data1,
	input i_relu,
	output wire [DATA_WIDTH-1:0] o_data0,
	output wire [DATA_WIDTH-1:0] o_data1
	);
	
	assign o_data0 = (i_relu&&(o_data0[7]))?0:i_data0;
	assign o_data1 = (i_relu&&(o_data1[7]))?0:i_data1;

endmodule