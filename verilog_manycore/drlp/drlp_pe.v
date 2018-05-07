 // PE

module drlp_pe
#(parameter
	DATA_WIDTH = 8,
	PDATA_WIDTH = 16,
	COLUMN_NUM = 6,
	ROW_NUM = 6,
	PMEM_ADDR_WIDTH = 8,
	WMEM_ADDR_WIDTH = 7,
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
	// input i_3x3_sel, // used in 2-3x3 mode, indicates using the high(1) or low(0) 3 wgr_rf
	input [2:0] i_wgt_shift, // shift RIGHT how many 8 bits


	input [2:0] i_psum_shift,
	input [DATA_WIDTH-1:0] i_bias,
	input i_update_bias,
	input i_bias_sel, // 0: add bias; 1: add psum

	input i_psum_sel,
	input i_pmem_wr_en0,
	input i_pmem_wr_en1,
	input i_pmem_rd_en0,
	input i_pmem_rd_en1,
	input [PMEM_ADDR_WIDTH-1:0] i_pmem_wr_addr0,
	input [PMEM_ADDR_WIDTH-1:0] i_pmem_wr_addr1,
	input [PMEM_ADDR_WIDTH-1:0] i_pmem_rd_addr0,
	input [PMEM_ADDR_WIDTH-1:0] i_pmem_rd_addr1,

	input [COLUMN_NUM-1:0] i_wmem_wr_en,
	input [WMEM_ADDR_WIDTH-1:0] i_wmem_wr_addr,
	input [ROW_DATA_WIDTH-1:0] i_wmem_wr_data,
	input [WMEM_ADDR_WIDTH-1:0] i_wmem_rd_addr,
	input i_update_wgt,

	output wire signed [PDATA_WIDTH-1:0] o_result0,
	output wire signed [PDATA_WIDTH-1:0] o_result1

	);


	reg signed [DATA_WIDTH-1:0] bias_reg;

	always @(posedge i_clk) begin
		if (i_update_bias) begin
			bias_reg <= i_bias;
		end
	end

	wire [ROW_DATA_WIDTH-1:0] wmem2rf[0:ROW_NUM-1];
	wire [ROW_DATA_WIDTH-1:0] wrf_out[0:ROW_NUM-1];
	wire [DATA_WIDTH-1:0] wrf_split[0:COLUMN_NUM*ROW_NUM-1];
	// reg [ROW_DATA_WIDTH*2-1:0] wrf_out_cir[0:ROW_NUM-1];
	reg [ROW_DATA_WIDTH-1:0] wrf_out_shift[0:ROW_NUM-1];

	generate
		genvar i;
		for (i = 0; i < COLUMN_NUM; i = i + 1)
		begin: row_wgt
			wmem_fake wmem(
				.i_clk(i_clk), 
				.i_wr_en(i_wmem_wr_en[i]),
				.i_wr_addr(i_wmem_wr_addr),
				// .i_wr_data(i_wmem_wr_data[(i+1)*ROW_DATA_WIDTH-1:i*ROW_DATA_WIDTH]), 
				.i_wr_data(i_wmem_wr_data), 
				.i_rd_en(1'b1),   
				.i_rd_addr(i_wmem_rd_addr), 
				.o_rd_data(wmem2rf[i])
				);

			// wgt_rf wgt_rf(
			// 	.i_clk(i_clk),
			// 	.i_wr_en(1'b1),
			// 	.i_wgt_row(wmem2rf[i]),
			// 	.o_wgt_row(wrf_out[i])
			// 	);

			assign wrf_split[i*COLUMN_NUM] = wmem2rf[i][DATA_WIDTH-1:0];
			assign wrf_split[i*COLUMN_NUM+1] = wmem2rf[i][DATA_WIDTH*2-1:DATA_WIDTH*1];
			assign wrf_split[i*COLUMN_NUM+2] = wmem2rf[i][DATA_WIDTH*3-1:DATA_WIDTH*2];
			assign wrf_split[i*COLUMN_NUM+3] = wmem2rf[i][DATA_WIDTH*4-1:DATA_WIDTH*3];
			assign wrf_split[i*COLUMN_NUM+4] = wmem2rf[i][DATA_WIDTH*5-1:DATA_WIDTH*4];
			assign wrf_split[i*COLUMN_NUM+5] = wmem2rf[i][DATA_WIDTH*6-1:DATA_WIDTH*5];

			always@(*) begin
				case (i_mode)
					2'b00: begin
						case (i_wgt_shift)
						3'd0: wrf_out_shift[i] = {wrf_split[i*COLUMN_NUM+5],wrf_split[i*COLUMN_NUM+4],wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+2],wrf_split[i*COLUMN_NUM+1],wrf_split[i*COLUMN_NUM]};
						3'd1: wrf_out_shift[i] = {wrf_split[i*COLUMN_NUM+4],wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+5],wrf_split[i*COLUMN_NUM+1],wrf_split[i*COLUMN_NUM],wrf_split[i*COLUMN_NUM+2]};
						3'd2: wrf_out_shift[i] = {wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+5],wrf_split[i*COLUMN_NUM+4],wrf_split[i*COLUMN_NUM],wrf_split[i*COLUMN_NUM+2],wrf_split[i*COLUMN_NUM+1]};
						default: wrf_out_shift[i] = {wrf_split[i*COLUMN_NUM+5],wrf_split[i*COLUMN_NUM+4],wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+2],wrf_split[i*COLUMN_NUM+1],wrf_split[i*COLUMN_NUM]};
						endcase
					end
					2'b01: begin
						case (i_wgt_shift)
						3'd0: wrf_out_shift[i] = {16'bx, wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+2],wrf_split[i*COLUMN_NUM+1],wrf_split[i*COLUMN_NUM]};
						3'd1: wrf_out_shift[i] = {16'bx, wrf_split[i*COLUMN_NUM+2],wrf_split[i*COLUMN_NUM+1],wrf_split[i*COLUMN_NUM],wrf_split[i*COLUMN_NUM+3]};
						3'd2: wrf_out_shift[i] = {16'bx, wrf_split[i*COLUMN_NUM+1],wrf_split[i*COLUMN_NUM],wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+2]};
						3'd3: wrf_out_shift[i] = {16'bx, wrf_split[i*COLUMN_NUM],wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+2],wrf_split[i*COLUMN_NUM+1]};
						default: wrf_out_shift[i] = {16'bx, wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+2],wrf_split[i*COLUMN_NUM+1],wrf_split[i*COLUMN_NUM]};
						endcase
					end
					2'b10: begin
						case (i_wgt_shift)
						3'd0: wrf_out_shift[i] = {8'bx, wrf_split[i*COLUMN_NUM+4],wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+2],wrf_split[i*COLUMN_NUM+1],wrf_split[i*COLUMN_NUM]};
						3'd1: wrf_out_shift[i] = {8'bx, wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+2],wrf_split[i*COLUMN_NUM+1],wrf_split[i*COLUMN_NUM],wrf_split[i*COLUMN_NUM+4]};
						3'd2: wrf_out_shift[i] = {8'bx, wrf_split[i*COLUMN_NUM+2],wrf_split[i*COLUMN_NUM+1],wrf_split[i*COLUMN_NUM],wrf_split[i*COLUMN_NUM+4],wrf_split[i*COLUMN_NUM+3]};
						3'd3: wrf_out_shift[i] = {8'bx, wrf_split[i*COLUMN_NUM+1],wrf_split[i*COLUMN_NUM],wrf_split[i*COLUMN_NUM+4],wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+2]};
						3'd4: wrf_out_shift[i] = {8'bx, wrf_split[i*COLUMN_NUM],wrf_split[i*COLUMN_NUM+4],wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+2],wrf_split[i*COLUMN_NUM+1]};
						default: wrf_out_shift[i] = {8'bx, wrf_split[i*COLUMN_NUM+4],wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+2],wrf_split[i*COLUMN_NUM+1],wrf_split[i*COLUMN_NUM]};
						endcase
					end
					2'b11: begin
						case (i_wgt_shift)
						3'd0: wrf_out_shift[i] = {wrf_split[i*COLUMN_NUM+5],wrf_split[i*COLUMN_NUM+4],wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+2],wrf_split[i*COLUMN_NUM+1],wrf_split[i*COLUMN_NUM]};
						3'd1: wrf_out_shift[i] = {wrf_split[i*COLUMN_NUM+4],wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+2],wrf_split[i*COLUMN_NUM+1],wrf_split[i*COLUMN_NUM],wrf_split[i*COLUMN_NUM+5]};
						3'd2: wrf_out_shift[i] = {wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+2],wrf_split[i*COLUMN_NUM+1],wrf_split[i*COLUMN_NUM],wrf_split[i*COLUMN_NUM+5],wrf_split[i*COLUMN_NUM+4]};
						3'd3: wrf_out_shift[i] = {wrf_split[i*COLUMN_NUM+2],wrf_split[i*COLUMN_NUM+1],wrf_split[i*COLUMN_NUM],wrf_split[i*COLUMN_NUM+5],wrf_split[i*COLUMN_NUM+4],wrf_split[i*COLUMN_NUM+3]};
						3'd4: wrf_out_shift[i] = {wrf_split[i*COLUMN_NUM+1],wrf_split[i*COLUMN_NUM],wrf_split[i*COLUMN_NUM+5],wrf_split[i*COLUMN_NUM+4],wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+2]};
						3'd5: wrf_out_shift[i] = {wrf_split[i*COLUMN_NUM],wrf_split[i*COLUMN_NUM+5],wrf_split[i*COLUMN_NUM+4],wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+2],wrf_split[i*COLUMN_NUM+1]};
						default: wrf_out_shift[i] = {wrf_split[i*COLUMN_NUM+5],wrf_split[i*COLUMN_NUM+4],wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+2],wrf_split[i*COLUMN_NUM+1],wrf_split[i*COLUMN_NUM]};
						endcase
					end
					default: wrf_out_shift[i] = {wrf_split[i*COLUMN_NUM+5],wrf_split[i*COLUMN_NUM+4],wrf_split[i*COLUMN_NUM+3],wrf_split[i*COLUMN_NUM+2],wrf_split[i*COLUMN_NUM+1],wrf_split[i*COLUMN_NUM]};
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

	wire signed [COLUMN_OUT_WIDTH-1:0] psum_column[0:ROW_NUM-1];

	generate
		genvar ic;
		for (ic = 0; ic < ROW_NUM; ic = ic + 1)
		begin: row_mac
			pe_mac mac(
				.i_img_column(i_img[(ic+1)*COLUMN_DATA_WIDTH-1:ic*COLUMN_DATA_WIDTH]),
				.i_wgt_column(wgt_column[ic]),
				.i_mode(i_mode),
				.o_psum_column(psum_column[ic])
				);
		end
	endgenerate

	wire signed [23:0] bias0; // 20b
	wire signed [23:0] bias1;
	
	reg signed [23:0] psum0; // 20b
	reg signed [23:0] psum1;

	wire signed [PDATA_WIDTH-1:0] psum0_rd;
	wire signed [PDATA_WIDTH-1:0] psum1_rd;

	wire signed [PDATA_WIDTH-1:0] psum0_pre;
	wire signed [PDATA_WIDTH-1:0] psum1_pre;

	assign psum0_pre = i_psum_sel?psum1_rd:psum0_rd;
	assign psum1_pre = i_psum_sel?psum0_rd:psum1_rd;

	// assign bias0 = i_bias_sel? (psum0_pre<<<i_psum_shift):bias_reg;
	assign bias0 = psum0_pre<<<i_psum_shift;
	assign bias1 = i_bias_sel? (psum1_pre<<<i_psum_shift):bias_reg;


	always@(*) begin

		case (i_mode)
			2'b00: begin
				case (i_wgt_shift)
					3'd0: begin
						psum0 = bias0;
						psum1 = psum_column[0]+psum_column[1]+psum_column[2]+psum_column[3]+psum_column[4]+psum_column[5]+bias1;
						// psum2 = bias2;
					end
					3'd1: begin
						psum0 = psum_column[0]+psum_column[3]+bias0;
						psum1 = psum_column[1]+psum_column[2]+psum_column[4]+psum_column[5]+bias1;
						// psum2 = psum_column[4]+psum_column[5]+bias2;
					end
					3'd2: begin
						psum0 = psum_column[0]+psum_column[1]+psum_column[3]+psum_column[4]+bias0;
						psum1 = psum_column[2]+psum_column[5]+bias1;
						// psum2 = psum_column[5]+bias2;
					end
					default: begin
						psum0 = bias0;
						psum1 = bias1;
						// psum2 = bias2;
					end
				endcase		
			end
			2'b01: begin
				// 4x4
				case (i_wgt_shift)
					3'd0: begin
						psum0 = bias0;
						psum1 = psum_column[0]+psum_column[1]+psum_column[2]+psum_column[3]+bias1;
						// psum2 = bias2;
					end
					3'd1: begin
						psum0 = psum_column[0]+bias0;
						psum1 = psum_column[1]+psum_column[2]+psum_column[3]+bias1;
						// psum2 = psum_column[5]+bias2;
					end
					3'd2: begin
						psum0 = psum_column[0]+psum_column[1]+bias0;
						psum1 = psum_column[2]+psum_column[3]+bias1;
						// psum2 = bias2;
					end
					3'd3: begin
						psum0 = psum_column[0]+psum_column[1]+psum_column[2]+bias0;
						psum1 = psum_column[3]+bias1;
						// psum2 = bias2;
					end
					default: begin
						psum0 = bias0;
						psum1 = bias1;
						// psum2 = bias2;
					end
				endcase		
			end
			2'b10: begin
				case (i_wgt_shift)
					3'd0: begin
						psum0 = bias0;
						psum1 = psum_column[0]+psum_column[1]+psum_column[2]+psum_column[3]+psum_column[4]+bias1;
						// psum2 = bias2;
					end
					3'd1: begin
						psum0 = psum_column[0]+bias0;
						psum1 = psum_column[1]+psum_column[2]+psum_column[3]+psum_column[4]+bias1;
						// psum2 = bias2;
					end
					3'd2: begin
						psum0 = psum_column[0]+psum_column[1]+bias0;
						psum1 = psum_column[2]+psum_column[3]+psum_column[4]+bias1;
						// psum2 = bias2;
					end
					3'd3: begin
						psum0 = psum_column[0]+psum_column[1]+psum_column[2]+bias0;
						psum1 = psum_column[3]+psum_column[4]+bias1;
						// psum2 = bias2;
					end
					3'd4: begin
						psum0 = psum_column[0]+psum_column[1]+psum_column[2]+psum_column[3]+bias0;
						psum1 = psum_column[4]+bias1;
						// psum2 = bias2;
					end
					default: begin
						psum0 = bias0;
						psum1 = bias1;
						// psum2 = bias2;
					end
				endcase		
			end
			2'b11: begin
				case (i_wgt_shift)
					3'd0: begin
						psum0 = bias0;
						psum1 = psum_column[0]+psum_column[1]+psum_column[2]+psum_column[3]+psum_column[4]+psum_column[5]+bias1;
						// psum2 = bias2;
					end
					3'd1: begin
						psum0 = psum_column[0]+bias0;
						psum1 = psum_column[1]+psum_column[2]+psum_column[3]+psum_column[4]+psum_column[5]+bias1;
						// psum2 = bias2;
					end
					3'd2: begin
						psum0 = psum_column[0]+psum_column[1]+bias0;
						psum1 = psum_column[2]+psum_column[3]+psum_column[4]+psum_column[5]+bias1;
						// psum2 = bias2;
					end
					3'd3: begin
						psum0 = psum_column[0]+psum_column[1]+psum_column[2]+bias0;
						psum1 = psum_column[3]+psum_column[4]+psum_column[5]+bias1;
						// psum2 = bias2;
					end
					3'd4: begin
						psum0 = psum_column[0]+psum_column[1]+psum_column[2]+psum_column[3]+bias0;
						psum1 = psum_column[4]+psum_column[5]+bias1;
						// psum2 = bias2;
					end
					3'd5: begin
						psum0 = psum_column[0]+psum_column[1]+psum_column[2]+psum_column[3]+psum_column[4]+bias0;
						psum1 = psum_column[5]+bias1;
						// psum2 = bias2;
					end
					default: begin
						psum0 = bias0;
						psum1 = bias1;
						// psum2 = bias2;
					end
				endcase		
			end
			default: begin
				psum0 = bias0;
				psum1 = bias1;
				// psum2 = bias2;
			end
		endcase
	end

	reg signed [23:0] psum0_shifted; // 20b
	reg signed [23:0] psum1_shifted;

	reg signed [PDATA_WIDTH-1:0] psum0_truncated;
	reg signed [PDATA_WIDTH-1:0] psum1_truncated;

	always @(*) begin
		if (~i_psum_sel) begin
			psum0_shifted = psum0 >>> i_psum_shift;
			psum1_shifted = psum1 >>> i_psum_shift;
		end
		else begin
			psum0_shifted = psum1 >>> i_psum_shift;
			psum1_shifted = psum0 >>> i_psum_shift;
		end

		if (psum0_shifted[23]) begin
			if (&(psum0_shifted[23:PDATA_WIDTH-1]))
				psum0_truncated = psum0_shifted[PDATA_WIDTH-1:0];
			else 
				psum0_truncated = 16'b1000_0000_0000_0000;
		end
		else begin
			if(~(|(psum0_shifted[23:PDATA_WIDTH-1])))
				psum0_truncated = psum0_shifted[PDATA_WIDTH-1:0];

			else
				psum0_truncated = 16'b0111_1111_1111_1111;
		end
		if (psum1_shifted[23]) begin
			if (&(psum1_shifted[23:PDATA_WIDTH-1]))
				psum1_truncated = psum1_shifted[PDATA_WIDTH-1:0];
			else
				psum1_truncated = 16'b1000_0000_0000_0000;
		end
		else begin
			if(~(|(psum1_shifted[23:PDATA_WIDTH-1])))
				psum1_truncated = psum1_shifted[PDATA_WIDTH-1:0];
			else
				psum1_truncated = 16'b0111_1111_1111_1111;
		end
	end

	pmem_fake pmem0(
	  .i_clk(i_clk), 
	  .i_wr_en(i_pmem_wr_en0),
	  .i_rd_en(i_pmem_rd_en0),
	  .i_wr_addr(i_pmem_wr_addr0),
	  .i_wr_data(psum0_truncated),
	  .i_rd_addr(i_pmem_rd_addr0),
	  .o_rd_data(psum0_rd)
	);

	pmem_fake pmem1(
	  .i_clk(i_clk), 
	  .i_wr_en(i_pmem_wr_en1),
	  .i_rd_en(i_pmem_rd_en1),
	  .i_wr_addr(i_pmem_wr_addr1),
	  .i_wr_data(psum1_truncated),
	  .i_rd_addr(i_pmem_rd_addr1),
	  .o_rd_data(psum1_rd)
	);


	assign o_result0 = psum0_rd;
	assign o_result1 = psum1_rd;


endmodule

