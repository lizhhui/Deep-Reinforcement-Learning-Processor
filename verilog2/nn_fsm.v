// nn_fsm

module nn_fsm
#(parameter
	DATA_WIDTH = 8,
	DMA_ADDR_WIDTH = 5,
	COLUMN_NUM = 6,
	ROW_NUM = 6,
	PMEM_ADDR_WIDTH = 8,
	WMEM_ADDR_WIDTH = 7,
	IMEM_ADDR_WIDTH = 10, // depth = 1024, 4KB
	WMEM_DEPTH = 2**WMEM_ADDR_WIDTH-1,
  	IMEM_DATA_WIDTH = DATA_WIDTH*6,
	COLUMN_DATA_WIDTH = DATA_WIDTH*COLUMN_NUM,
	ROW_DATA_WIDTH = DATA_WIDTH*ROW_NUM,
	OUT_WIDTH = 2*DATA_WIDTH,
	COLUMN_OUT_WIDTH = OUT_WIDTH+3,
	TOTAL_IN_WIDTH = DATA_WIDTH*COLUMN_NUM*ROW_NUM
	)
(
	input i_clk,
	input i_rst,

	input i_start,

	// from configuration registers
	input [1:0] i_mode,
	input [1:0] i_pool,
	// input i_relu,
	input [2:0] i_stride,
	input [6:0] i_zmove,
	input [5:0] i_xmove,
	input [6:0] i_ymove,
	input [DMA_ADDR_WIDTH-1:0] i_dma_img_base_addr,
	input [DMA_ADDR_WIDTH-1:0] i_dma_wgt_base_addr,
	input [DMA_ADDR_WIDTH-1:0] i_dma_wr_base_addr,
	input [IMEM_ADDR_WIDTH-1:0] i_img_wr_count,

	// from PE
	input [DATA_WIDTH-1:0] i_pmem_rd_data0,
	input [DATA_WIDTH-1:0] i_pmem_rd_data1,
	

	// from DMA
	input [15:0] i_dma_rd_data,
	input i_dma_rd_ready,

	output reg o_dma_rd_en,
	output reg [DMA_ADDR_WIDTH-1:0] o_dma_rd_addr,

	output reg o_img_bf_wr_en,
	output reg [IMEM_ADDR_WIDTH-1:0] o_img_bf_wr_addr,
	output reg [IMEM_DATA_WIDTH-1:0] o_img_bf_wr_data,
	output reg [IMEM_ADDR_WIDTH-1:0] o_img_bf_rd_addr,

	// to sliding
	output reg o_shift,
	output reg o_3x3,

	output reg o_wmem0_state, // 0: to be wrote; 1: to be read
	output reg o_wmem1_state, // 0: to be wrote; 1: to be read
	output reg [COLUMN_NUM-1:0] o_wmem_wr_en,
	output reg [WMEM_ADDR_WIDTH-1:0] o_wmem_wr_addr,
	output reg [ROW_DATA_WIDTH-1:0] o_wmem_wr_data,
	output reg [WMEM_ADDR_WIDTH-1:0] o_wmem_rd_addr,


	output reg [2:0] o_wgt_shift,
	// output reg [3:0] o_psum_shift,

	output reg o_bias_sel, // 0: add bias; 1: add psum
	output reg [DATA_WIDTH-1:0] o_bias,
	output reg o_update_bias,

	output o_psum_sel,

	output reg o_pmem_wr_en0,
	output reg o_pmem_wr_en1,
	output reg o_pmem_rd_en0,
	output reg o_pmem_rd_en1,
	output reg [PMEM_ADDR_WIDTH-1:0] o_pmem_wr_addr0,
	output reg [PMEM_ADDR_WIDTH-1:0] o_pmem_wr_addr1,
	output reg [PMEM_ADDR_WIDTH-1:0] o_pmem_rd_addr0,
	output reg [PMEM_ADDR_WIDTH-1:0] o_pmem_rd_addr1,
	
	output reg o_update_wgt,
	output reg o_dma_wr_en,
	output reg [DMA_ADDR_WIDTH-1:0] o_dma_wr_addr,
	output reg [DATA_WIDTH-1:0] o_dma_wr_data

);
	localparam RESET = 2'b00; // initial/reset
	localparam WRIBF = 2'b01; // write image buffer
	localparam COMPT = 2'b10; // compute, write wight buffer and the same time
	localparam BURST = 2'b11; // burst out result (relu/pool)

	reg [1:0] status; // 2'b00: initial/reset; 2'b01: wrt img bf
					  // 2'b10: compute/wrt wgt bf; 2'b11: burst (relu/pool) 

	reg [1:0] wr_flag;
	reg [IMEM_ADDR_WIDTH-1:0] img_wr_count; // check with o_img_bf_wr_addr
	reg [5:0] wgt_wr_count;

	reg [COLUMN_NUM-1:0] wmem_wr_which;
	reg [COLUMN_NUM-1:0] wmem_wr_row_end;

	reg [8:0] ymove_count;
	reg [5:0] xmove_count;
	reg [6:0] zmove_count;

	reg [2:0] sld_count;

	reg [2:0] wgt_shift_count;

	reg [PMEM_ADDR_WIDTH-1:0] psum_base_addr [0:5];


	reg compute_statrt;

	reg wgt_shift_finish;

	reg dma_wr_flag;

	reg [1:0] pool_position;
	reg [1:0] pool_count;

	assign o_psum_sel = ~xmove_count[0];

	always @(posedge i_clk or negedge i_rst) begin
		if (~i_rst) begin
			status <= 2'b00;
			wr_flag <= 2'b00;
		end
		else begin
			case (status)
				RESET: begin
					o_dma_rd_addr <= 0;
					o_dma_rd_en <= 0;
					o_img_bf_wr_addr <= 10'b11_1111_1111;
					o_img_bf_wr_data <= 0;
					o_img_bf_wr_en <= 0;
					o_img_bf_rd_addr <= 10'b11_1111_1111;
					wr_flag <= 2'b00;
					img_wr_count <= 0;
					wgt_wr_count <= 0;
					o_wmem0_state <= 0;
					o_wmem1_state <= 0;
					wmem_wr_which <= 6'b0000_01;
					wmem_wr_row_end <= 0;
					o_wmem_wr_addr <= 0;
					ymove_count <= 0;
					xmove_count <= 0;
					zmove_count <= 0;
					o_shift <= 0;
					sld_count <= 0;
					o_3x3 <= 0;
					wgt_shift_count <= 0;
					o_pmem_wr_en0 <= 0;
					o_pmem_wr_en1 <= 0;
					// psum_base_addr <= 0;
					o_wmem_rd_addr <= 0; 
					o_update_wgt <= 0;

					o_bias <= 0;
					o_bias_sel <= 0;
					o_update_bias <= 0;

					o_wgt_shift <= 0;

					o_dma_wr_en <= 0;
					o_dma_wr_addr <= 0;
					o_dma_wr_data <= 0;
					wgt_shift_finish<=0;

					dma_wr_flag <= 0;
					pool_position <= 0;
					pool_count <= 0;
					if (i_start) begin
						status <= WRIBF;
						o_dma_rd_addr <= i_dma_img_base_addr;
						o_dma_rd_en <= 1;
						// initial psum_base_addr
						psum_base_addr[0] <= 0;
						psum_base_addr[1] <= i_ymove+1;
						psum_base_addr[2] <= (i_ymove+1)<<1;
						psum_base_addr[3] <= (i_ymove+1)+((i_ymove+1)<<1);
						psum_base_addr[4] <= (i_ymove+1)<<2;
						psum_base_addr[5] <= (i_ymove+1)+((i_ymove+1)<<2);
						compute_statrt <= 0;
					end			
				end

				WRIBF: begin

					if (img_wr_count == i_img_wr_count) begin
						img_wr_count <= 0;
						// o_dma_rd_en <= 0;
						o_img_bf_wr_en <= 0;
						o_dma_rd_addr <= i_dma_wgt_base_addr;
						status <= COMPT;
					end
					else if (i_dma_rd_ready) begin
						o_dma_rd_addr <= o_dma_rd_addr+1;
						if (wr_flag==2'b00) begin
							wr_flag <= 2'b01;
							o_img_bf_wr_data[15:0] <= i_dma_rd_data;
							o_img_bf_wr_en <= 0;
						end
						else if (wr_flag==2'b01) begin
							wr_flag <= 2'b10;
							o_img_bf_wr_data[31:16] <= i_dma_rd_data;
						end
						else if (wr_flag==2'b10) begin
							wr_flag <= 2'b00;
							o_img_bf_wr_data[47:32] <= i_dma_rd_data;
							o_img_bf_wr_en <= 1;
							case (i_mode)
								2'b00: wmem_wr_row_end <= 6'b10_0000;
								2'b01: wmem_wr_row_end <= 6'b00_1000;
								2'b10: wmem_wr_row_end <= 6'b01_0000;
								2'b11: wmem_wr_row_end <= 6'b10_0000;
							endcase

							o_img_bf_wr_addr <= o_img_bf_wr_addr + 1'b1;
							img_wr_count <= img_wr_count+1'b1;
						end
					end
				end

				COMPT: begin
					o_img_bf_wr_en <= 0;

					// Write weight buffer
					if (wgt_wr_count > i_zmove) begin
						o_wmem_wr_en <= 0;
						o_wmem_wr_addr <= 0;
						o_update_bias <= 0;
						o_dma_rd_en <= 0;
					end
					else if(i_dma_rd_ready) begin
						// if (o_wmem0_state==0) begin 	
						if (wgt_wr_count==0&&o_update_bias==0) begin
							o_update_bias <= 1;
							o_bias <= i_dma_rd_data;
							o_dma_rd_en <= 1;
						end
						else begin
							o_update_bias <= 0;
							o_dma_rd_en <= 1;
							if (wr_flag==2'b00) begin
								o_dma_rd_addr <= o_dma_rd_addr+1;
								wr_flag <= 2'b01;
								o_wmem_wr_data[15:0] <= i_dma_rd_data;
								o_wmem_wr_en <= 0;
							end
							else if (wr_flag==2'b01) begin
								o_dma_rd_addr <= o_dma_rd_addr+1;
								wr_flag <= 2'b10;
								o_wmem_wr_data[31:16] <= i_dma_rd_data;
								o_wmem_wr_en <= 0;
							end
							else if (wr_flag==2'b10) begin
								o_dma_rd_addr <= o_dma_rd_addr+1;
								wr_flag <= 2'b00;
								o_wmem_wr_data[47:32] <= i_dma_rd_data;
								o_wmem_wr_en <= wmem_wr_which;

								if (wmem_wr_which == wmem_wr_row_end) begin
									wmem_wr_which <= 6'b0000_01;
									wgt_wr_count <= wgt_wr_count+1'b1;
									// if ((wgt_wr_count+1'b1) == i_zmove ) begin
									// 	o_wmem_wr_addr <= 0;
									// 	if (o_wmem0_state==0) begin
									// 		o_wmem0_state <= 1; // wmem0 to be read
									// 		o_update_wgt <= 1;
									// 		o_wmem_rd_addr <= 0;
									// 	end
									// 	else begin
									// 		o_wmem1_state <= 1; // wmem1 to be read
									// 		o_update_wgt <= 1;
									// 		o_wmem_rd_addr <= 0;
									// 	end
									// end
								end
								else begin
									wmem_wr_which <= wmem_wr_which << 1;
								end
							end			
						end
					end
					
					if (wgt_wr_count>=zmove_count && wgt_wr_count>0) begin

						if (wgt_shift_finish) begin
							if (ymove_count==i_ymove) begin
								ymove_count <= 0;
								if (xmove_count==i_ymove) begin
									xmove_count <= 0;
									if (zmove_count==i_zmove) begin
										// COMPUTATION FINISHED
										// GO TO BURST
										status <= BURST;
										zmove_count <= 0;
										xmove_count <= 0;
										ymove_count <= 1;
										o_pmem_rd_en0 <= 1;
										o_pmem_rd_en1 <= 0;
										o_pmem_rd_addr0 <= 0;
										o_pmem_rd_addr1 <= 0;
										o_dma_wr_addr <= i_dma_wr_base_addr-1;
										case(i_mode)
											2'b00: psum_base_addr[0] <= (i_ymove+1)*3-1;
											2'b01: psum_base_addr[0] <= (i_ymove+1)*4-1;
											2'b10: psum_base_addr[0] <= (i_ymove+1)*5-1;
											2'b11: psum_base_addr[0] <= (i_ymove+1)*6-1;
										endcase
										psum_base_addr[1] <= ((i_ymove+1)<<1)-1;
										psum_base_addr[2] <= (i_ymove+1)*4-1;
										psum_base_addr[3] <= (i_ymove+1)*6-1;
									end
									else zmove_count <= zmove_count+1;
								end
								else begin 
									xmove_count <= xmove_count+1;
									if(xmove_count[0])
										case(i_mode)
											2'b00: begin
												psum_base_addr[0] <= psum_base_addr[2]+1;
												psum_base_addr[1] <= psum_base_addr[2]+i_ymove+1;
												psum_base_addr[2] <= psum_base_addr[2]+(i_ymove>>1)+1;
											end
											2'b01: begin
												psum_base_addr[0] <= psum_base_addr[3]+1;
												psum_base_addr[1] <= psum_base_addr[3]+i_ymove+1;
												psum_base_addr[2] <= psum_base_addr[3]+(i_ymove>>1)+1;
												psum_base_addr[3] <= psum_base_addr[2]+(i_ymove>>2)+1;
											end
											2'b10: begin
												psum_base_addr[0] <= psum_base_addr[4]+1;
												psum_base_addr[1] <= psum_base_addr[4]+i_ymove+1;
												psum_base_addr[2] <= psum_base_addr[4]+(i_ymove>>1)+1;
												psum_base_addr[3] <= psum_base_addr[3]+(i_ymove>>2)+1;
												psum_base_addr[4] <= psum_base_addr[4]+(i_ymove>>2)+1;
											end
											2'b11: begin
												psum_base_addr[0] <= psum_base_addr[5]+1;
												psum_base_addr[1] <= psum_base_addr[5]+i_ymove+1;
												psum_base_addr[2] <= psum_base_addr[5]+(i_ymove>>1)+1;
												psum_base_addr[3] <= psum_base_addr[4]+(i_ymove>>2)+1;
												psum_base_addr[4] <= psum_base_addr[5]+(i_ymove>>2)+1;
												psum_base_addr[5] <= psum_base_addr[2]+(i_ymove>>3)+1;
											end
										endcase
									else begin
										psum_base_addr[0] <= psum_base_addr[0]-i_ymove;
										psum_base_addr[1] <= psum_base_addr[1]-i_ymove;
										psum_base_addr[2] <= psum_base_addr[2]-i_ymove;
										psum_base_addr[3] <= psum_base_addr[3]-i_ymove;
										psum_base_addr[4] <= psum_base_addr[4]-i_ymove;
										psum_base_addr[5] <= psum_base_addr[5]-i_ymove;
									end
								end
							end
							else begin 
								ymove_count <= ymove_count+1;
								psum_base_addr[0] <= psum_base_addr[0]+1;
								psum_base_addr[1] <= psum_base_addr[1]+1;
								psum_base_addr[2] <= psum_base_addr[2]+1;
								psum_base_addr[3] <= psum_base_addr[3]+1;
								psum_base_addr[4] <= psum_base_addr[4]+1;
								psum_base_addr[5] <= psum_base_addr[5]+1;
							end
						end
						
						if (zmove_count==0) begin
							o_bias_sel <= 0;
						end
						else begin
							o_bias_sel <= 1;
						end

						if (zmove_count <= i_zmove) begin

							if (xmove_count==0 && ymove_count==0 && wgt_shift_count==0 && sld_count==0 && o_update_wgt==0) begin
								o_update_wgt <= 1;
								o_wmem_rd_addr <= o_wmem_rd_addr+1;
							end

							else begin
								o_update_wgt <= 0;
								case(i_mode)
									2'b00: begin
										// 4-3x3 mode
										if (sld_count<3'd6) begin
											wgt_shift_finish <= 0;
											o_3x3 <= sld_count[0]; // slide high || low
											o_shift <= 1;
											sld_count <= sld_count+1'b1;
											o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
											o_pmem_wr_en0 <= 0;
											o_pmem_wr_en1 <= 0;
											o_pmem_rd_en0 <= 0;
											o_pmem_rd_en1 <= 0;
										end
										else begin
											// sliding rf is full, do the computation
											compute_statrt <= 1;
											o_shift <= 0;
											if (i_stride==4'd1) begin
												if (wgt_shift_count == 0) begin
													o_wgt_shift <= 0;

													o_pmem_wr_en0 <= ~xmove_count[0];
													o_pmem_wr_en1 <= xmove_count[0];
													o_pmem_wr_addr0 <= psum_base_addr[0];
													o_pmem_wr_addr1 <= psum_base_addr[0];

													o_pmem_rd_en0 <= 1;
													o_pmem_rd_en1 <= 1;
													o_pmem_rd_addr0 <= psum_base_addr[1];
													o_pmem_rd_addr1 <= psum_base_addr[1];
													wgt_shift_count <= wgt_shift_count+1;
												end
												else if (wgt_shift_count == 1) begin
													o_wgt_shift <= 1;

													if(xmove_count>0) begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_en1 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[1];
														o_pmem_wr_addr1 <= psum_base_addr[1];
													end
													else begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[1];
														o_pmem_wr_en1 <= 0;
														o_pmem_wr_addr1 <= psum_base_addr[1];
													end

													o_pmem_rd_en0 <= 1;
													o_pmem_rd_en1 <= 1;
													o_pmem_rd_addr0 <= psum_base_addr[2];
													o_pmem_rd_addr1 <= psum_base_addr[2];
												
													wgt_shift_count <= wgt_shift_count+1;
												end
												else if (wgt_shift_count == 2) begin
													o_wgt_shift <= 2;
													wgt_shift_finish <= 1;
													if(xmove_count>0) begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_en1 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[2];
														o_pmem_wr_addr1 <= psum_base_addr[2];
													end
													else begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_en1 <= 0;
														o_pmem_wr_addr0 <= psum_base_addr[2];
														o_pmem_wr_addr1 <= psum_base_addr[2];
													end


													o_pmem_rd_en0 <= ~xmove_count[0];
													o_pmem_rd_en1 <= xmove_count[0];
													o_pmem_rd_addr0 <= psum_base_addr[0];
													o_pmem_rd_addr1 <= psum_base_addr[0];

												
													wgt_shift_count <= 0;

													sld_count <= sld_count-2;
												end
												
											end
										end


									end
									2'b01: begin
										// 4x4 mode
										if (sld_count<3'd4) begin
											wgt_shift_finish <= 0;
											o_shift <= 1;
											sld_count <= sld_count+1'b1;
											o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
											o_pmem_wr_en0 <= 0;
											o_pmem_wr_en1 <= 0;
											o_pmem_rd_en0 <= 0;
											o_pmem_rd_en1 <= 0;
										end
										else begin 
											compute_statrt <= 1;
											o_shift <= 0;
											if (i_stride==4'd1) begin
												if (wgt_shift_count == 0) begin
													o_wgt_shift <= 0;

													o_pmem_wr_en0 <= ~xmove_count[0];
													o_pmem_wr_en1 <= xmove_count[0];
													o_pmem_wr_addr0 <= psum_base_addr[0];
													o_pmem_wr_addr1 <= psum_base_addr[0];

													o_pmem_rd_en0 <= 1;
													o_pmem_rd_en1 <= 1;
													o_pmem_rd_addr0 <= psum_base_addr[1];
													o_pmem_rd_addr1 <= psum_base_addr[1];
													wgt_shift_count <= wgt_shift_count+1;
												end
												else if (wgt_shift_count == 1) begin
													o_wgt_shift <= 1;
													if(xmove_count>0) begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_en1 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[1];
														o_pmem_wr_addr1 <= psum_base_addr[1];
													end
													else begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[1];
													end

													o_pmem_rd_en0 <= 1;
													o_pmem_rd_en1 <= 1;
													o_pmem_rd_addr0 <= psum_base_addr[2];
													o_pmem_rd_addr1 <= psum_base_addr[2];
													wgt_shift_count <= wgt_shift_count+1;
												end
												else if (wgt_shift_count == 2) begin
													o_wgt_shift <= 2;
													if(xmove_count>0) begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_en1 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[2];
														o_pmem_wr_addr1 <= psum_base_addr[2];
													end
													else begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_en1 <= 0;
														o_pmem_wr_addr0 <= psum_base_addr[2];
														o_pmem_wr_addr1 <= psum_base_addr[2];
													end

													o_pmem_rd_en0 <= 1;
													o_pmem_rd_en1 <= 1;
													o_pmem_rd_addr0 <= psum_base_addr[3];
													o_pmem_rd_addr1 <= psum_base_addr[3];
													wgt_shift_count <= 3;
												end
												else if (wgt_shift_count == 3) begin
													wgt_shift_finish <= 1;
													sld_count <= sld_count-1;

													o_wgt_shift <= 3;
													if(xmove_count>0) begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[3];
														o_pmem_wr_en1 <= 1;
														o_pmem_wr_addr1 <= psum_base_addr[3];
													end
													else begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_en1 <= 0;
														o_pmem_wr_addr0 <= psum_base_addr[3];
														o_pmem_wr_addr1 <= psum_base_addr[3];
													end

													o_pmem_rd_en0 <= ~xmove_count[0];
													o_pmem_rd_en1 <= xmove_count[0];
													o_pmem_rd_addr0 <= psum_base_addr[0];
													wgt_shift_count <= 0;
												end
											end
											// TO DO: strides!=1
										end

									end

									2'b10: begin
										// 5x5 mode
										if (sld_count<3'd5) begin
											wgt_shift_finish <= 0;
											o_shift <= 1;
											sld_count <= sld_count+1'b1;
											o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
											o_pmem_wr_en0 <= 0;
											o_pmem_wr_en1 <= 0;
											o_pmem_rd_en0 <= 0;
											o_pmem_rd_en1 <= 0;
										end
										else begin
											compute_statrt <= 1;
											o_shift <= 0;
											if (i_stride==4'd1) begin
												if (wgt_shift_count == 0) begin
													o_wgt_shift <= 0;
								
													o_pmem_wr_en0 <= ~xmove_count[0];
													o_pmem_wr_en1 <= xmove_count[0];
													o_pmem_wr_addr0 <= psum_base_addr[0];
													o_pmem_wr_addr1 <= psum_base_addr[0];

													o_pmem_rd_en0 <= 1;
													o_pmem_rd_en1 <= 1;
													o_pmem_rd_addr0 <= psum_base_addr[1];
													o_pmem_rd_addr1 <= psum_base_addr[1];
													wgt_shift_count <= wgt_shift_count+1;
												end
												else if (wgt_shift_count == 1) begin
													o_wgt_shift <= 1;
													if(xmove_count>0) begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_en1 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[1];
														o_pmem_wr_addr1 <= psum_base_addr[1];
													end
													else begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[1];
														o_pmem_wr_en1 <= 0;
														o_pmem_wr_addr1 <= psum_base_addr[1];
													end


													o_pmem_rd_en0 <= 1;
													o_pmem_rd_en1 <= 1;
													o_pmem_rd_addr0 <= psum_base_addr[2];
													o_pmem_rd_addr1 <= psum_base_addr[2];
													wgt_shift_count <= wgt_shift_count+1;
												end
												else if (wgt_shift_count == 2) begin
													o_wgt_shift <= 2;
													if(xmove_count>0) begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_en1 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[2];
														o_pmem_wr_addr1 <= psum_base_addr[2];
													end
													else begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[2];
														o_pmem_wr_en1 <= 0;
														o_pmem_wr_addr1 <= psum_base_addr[2];
													end

													o_pmem_rd_en0 <= 1;
													o_pmem_rd_en1 <= 1;
													o_pmem_rd_addr0 <= psum_base_addr[3];
													o_pmem_rd_addr0 <= psum_base_addr[3];
													wgt_shift_count <= wgt_shift_count+1;
												end
												else if (wgt_shift_count == 3) begin
													o_wgt_shift <= 3;
													if(xmove_count>0) begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_en1 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[3];
														o_pmem_wr_addr1 <= psum_base_addr[3];
													end
													else begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[3];
														o_pmem_wr_en1 <= 0;
														o_pmem_wr_addr1 <= psum_base_addr[3];
													end

													o_pmem_rd_en0 <= 1;
													o_pmem_rd_en1 <= 1;
													o_pmem_rd_addr0 <= psum_base_addr[4];
													o_pmem_rd_addr0 <= psum_base_addr[4];
													wgt_shift_count <= wgt_shift_count+1;
												end
												else if (wgt_shift_count == 4) begin
													wgt_shift_finish <= 1;
													sld_count <= sld_count-1;

													o_wgt_shift <= 4;
													if(xmove_count>0) begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[4];
														o_pmem_wr_en1 <= 1;
														o_pmem_wr_addr1 <= psum_base_addr[4];
													end
													else begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[4];
														o_pmem_wr_en1 <= 0;
														o_pmem_wr_addr1 <= psum_base_addr[4];
													end

													o_pmem_rd_en0 <= ~xmove_count[0];
													o_pmem_rd_en1 <= xmove_count[0];
													o_pmem_rd_addr0 <= psum_base_addr[0];
													wgt_shift_count <= 0;
												end
											end
											// TO DO: strides!=1
										end

									end
									2'b11: begin
										// 6x6 mode
										if (sld_count<3'd6) begin
											wgt_shift_finish <= 0;
											o_shift <= 1;
											sld_count <= sld_count+1'b1;
											o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
											o_pmem_wr_en0 <= 0;
											o_pmem_wr_en1 <= 0;
											o_pmem_rd_en0 <= 0;
											o_pmem_rd_en1 <= 0;
										end
										else begin
											compute_statrt <= 1;
											o_shift <= 0;
											if (i_stride==4'd1) begin
												if (wgt_shift_count == 0) begin
													o_wgt_shift <= 0;

													o_pmem_wr_en0 <= ~xmove_count[0];
													o_pmem_wr_en1 <= xmove_count[0];
													o_pmem_wr_addr0 <= psum_base_addr[0];
													o_pmem_wr_addr1 <= psum_base_addr[0];

													o_pmem_rd_en0 <= 1;
													o_pmem_rd_en1 <= 1;
													o_pmem_rd_addr0 <= psum_base_addr[1];
													o_pmem_rd_addr1 <= psum_base_addr[1];
													wgt_shift_count <= wgt_shift_count+1;
												end
												else if (wgt_shift_count == 1) begin
													o_wgt_shift <= 1;
													if(xmove_count>0) begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_en1 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[1];
														o_pmem_wr_addr1 <= psum_base_addr[1];
													end
													else begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[1];
														o_pmem_wr_en1 <= 0;
														o_pmem_wr_addr1 <= psum_base_addr[1];
													end

													o_pmem_rd_en0 <= 1;
													o_pmem_rd_en1 <= 1;
													o_pmem_rd_addr0 <= psum_base_addr[2];
													o_pmem_rd_addr1 <= psum_base_addr[2];
													wgt_shift_count <= wgt_shift_count+1;
												end
												else if (wgt_shift_count == 2) begin
													o_wgt_shift <= 2;
													if(xmove_count>0) begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_en1 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[2];
														o_pmem_wr_addr1 <= psum_base_addr[2];
													end
													else begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_en1 <= 0;
														o_pmem_wr_addr0 <= psum_base_addr[2];
													end

													o_pmem_rd_en0 <= 1;
													o_pmem_rd_en1 <= 1;
													o_pmem_rd_addr0 <= psum_base_addr[3];
													o_pmem_rd_addr1 <= psum_base_addr[3];
													wgt_shift_count <= wgt_shift_count+1;
												end
												else if (wgt_shift_count == 3) begin
													o_wgt_shift <= 3;
													if(xmove_count>0) begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_en1 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[3];
														o_pmem_wr_addr1 <= psum_base_addr[3];
													end
													else begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_en1 <= 0;
														o_pmem_wr_addr0 <= psum_base_addr[3];
													end

													o_pmem_rd_en0 <= 1;
													o_pmem_rd_en1 <= 1;
													o_pmem_rd_addr0 <= psum_base_addr[4];
													o_pmem_rd_addr1 <= psum_base_addr[4];
													wgt_shift_count <= wgt_shift_count+1;
												end
												else if (wgt_shift_count == 4) begin
													o_wgt_shift <= 4;
													if(xmove_count>0) begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_en1 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[4];
														o_pmem_wr_addr1 <= psum_base_addr[4];
													end
													else begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_en1 <= 0;
														o_pmem_wr_addr0 <= psum_base_addr[4];
													end

													o_pmem_rd_en0 <= 1;
													o_pmem_rd_en1 <= 1;
													o_pmem_rd_addr0 <= psum_base_addr[5];
													o_pmem_rd_addr1 <= psum_base_addr[5];
													wgt_shift_count <= 5;
												end
												else if (wgt_shift_count == 5) begin
													wgt_shift_finish <= 1;
													sld_count <= sld_count-1;

													o_wgt_shift <= 5;
													if(xmove_count>0) begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_addr0 <= psum_base_addr[5];
														o_pmem_wr_en1 <= 1;
														o_pmem_wr_addr1 <= psum_base_addr[5];
													end
													else begin
														o_pmem_wr_en0 <= 1;
														o_pmem_wr_en1 <= 0;
														o_pmem_wr_addr0 <= psum_base_addr[5];
													end

													o_pmem_rd_en0 <= ~xmove_count[0];
													o_pmem_rd_en1 <= xmove_count[0];
													o_pmem_rd_addr0 <= psum_base_addr[0];
													o_pmem_rd_addr1 <= psum_base_addr[0];
													wgt_shift_count <= 0;
												end
											end
											// TO DO: strides!=1
										end

									end
								endcase

							end
						end
					end
				end

				BURST: begin

					if (i_pool==0) begin
						if (xmove_count<=i_xmove) begin
							o_dma_wr_en <= dma_wr_flag;
							dma_wr_flag <= ~dma_wr_flag;
							if (dma_wr_flag) begin
								if (o_pmem_rd_en0) o_dma_wr_data[15:8] <= i_pmem_rd_data0;
								else o_dma_wr_data[15:8] <= i_pmem_rd_data1;
							end
							else begin
								if (o_pmem_rd_en0) o_dma_wr_data[7:0] <= i_pmem_rd_data0;
								else o_dma_wr_data[7:0] <= i_pmem_rd_data1;
							end
							o_dma_wr_addr <= dma_wr_flag?(o_dma_wr_addr+1):o_dma_wr_addr;

							o_pmem_rd_en0 <= ~xmove_count[0];
							o_pmem_rd_en1 <= xmove_count[0];
							if (ymove_count<=psum_base_addr[0]) begin
								o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
								o_pmem_rd_addr1 <= o_pmem_rd_addr1+1;
								ymove_count <= ymove_count+1;
							end
							else begin
								ymove_count <= 0;
								xmove_count <= xmove_count+1;
								if (xmove_count[0]) begin
									o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
									o_pmem_rd_addr1 <= o_pmem_rd_addr1+1;
								end
								else begin
									o_pmem_rd_addr0 <= o_pmem_rd_addr0-psum_base_addr[0];
									o_pmem_rd_addr1 <= o_pmem_rd_addr1-psum_base_addr[0];
								end
							end
						end
						else begin
							o_pmem_rd_en0 <= 0;
							o_pmem_rd_en1 <= 0;
							status <= RESET;
						end
					end
					else begin // 2x2 max pool
						if (xmove_count<=i_xmove) begin
							case (i_mode)
								2'b00: begin
									if (ymove_count==psum_base_addr[3]) begin
										xmove_count <= xmove_count+1;
										ymove_count <= 0;
									end
									else begin
										ymove_count <= ymove_count+1;
									end
									case (pool_count)
										2'b00: begin
											if (ymove_count<psum_base_addr[2]) begin
												o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
												o_pmem_rd_en0 <= 1;
												o_pmem_rd_en1 <= 0;

												o_dma_wr_data[7:0] <= i_pmem_rd_data0;
												o_dma_wr_data[15:0] <= 0;
											end
											else begin
												o_pmem_rd_addr1 <= o_pmem_rd_addr1+1;
												o_pmem_rd_en0 <= 0;
												o_pmem_rd_en1 <= 1;

												o_dma_wr_data[7:0] <= i_pmem_rd_data1;
												o_dma_wr_data[15:0] <= 0;
											end
										end
										2'b01: begin
											if(ymove_count>psum_base_addr[1]) begin
												if (ymove_count<psum_base_addr[2]) begin
													o_pmem_rd_addr1 <= (o_pmem_rd_addr1==0)?0:(o_pmem_rd_addr1+1);
													o_pmem_rd_en0 <= 0;
													o_pmem_rd_en1 <= 1;

													if (i_pmem_rd_data0>o_dma_wr_data[7:0]) begin
														o_dma_wr_data[7:0] <= i_pmem_rd_data0;
														o_dma_wr_data[15:0] <= 1;
													end
												end
												else begin
													o_pmem_rd_addr1 <= o_pmem_rd_addr1+i_ymove;
													o_pmem_rd_en0 <= 0;
													o_pmem_rd_en1 <= 1;

													if (i_pmem_rd_data1>o_dma_wr_data[7:0]) begin
														o_dma_wr_data[7:0] <= i_pmem_rd_data1;
														o_dma_wr_data[15:0] <= 1;
													end
												end
											end
											else begin
												o_pmem_rd_addr0 <= o_pmem_rd_addr0+i_ymove;
												o_pmem_rd_en0 <= 1;
												o_pmem_rd_en1 <= 0;

												if (i_pmem_rd_data0>o_dma_wr_data[7:0]) begin
													o_dma_wr_data[7:0] <= i_pmem_rd_data0;
													o_dma_wr_data[15:0] <= 1;
												end
											end
										end
										2'b10: begin
											if (ymove_count<psum_base_addr[1]) begin
												o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
												o_pmem_rd_en0 <= 1;
												o_pmem_rd_en1 <= 0;

												if (i_pmem_rd_data0>o_dma_wr_data[7:0]) begin
													o_dma_wr_data[7:0] <= i_pmem_rd_data0;
													o_dma_wr_data[15:0] <= 2;
												end
											end
											else begin
												o_pmem_rd_addr1 <= o_pmem_rd_addr1+1;
												o_pmem_rd_en0 <= 0;
												o_pmem_rd_en1 <= 1;

												if (i_pmem_rd_data1>o_dma_wr_data[7:0]) begin
													o_dma_wr_data[7:0] <= i_pmem_rd_data1;
													o_dma_wr_data[15:0] <= 2;
												end
											end	
										end
										2'b11: begin
											o_dma_wr_en <= 1;
											o_dma_wr_addr <= o_dma_wr_addr+1;
											if(ymove_count>psum_base_addr[1]) begin
												if (i_pmem_rd_data1>o_dma_wr_data[7:0]) begin
													o_dma_wr_data[7:0] <= i_pmem_rd_data1;
													o_dma_wr_data[15:0] <= 3;
												end

												if (ymove_count<=psum_base_addr[2]) begin
													if (ymove_count==psum_base_addr[2]) begin
														o_pmem_rd_addr1 <= o_pmem_rd_addr1+1;
														o_pmem_rd_en0 <= 0;
														o_pmem_rd_en1 <= 1;
													end
													else begin
														o_pmem_rd_addr0 <= (o_pmem_rd_addr0+1);
														o_pmem_rd_en0 <= 1;
														o_pmem_rd_en1 <= 0;
													end
												end
												else begin
													if (ymove_count==psum_base_addr[3]) begin
														o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
														o_pmem_rd_en1 <= 0;
														o_pmem_rd_en0 <= 1;
													end
													else begin
														o_pmem_rd_addr1 <= o_pmem_rd_addr1-i_ymove;
														o_pmem_rd_en1 <= 1;
														o_pmem_rd_en0 <= 0;
													end
												end
											end
											else begin
												if (i_pmem_rd_data0>o_dma_wr_data[7:0]) begin
													o_dma_wr_data[7:0] <= i_pmem_rd_data0;
													o_dma_wr_data[15:0] <= 3;
												end

												if (ymove_count==psum_base_addr[1]) begin
													o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
													o_pmem_rd_en1 <= 0;
													o_pmem_rd_en0 <= 1;
												end
												else begin
													o_pmem_rd_addr0 <= o_pmem_rd_addr0-i_ymove;
													o_pmem_rd_en1 <= 0;
													o_pmem_rd_en0 <= 1;
												end
											end
										end
									endcase
								end
								2'b01: begin
									
								end
								2'b10: begin
									
								end
								2'b11: begin
									
								end
							endcase
						end
					end
				end
			endcase
		end
	end

endmodule










