// PE

module PE
#(parameter
	DATA_WIDTH = 8,
	COLUMN_NUM = 6,
	ROW_NUM = 6,
	COLUMN_DATA_WIDTH = DATA_WIDTH*COLUMN_NUM,
	ROW_DATA_WIDTH = DATA_WIDTH*ROW_NUM,
	OUT_WIDTH = 2*DATA_WIDTH,
	COLUMN_OUT_WIDTH = OUT_WIDTH+3,
	TOTAL_IN_WIDTH = DATA_WIDTH*COLUMN_NUM*ROW_NUM
	)
(
	input i_clk,
	input [TOTAL_IN_WIDTH-1:0] i_img,

	input [1:0] i_mode, // 2'b00: 2-3x3, 2'b01: 4x4, 2'b10: 5x5, 2'b11: 6x6
	input i_3x3_sel, // used in 2-3x3 mode, indicates using the high(1) or low(0) 3 wgr_rf
	input [2:0] i_wgt_shift, // shift RIGHT how many 8 bits

	input [DATA_WIDTH-1:0] i_bias0,
	input [DATA_WIDTH-1:0] i_bias1,
	input [DATA_WIDTH-1:0] i_bias2,

	input [3:0] i_psum_shift;

	);

	wire [ROW_DATA_WIDTH-1:0] wmem2rf[0:ROW_NUM-1];
	wire [ROW_DATA_WIDTH-1:0] wrf_out[0:ROW_NUM-1];
	reg [ROW_DATA_WIDTH-1:0] wrf_out_cir[0:ROW_NUM-1];
	reg [ROW_DATA_WIDTH-1:0] wrf_out_shift[0:ROW_NUM-1];
	generate
		genvar i;
		for (i = 0; i < COLUMN_NUM; i = i + 1)
		begin: row_wgt
			wmem_fake(
				.i_clk(i_clk), 
				.i_wr_en(),
				.i_wr_addr(),
				.i_wr_data(), 
				.i_rd_en(),   
				.i_rd_addr(), 
				.o_bias(),
				.o_rd_data(wmem2rf[i])
				);

			wgt_rf(
				.i_clk(i_clk),
				.i_wr_en(),
				.i_wgt_row(wmem2rf[i]),
				.o_wgt_row(wrf_out[i])
				);


			always@(*) begin
				case (imode)
					2'b00: begin
						if (i_3x3_sel) wrf_out_cir[i] = {wrf_out[i][ROW_DATA_WIDTH-1:(ROW_NUM/2)*DATA_WIDTH],wrf_out[i][ROW_DATA_WIDTH-1:(ROW_NUM/2)*DATA_WIDTH]};
						else wrf_out_cir[i] = {wrf_out[i][(ROW_NUM/2)*DATA_WIDTH-1:0],wrf_out[i][(ROW_NUM/2)*DATA_WIDTH-1:0]};
					end
					2'b01: wrf_out_cir[i] = {wrf_out[i][DATA_WIDTH*2-1:0],wrf_out[i][DATA_WIDTH*4-1:0]};
					2'b10: wrf_out_cir[i] = {wrf_out[i][DATA_WIDTH-1:0],wrf_out[i][DATA_WIDTH*5-1:0]};
					2'b11: wrf_out_cir[i] = wrf_out[i];
					default: wrf_out_cir[i] = wrf_out[i];
				endcase

				case (i_wgt_shift)
					3'd0: wrf_out_shift[i] = wrf_out_cir[i];
					3'd1: wrf_out_shift[i] = {wrf_out_cir[i],wrf_out_cir[i]} >> 8;
					3'd2: wrf_out_shift[i] = {wrf_out_cir[i],wrf_out_cir[i]} >> 16;
					3'd3: wrf_out_shift[i] = {wrf_out_cir[i],wrf_out_cir[i]} >> 24;
					3'd4: wrf_out_shift[i] = {wrf_out_cir[i],wrf_out_cir[i]} >> 32;
					3'd5: wrf_out_shift[i] = {wrf_out_cir[i],wrf_out_cir[i]} >> 40;
					default: wrf_out_shift[i] = wrf_out_cir[i];
				endcase
			end
		end
	endgenerate


	reg [COLUMN_DATA_WIDTH-1:0] wgt_column[0:COLUMN_NUM-1];

	always@(*) begin
		wgt_column[0] = {wrf_out_shift[5][DATA_WIDTH-1:0], wrf_out_shift[4][DATA_WIDTH-1:0], 
						 wrf_out_shift[3][DATA_WIDTH-1:0], wrf_out_shift[2][DATA_WIDTH-1:0],
						 wrf_out_shift[1][DATA_WIDTH-1:0], wrf_out_shift[0][DATA_WIDTH-1:0]};

		wgt_column[1] = {wrf_out_shift[5][DATA_WIDTH*2-1:DATA_WIDTH], wrf_out_shift[4][DATA_WIDTH*2-1:DATA_WIDTH], 
						 wrf_out_shift[3][DATA_WIDTH*2-1:DATA_WIDTH], wrf_out_shift[2][DATA_WIDTH*2-1:DATA_WIDTH],
						 wrf_out_shift[1][DATA_WIDTH*2-1:DATA_WIDTH], wrf_out_shift[0][DATA_WIDTH*2-1:DATA_WIDTH]};

		wgt_column[2] = {wrf_out_shift[5][DATA_WIDTH*3-1:DATA_WIDTH*2], wrf_out_shift[4][DATA_WIDTH*3-1:DATA_WIDTH*2], 
						 wrf_out_shift[3][DATA_WIDTH*3-1:DATA_WIDTH*2], wrf_out_shift[2][DATA_WIDTH*3-1:DATA_WIDTH*2],
						 wrf_out_shift[1][DATA_WIDTH*3-1:DATA_WIDTH*2], wrf_out_shift[0][DATA_WIDTH*3-1:DATA_WIDTH*2]};

		wgt_column[3] = {wrf_out_shift[5][DATA_WIDTH*4-1:DATA_WIDTH*3], wrf_out_shift[4][DATA_WIDTH*4-1:DATA_WIDTH*3], 
						 wrf_out_shift[3][DATA_WIDTH*4-1:DATA_WIDTH*3], wrf_out_shift[2][DATA_WIDTH*4-1:DATA_WIDTH*3],
						 wrf_out_shift[1][DATA_WIDTH*4-1:DATA_WIDTH*3], wrf_out_shift[0][DATA_WIDTH*4-1:DATA_WIDTH*3]};

		wgt_column[4] = {wrf_out_shift[5][DATA_WIDTH*5-1:DATA_WIDTH*4], wrf_out_shift[4][DATA_WIDTH*5-1:DATA_WIDTH*4], 
						 wrf_out_shift[3][DATA_WIDTH*5-1:DATA_WIDTH*4], wrf_out_shift[2][DATA_WIDTH*5-1:DATA_WIDTH*4],
						 wrf_out_shift[1][DATA_WIDTH*5-1:DATA_WIDTH*4], wrf_out_shift[0][DATA_WIDTH*5-1:DATA_WIDTH*4]};

		wgt_column[5] = {wrf_out_shift[5][DATA_WIDTH*6-1:DATA_WIDTH*5], wrf_out_shift[4][DATA_WIDTH*6-1:DATA_WIDTH*5], 
						 wrf_out_shift[3][DATA_WIDTH*6-1:DATA_WIDTH*5], wrf_out_shift[2][DATA_WIDTH*6-1:DATA_WIDTH*5],
						 wrf_out_shift[1][DATA_WIDTH*6-1:DATA_WIDTH*5], wrf_out_shift[0][DATA_WIDTH*6-1:DATA_WIDTH*5]};
	end

	wire signed [COLUMN_DATA_WIDTH-1:0] psum_column[0:ROW_NUM-1];

	generate
		genvar i;
		for (i = 0; i < ROW_NUM; i = i + 1)
		begin: row_mac
			MAC_column(
				.i_img_column(i_img[(i+1)*COLUMN_DATA_WIDTH-1:i*COLUMN_DATA_WIDTH]),
				.i_wgt_column(wgt_column[i]),
				.o_psum_column(psum_column[i])
				);
		end
	endgenerate

	wire signed [COLUMN_DATA_WIDTH:0] bias0; // 20b
	wire signed [COLUMN_DATA_WIDTH:0] bias1;
	wire signed [COLUMN_DATA_WIDTH:0] bias2;
	reg signed [COLUMN_DATA_WIDTH:0] psum0; // 20b
	reg signed [COLUMN_DATA_WIDTH:0] psum1;
	reg signed [COLUMN_DATA_WIDTH:0] psum2;

	assign bias0 = i_bias0<<<i_psum_shift;
	assign bias1 = i_bias1<<<i_psum_shift;
	assign bias2 = i_bias2<<<i_psum_shift;


	always@(*) begin
		case (mode)
			2'b00: begin
				case (i_wgt_shift)
					3'd0: begin
						psum0 = psum_column[0]+psum_column[1]+psum_column[2]+bias0;
						psum1 = psum_column[3]+psum_column[4]+psum_column[5]+bias1;
						psum2 = bias2;
					end
					3'd1: begin
						psum0 = psum_column[0]+bias0;
						psum1 = psum_column[1]+psum_column[2]+psum_column[3]+bias1;
						psum2 = psum_column[4]+psum_column[5]+bias2;
					end
					3'd2: begin
						psum0 = psum_column[0]+psum_column[1]+bias0;
						psum1 = psum_column[2]+psum_column[3]+psum_column[4]+bias1;
						psum2 = psum_column[5]+bias2;
					end
					default: begin
						psum0 = bias0;
						psum1 = bias1;
						psum2 = bias2;
					end
				endcase		
			end
			2'b01: begin
				case (i_wgt_shift)
					3'd0: begin
						psum0 = psum_column[0]+psum_column[1]+psum_column[2]+psum_column[3]+bias0;
						psum1 = psum_column[4]+psum_column[5]+bias1;
						psum2 = bias2;
					end
					3'd1: begin
						psum0 = psum_column[0]+bias0;
						psum1 = psum_column[1]+psum_column[2]+psum_column[3]+psum_column[4]+bias1;
						psum2 = psum_column[5]+bias2;
					end
					3'd2: begin
						psum0 = psum_column[0]+psum_column[1]+bias0;
						psum1 = psum_column[2]+psum_column[3]+psum_column[4]+psum_column[5]+bias1;
						psum2 = bias2;
					end
					3'd3: begin
						psum0 = psum_column[0]+psum_column[1]+psum_column[2]+bias0;
						psum1 = psum_column[3]+psum_column[4]+psum_column[5]+bias1;
						psum2 = bias2;
					end
					default: begin
						psum0 = bias0;
						psum1 = bias1;
						psum2 = bias2;
					end
				endcase		
			end
			2'b10: begin
				case (i_wgt_shift)
					3'd0: begin
						psum0 = psum_column[0]+psum_column[1]+psum_column[2]+psum_column[3]+psum_column[4]+bias0;
						psum1 = psum_column[5]+bias1;
						psum2 = bias2;
					end
					3'd1: begin
						psum0 = psum_column[0]+bias0;
						psum1 = psum_column[1]+psum_column[2]+psum_column[3]+psum_column[4]+psum_column[5]+bias1;
						psum2 = bias2;
					end
					3'd2: begin
						psum0 = psum_column[0]+psum_column[1]+bias0;
						psum1 = psum_column[2]+psum_column[3]+psum_column[4]+psum_column[5]+bias1;
						psum2 = bias2;
					end
					3'd3: begin
						psum0 = psum_column[0]+psum_column[1]+psum_column[2]+bias0;
						psum1 = psum_column[3]+psum_column[4]+psum_column[5]+bias1;
						psum2 = bias2;
					end
					3'd4: begin
						psum0 = psum_column[0]+psum_column[1]+psum_column[2]+psum_column[3]+bias0;
						psum1 = psum_column[4]+psum_column[5]+bias1;
						psum2 = bias2;
					end
					default: begin
						psum0 = bias0;
						psum1 = bias1;
						psum2 = bias2;
					end
				endcase		
			end
			2'b11: begin
				case (i_wgt_shift)
					3'd0: begin
						psum0 = psum_column[0]+psum_column[1]+psum_column[2]+psum_column[3]+psum_column[4]+psum_column[5]+bias0;
						psum1 = bias1;
						psum2 = bias2;
					end
					3'd1: begin
						psum0 = psum_column[0]+bias0;
						psum1 = psum_column[1]+psum_column[2]+psum_column[3]+psum_column[4]+psum_column[5]+bias1;
						psum2 = bias2;
					end
					3'd2: begin
						psum0 = psum_column[0]+psum_column[1]+bias0;
						psum1 = psum_column[2]+psum_column[3]+psum_column[4]+psum_column[5]+bias1;
						psum2 = bias2;
					end
					3'd3: begin
						psum0 = psum_column[0]+psum_column[1]+psum_column[2]+bias0;
						psum1 = psum_column[3]+psum_column[4]+psum_column[5]+bias1;
						psum2 = bias2;
					end
					3'd4: begin
						psum0 = psum_column[0]+psum_column[1]+psum_column[2]+psum_column[3]+bias0;
						psum1 = psum_column[4]+psum_column[5]+bias1;
						psum2 = bias2;
					end
					3'd5: begin
						psum0 = psum_column[0]+psum_column[1]+psum_column[2]+psum_column[3]+psum_column[4]+bias0;
						psum1 = psum_column[5]+bias1;
						psum2 = bias2;
					end
					default: begin
						psum0 = bias0;
						psum1 = bias1;
						psum2 = bias2;
					end
				endcase		
			end
			default: begin
				psum0 = bias0;
				psum1 = bias1;
				psum2 = bias2;
			end
		endcase
	end

	reg signed [COLUMN_DATA_WIDTH:0] psum0_shifted; // 20b
	reg signed [COLUMN_DATA_WIDTH:0] psum1_shifted;
	reg signed [COLUMN_DATA_WIDTH:0] psum2_shifted;

	reg signed [DATA_WIDTH-1:0] psum0_truncated;
	reg signed [DATA_WIDTH-1:0] psum1_truncated;
	reg signed [DATA_WIDTH-1:0] psum2_truncated;

	always @(*) begin
		psum0_shifted = psum0 >>> i_psum_shift;
		psum1_shifted = psum1 >>> i_psum_shift;
		psum2_shifted = psum2 >>> i_psum_shift;
		if (psum0_shifted[COLUMN_DATA_WIDTH]) begin
			if (&(psum0_shifted[COLUMN_DATA_WIDTH:DATA_WIDTH-1])) begin
				psum0_truncated = psum0_shifted[DATA_WIDTH-1:0];
			end
			else begin
				psum0_truncated = 8'b1000_0000;
			end
		else begin
			if(~(|(psum0_shifted[COLUMN_DATA_WIDTH:DATA_WIDTH-1]))) begin
				psum0_truncated = psum0_shifted[DATA_WIDTH-1:0];
			end
			else begin
				psum0_truncated = 8'b0111_1111;
			end
		end
		if (psum1_shifted[COLUMN_DATA_WIDTH]) begin
			if (&(psum1_shifted[COLUMN_DATA_WIDTH:DATA_WIDTH-1])) begin
				psum1_truncated = psum1_shifted[DATA_WIDTH-1:0];
			end
			else begin
				psum1_truncated = 8'b1000_0000;
			end
		else begin
			if(~(|(psum1_shifted[COLUMN_DATA_WIDTH:DATA_WIDTH-1]))) begin
				psum1_truncated = psum1_shifted[DATA_WIDTH-1:0];
			end
			else begin
				psum1_truncated = 8'b0111_1111;
			end
		end
		if (psum2_shifted[COLUMN_DATA_WIDTH]) begin
			if (&(psum2_shifted[COLUMN_DATA_WIDTH:DATA_WIDTH-1])) begin
				psum2_truncated = psum2_shifted[DATA_WIDTH-1:0];
			end
			else begin
				psum2_truncated = 8'b1000_0000;
			end
		else begin
			if(~(|(psum2_shifted[COLUMN_DATA_WIDTH:DATA_WIDTH-1]))) begin
				psum2_truncated = psum2_shifted[DATA_WIDTH-1:0];
			end
			else begin
				psum2_truncated = 8'b0111_1111;
			end
		end
	end



endmodule

