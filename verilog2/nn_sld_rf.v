// nn_sld_rf

module nn_sld_rf
#(parameter
	DATA_WIDTH = 8,
	COLUMN_NUM = 6,
	ROW_NUM = 6,
	TOTAL_DATA_WIDTH = DATA_WIDTH*6,
	TOTAL_OUT_WIDTH = DATA_WIDTH*ROW_NUM*COLUMN_NUM
	)
(
	input i_clk,
	input i_rst,

	input [TOTAL_DATA_WIDTH-1:0] i_data,
	input i_shift,
	input [1:0] i_mode,
	input i_3x3, // 0: 3x3 high, 1: 3x3 low


	output reg [TOTAL_OUT_WIDTH-1:0] o_img

	);

	always @(posedge i_clk or negedge i_rst) begin
		if (~i_rst) begin
			o_img <= 0;
		end
		else if (shift) begin
			case (i_mode)
				2'b00: begin
					if (i_3x3)
						o_img <= {o_img[279:264], i_data[47:40], o_img[263:240],
								  o_img[231:216], i_data[39:32], o_img[215:192],
								  o_img[183:168], i_data[31:24], o_img[167:144],
								  o_img[135:120], i_data[23:16], o_img[119: 96],
								  o_img[87 : 72], i_data[15: 8], o_img[71 : 48],
								  o_img[39 : 24], i_data[7 : 0], o_img[23 :  0]};
					else
						o_img <= {o_img[287:264], o_img[255:240], i_data[47:40], 
								  o_img[239:216], o_img[207:192], i_data[39:32], 
								  o_img[191:168], o_img[159:144], i_data[31:24], 
								  o_img[143:120], o_img[111: 96], i_data[23:16],
								  o_img[95 : 72], o_img[63 : 48], i_data[15: 8],
								  o_img[47 : 24], o_img[15 :  0], i_data[7 : 0]};
				end
				2'b01: o_img <= {o_img[279:248], i_data[47:40], 
								 o_img[231:200], i_data[39:32], 
								 o_img[183:152], i_data[31:24], 
								 o_img[135:104], i_data[23:16],
								 o_img[87 : 56], i_data[15: 8],
								 o_img[39 :  8], i_data[7 : 0]};

				2'b10: o_img <= {o_img[279:248], i_data[47:40], 
								 o_img[231:200], i_data[39:32], 
								 o_img[183:152], i_data[31:24], 
								 o_img[135:104], i_data[23:16],
								 o_img[87 : 56], i_data[15: 8],
								 o_img[39 :  8], i_data[7 : 0]};

				2'b11: o_img <= {o_img[279:248], i_data[47:40], 
								 o_img[231:200], i_data[39:32], 
								 o_img[183:152], i_data[31:24], 
								 o_img[135:104], i_data[23:16],
								 o_img[87 : 56], i_data[15: 8],
								 o_img[39 :  8], i_data[7 : 0]};
				default: o_img <= o_img;
			endcase
		end
	end

endmodule