// nn_fsm

module drlp_fsm
#(parameter
	DATA_WIDTH = 8,
	PE_NUM = 16,
	DMA_ADDR_WIDTH = 32,
	DMA_ADDR_BASE_WIDTH = 5,
	COLUMN_NUM = 6,
	ROW_NUM = 6,
	PMEM_ADDR_WIDTH = 7,
	WMEM_ADDR_WIDTH = 6,
	IMEM_ADDR_WIDTH = 12, // depth = 4096, 24KB
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
	input i_pool,
	input [2:0] i_stride,
	input [5:0] i_xmove,
	input [7:0] i_zmove,
	input [7:0] i_ymove,
	input [IMEM_ADDR_WIDTH-1:0] i_img_wr_count,
	input i_result_scale, // 0: w/i scale; 1: w/o scale
	input [2:0] i_result_shift,
	input i_img_bf_update,
	input i_wgt_mem_update,
	input i_bias_psum,
	input i_wo_compute,

	input [DMA_ADDR_WIDTH-1:0] i_dma_img_base_addr,
	input [DMA_ADDR_WIDTH-1:0] i_dma_wgt_base_addr,
	input [DMA_ADDR_WIDTH-1:0] i_dma_wr_base_addr,

	// from PE
	input signed [15:0] i_pmem_rd_data0,
	input signed [15:0] i_pmem_rd_data1,

	// from mesh
	input i_hand_shaked,

	// from buffer
	input [47:0] i_buffer_data,
	input i_buffer_ready,
	// input i_dma_rd_ready,

	output reg o_dma_rd_en,
	output reg o_last,
	output reg [DMA_ADDR_WIDTH-1:0] o_dma_base_addr,

	output reg o_img_bf_wr_en,
	// output reg o_img_bf_rd_en,
	output reg [IMEM_ADDR_WIDTH-1:0] o_img_bf_wr_addr,
	output reg [IMEM_DATA_WIDTH-1:0] o_img_bf_wr_data,
	output reg [IMEM_ADDR_WIDTH-1:0] o_img_bf_rd_addr,

	// to sliding
	output reg o_shift,
	output reg o_3x3,

	output reg [COLUMN_NUM-1:0] o_wmem_wr_en,
	output reg [WMEM_ADDR_WIDTH-1:0] o_wmem_wr_addr,
	output reg [ROW_DATA_WIDTH-1:0] o_wmem_wr_data,
	output reg [WMEM_ADDR_WIDTH-1:0] o_wmem_rd_addr,

	output reg [2:0] o_wgt_shift,

	output reg o_bias_sel, // 0: add bias; 1: add psum
	output reg [DATA_WIDTH-1:0] o_bias,
	output reg o_update_bias,

	output wire o_psum_sel,

	output reg o_pmem_wr_en0,
	output reg o_pmem_wr_en1,
	output reg o_pmem_rd_en0,
	output reg o_pmem_rd_en1,
	output reg [PMEM_ADDR_WIDTH-1:0] o_pmem_wr_addr0,
	output reg [PMEM_ADDR_WIDTH-1:0] o_pmem_wr_addr1,
	output reg [PMEM_ADDR_WIDTH-1:0] o_pmem_rd_addr0,
	output reg [PMEM_ADDR_WIDTH-1:0] o_pmem_rd_addr1,
	output reg [3:0] o_PE_sel, 
	output reg o_update_wgt,

	output reg o_dma_wr_en,
	output reg [DMA_ADDR_WIDTH-1:0] o_dma_wr_addr,
	output reg [31:0] o_dma_wr_data,

	output reg o_finish

);
	localparam RESET = 2'b00; // initial/reset
	localparam WRIBF = 2'b01; // write image buffer
	localparam COMPT = 2'b10; // compute, write wight buffer and the same time
	localparam BURST = 2'b11; // burst out result (relu/pool)

	reg [1:0] status; // 2'b00: initial/reset; 2'b01: wrt img bf
					  // 2'b10: compute/wrt wgt bf; 2'b11: burst (relu/pool) 

	reg [IMEM_ADDR_WIDTH-1:0] img_wr_count; // check with o_img_bf_wr_addr
	reg [7:0] wgt_wr_count;

	reg [COLUMN_NUM-1:0] wmem_wr_which;
	reg [COLUMN_NUM-1:0] wmem_wr_row_end;

	reg [8:0] ymove_count;
	reg [5:0] xmove_count;
	reg [6:0] zmove_count;

	reg [2:0] sld_count;

	reg [2:0] wgt_shift_count;

	reg [PMEM_ADDR_WIDTH-1:0] psum_base_addr [0:5];


	reg compute_start;

	reg wgt_shift_finish;

	reg [3:0] status_reset;

	reg [1:0] pool_position;
	reg [1:0] pool_count;

	reg pmem_rd_en0_d1;
	reg pmem_rd_en1_d1;

	reg wmem_wr_start;

	reg signed [15:0] pmem_rd_data0_shifted;
	reg signed [15:0] pmem_rd_data1_shifted;
	reg signed [7:0] pmem_rd_data0;
	reg signed [7:0] pmem_rd_data1;

	reg [2:0] wr_flag;
	reg dma_wr_en;
	reg signed [7:0] dma_wr_data;
	reg [7:0] dma_wr_data2;
	reg signed [7:0] dma_wr_data_reg[0:2];
	reg [7:0] dma_wr_data2_reg[0:2];
	reg signed [7:0] dma_wr_data_wire;
	reg [7:0] dma_wr_data2_wire;

	reg dma_hand_shaked;

	reg pre_finish;
	
	reg [3:0] PE_sel;
	
	assign o_psum_sel = ~xmove_count[0];

	always @(posedge i_clk) begin
		pmem_rd_en0_d1 <= o_pmem_rd_en0;
		pmem_rd_en1_d1 <= o_pmem_rd_en1;
	end

	always @(*) begin
		case(status)
			RESET: o_dma_base_addr = 0;
			WRIBF: o_dma_base_addr = i_dma_img_base_addr;
			COMPT: o_dma_base_addr = i_dma_wgt_base_addr;
			// BURST: o_dma_base_addr = i_dma_wgt_base_addr;
			default: o_dma_base_addr = 0;
		endcase
	end

	always @(*) begin
		pmem_rd_data0_shifted = i_pmem_rd_data0 >>> (i_result_shift+1);
		pmem_rd_data1_shifted = i_pmem_rd_data1 >>> (i_result_shift+1);
		if (pmem_rd_data0_shifted[15]) begin
			if (&(pmem_rd_data0_shifted[15:DATA_WIDTH-1]))
				pmem_rd_data0 = pmem_rd_data0_shifted[DATA_WIDTH-1:0];
			else 
				pmem_rd_data0 = 8'b1000_0000;
		end
		else begin
			if(~(|(pmem_rd_data0_shifted[15:DATA_WIDTH-1])))
				pmem_rd_data0 = pmem_rd_data0_shifted[DATA_WIDTH-1:0];

			else
				pmem_rd_data0 = 8'b0111_1111;
		end
		if (pmem_rd_data1_shifted[15]) begin
			if (&(pmem_rd_data1_shifted[15:DATA_WIDTH-1]))
				pmem_rd_data1 = pmem_rd_data1_shifted[DATA_WIDTH-1:0];
			else
				pmem_rd_data1 = 8'b1000_0000;
		end
		else begin
			if(~(|(pmem_rd_data1_shifted[15:DATA_WIDTH-1])))
				pmem_rd_data1 = pmem_rd_data1_shifted[DATA_WIDTH-1:0];
			else
				pmem_rd_data1 = 8'b0111_1111;
		end
	end

	always @(posedge i_clk) begin
		if (i_rst) begin
			status <= 2'b00;
			o_finish <= 0;
			pre_finish <= 0;
		end
		else if (dma_hand_shaked) begin
			case (status)
				RESET: begin
					o_finish <= 0;
					pre_finish <= 0;
					// o_dma_rd_addr <= 0;
					o_dma_rd_en <= 0;
					o_img_bf_wr_addr <= 12'b1111_1111_1111;
					//o_img_bf_wr_addr <= 0;
					o_img_bf_wr_data <= 0;
					o_img_bf_wr_en <= 0;
					// o_img_bf_rd_addr <= 10'b11_1111_1111;
					// o_img_bf_rd_en <= 0;
					o_img_bf_rd_addr <= 10'b0;
					// wr_flag <= 3'd0;
					img_wr_count <= 0;
					wgt_wr_count <= 0;
					// o_wmem0_state <= 0;
					// o_wmem1_state <= 0;
					wmem_wr_which <= 6'b0000_00;
					wmem_wr_row_end <= 0;
					o_wmem_wr_addr <= 7'b0;
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

					// o_dma_wr_addr <= 0;
					
					wgt_shift_finish<=0;

					status_reset <= 0;
					pool_position <= 0;
					pool_count <= 0;

					wmem_wr_start<= 0;

					o_PE_sel<=0;
					o_last <= 0;
					PE_sel<=0;
					o_wmem_wr_en <= 0;
					if (i_start) begin

						wgt_wr_count <= i_wgt_mem_update?0:(i_zmove+1);

						if (i_img_bf_update) begin
							status <= WRIBF;
							// o_dma_rd_addr <= i_dma_img_base_addr;
							// initial psum_base_addr
							psum_base_addr[0] <= 0;
							psum_base_addr[1] <= i_ymove+1;
							psum_base_addr[2] <= (i_ymove+1)<<1;
							psum_base_addr[3] <= (i_ymove+1)+((i_ymove+1)<<1);
							psum_base_addr[4] <= (i_ymove+1)<<2;
							psum_base_addr[5] <= (i_ymove+1)+((i_ymove+1)<<2);
						end
						else if(i_wo_compute) begin
							status <= BURST;
							case(i_mode)
								2'b00: begin
									if (i_stride==3'd1) begin
										psum_base_addr[0] <= (i_ymove+1)*3-1;
									end
									else begin
										psum_base_addr[0] <= i_ymove;
									end
								end
								2'b01: begin 
									if (i_stride==3'd1) begin
										psum_base_addr[0] <= (i_ymove+1)*4-1;
									end
									else if (i_stride==3'd2) begin
										psum_base_addr[0] <= (i_ymove+1)*2-1;
									end
									else begin
										psum_base_addr[0] <= i_ymove;
									end
								end
								2'b10: begin
									if (i_stride==3'd1) begin
										psum_base_addr[0] <= (i_ymove+1)*5-1;
									end
									else begin
										psum_base_addr[0] <= i_ymove;
									end
								end
								2'b11: begin
									if (i_stride==3'd1) begin
										psum_base_addr[0] <= (i_ymove+1)*6-1;
									end
									else begin
										psum_base_addr[0] <= i_ymove;
									end
								end
							endcase
							psum_base_addr[1] <= ((i_ymove+1)<<1);
							psum_base_addr[2] <= (i_stride==3'b010)?((i_ymove+1)*2):((i_ymove+1)*4);
							psum_base_addr[3] <= (i_stride==3'b010)?((i_ymove+1)*3):((i_ymove+1)*6);
							psum_base_addr[4] <= (i_ymove+1)*8;
							psum_base_addr[5] <= (i_ymove+1)*10;
						end
						else begin
							status <= COMPT;
							psum_base_addr[0] <= 0;
							psum_base_addr[1] <= i_ymove+1;
							psum_base_addr[2] <= (i_ymove+1)<<1;
							psum_base_addr[3] <= (i_ymove+1)+((i_ymove+1)<<1);
							psum_base_addr[4] <= (i_ymove+1)<<2;
							psum_base_addr[5] <= (i_ymove+1)+((i_ymove+1)<<2);
						end
						
						// o_dma_rd_en <= 1;
						// o_dma_wr_addr <= i_dma_wr_base_addr;
						compute_start <= 0;
						o_finish <= 0;
					end			
				end

				WRIBF: begin
					if (img_wr_count == i_img_wr_count) begin
						o_dma_rd_en <= 0;
						o_PE_sel <= 4'd15;
						img_wr_count <= 0;
						o_img_bf_wr_en <= 0;
						status <= COMPT;
						case (i_mode)
							2'b00: wmem_wr_row_end <= 6'b10_0000;
							2'b01: wmem_wr_row_end <= 6'b00_1000;
							2'b10: wmem_wr_row_end <= 6'b01_0000;
							2'b11: wmem_wr_row_end <= 6'b10_0000;
						endcase
						o_last <= 0;
					end
					else begin
						if (i_buffer_ready) begin
							o_img_bf_wr_data <= i_buffer_data;
							img_wr_count <= img_wr_count+1'b1;
							
							if((img_wr_count+1'b1)==(i_img_wr_count-1'b1)) o_last<=1;
							else o_last<=0;
							
							o_img_bf_wr_en <= 1;
							o_img_bf_wr_addr <= o_img_bf_wr_addr + 1'b1;

							if (img_wr_count+1'b1 == i_img_wr_count) begin
								o_dma_rd_en <= 0;
							end
							else begin
								o_dma_rd_en <= 1;
							end
						end
						else begin
							o_dma_rd_en <= 1;
							o_img_bf_wr_en <= 0;
						end
					end
				end

				COMPT: begin
					o_img_bf_wr_en <= 0;
					if(status_reset<4'b1111) begin
						status_reset <= status_reset+1;
					end
					else begin

						// Write weight buffer
						if (wgt_wr_count > i_zmove) begin
							o_wmem_wr_en <= 0;
							o_wmem_wr_addr <= 7'b0;
							o_update_bias <= 0;
							o_dma_rd_en <= 0;
						end
						else begin
							o_dma_rd_en <= 1;
						end

						if (i_buffer_ready) begin
							if (wmem_wr_which == 6'b0000_00) begin
								o_update_bias <= 1;
								o_bias <= i_buffer_data[7:0];
								o_PE_sel <= o_PE_sel+1;
								o_wmem_wr_en <= 0;
								if (o_PE_sel == 4'd14) begin
									wmem_wr_which <= 6'b0000_01;
								end
							end
							else begin
								o_update_bias <= 0;
								o_wmem_wr_data <= i_buffer_data;
								o_wmem_wr_en <= wmem_wr_which;

								if (wmem_wr_which == 6'b0000_01) begin
									o_PE_sel <= o_PE_sel+1;
									wmem_wr_start <= 1;
									if (wmem_wr_start) begin
										if (o_PE_sel == 4'd15) begin
											wgt_wr_count <= wgt_wr_count+1'b1;
											o_wmem_wr_addr <= o_wmem_wr_addr + 1'b1;
										end
									end
								end

								if (wmem_wr_which == wmem_wr_row_end) begin
									wmem_wr_which <= 6'b0000_01;
								end
								else begin
									wmem_wr_which <= wmem_wr_which << 1;
								end	
							end
						end
					
						if (wgt_wr_count>zmove_count) begin

							if (wgt_shift_finish) begin
								wgt_shift_finish <= 0;
								if (ymove_count==i_ymove) begin
									ymove_count <= 0;
									if (xmove_count==i_xmove) begin
										xmove_count <= 0;
										if ((zmove_count+1)==i_zmove) begin
											// COMPUTATION FINISHED
											// GO TO BURST
											status <= BURST;
											status_reset <= 0;
											zmove_count <= 0;
											xmove_count <= 0;
											ymove_count <= 0;
											o_pmem_rd_en0 <= 0;
											o_pmem_rd_en1 <= 0;
											o_pmem_rd_addr0 <= 0;
											o_pmem_rd_addr1 <= 0;
											// o_dma_wr_addr <= -1;
											pool_count <= 2'd3;
											o_PE_sel <= 0;
											case(i_mode)
												2'b00: begin
													if (i_stride==3'd1) begin
														psum_base_addr[0] <= (i_ymove+1)*3-1;
													end
													else begin
														psum_base_addr[0] <= i_ymove;
													end
												end
												2'b01: begin 
													if (i_stride==3'd1) begin
														psum_base_addr[0] <= (i_ymove+1)*4-1;
													end
													else if (i_stride==3'd2) begin
														psum_base_addr[0] <= (i_ymove+1)*2-1;
													end
													else begin
														psum_base_addr[0] <= i_ymove;
													end
												end
												2'b10: begin
													if (i_stride==3'd1) begin
														psum_base_addr[0] <= (i_ymove+1)*5-1;
													end
													else begin
														psum_base_addr[0] <= i_ymove;
													end
												end
												2'b11: begin
													if (i_stride==3'd1) begin
														psum_base_addr[0] <= (i_ymove+1)*6-1;
													end
													else begin
														psum_base_addr[0] <= i_ymove;
													end
												end
											endcase
											psum_base_addr[1] <= ((i_ymove+1)<<1);
											psum_base_addr[2] <= (i_stride==3'b010)?((i_ymove+1)*2):((i_ymove+1)*4);
											psum_base_addr[3] <= (i_stride==3'b010)?((i_ymove+1)*3):((i_ymove+1)*6);
											psum_base_addr[4] <= (i_ymove+1)*8;
											psum_base_addr[5] <= (i_ymove+1)*10;
										end
										else begin
											zmove_count <= zmove_count+1;
											psum_base_addr[0] <= 0;
											psum_base_addr[1] <= i_ymove+1;
											psum_base_addr[2] <= (i_ymove+1)<<1;
											psum_base_addr[3] <= (i_ymove+1)+((i_ymove+1)<<1);
											psum_base_addr[4] <= (i_ymove+1)<<2;
											psum_base_addr[5] <= (i_ymove+1)+((i_ymove+1)<<2);
										end 
									end
									else begin 
										xmove_count <= xmove_count+1;
										if(xmove_count[0])
											case(i_mode)
												2'b00: begin
													if (i_stride==3'd1) begin
														psum_base_addr[0] <= psum_base_addr[2]+1;
														psum_base_addr[1] <= psum_base_addr[2]+(i_ymove+1)+1;
														psum_base_addr[2] <= psum_base_addr[2]+((i_ymove+1)*2)+1;
													end
													else begin
														psum_base_addr[0] <= psum_base_addr[0]+1;
													end
												end
												2'b01: begin
													if (i_stride==3'd1) begin
														psum_base_addr[0] <= psum_base_addr[3]+1;
														psum_base_addr[1] <= psum_base_addr[3]+(i_ymove+1)+1;
														psum_base_addr[2] <= psum_base_addr[3]+(i_ymove+1)*2+1;
														psum_base_addr[3] <= psum_base_addr[3]+(i_ymove+1)*3+1;
													end
													else if (i_stride==3'd2) begin
														psum_base_addr[0] <= psum_base_addr[1]+1;
														psum_base_addr[1] <= psum_base_addr[1]+(i_ymove+1)+1;
													end
													else begin
														psum_base_addr[0] <= psum_base_addr[0]+1;
													end
												end
												2'b10: begin
													if (i_stride==3'd1) begin
														psum_base_addr[0] <= psum_base_addr[4]+1;
														psum_base_addr[1] <= psum_base_addr[4]+(i_ymove+1)+1;
														psum_base_addr[2] <= psum_base_addr[4]+(i_ymove+1)*2+1;
														psum_base_addr[3] <= psum_base_addr[4]+(i_ymove+1)*3+1;
														psum_base_addr[4] <= psum_base_addr[4]+(i_ymove+1)*4+1;
													end
													else begin
														psum_base_addr[0] <= psum_base_addr[0]+1;
													end
												end
												2'b11: begin
													if (i_stride==3'd1) begin
														psum_base_addr[0] <= psum_base_addr[5]+1;
														psum_base_addr[1] <= psum_base_addr[5]+(i_ymove+1)+1;
														psum_base_addr[2] <= psum_base_addr[5]+(i_ymove+1)*2+1;
														psum_base_addr[3] <= psum_base_addr[5]+(i_ymove+1)*3+1;
														psum_base_addr[4] <= psum_base_addr[5]+(i_ymove+1)*4+1;
														psum_base_addr[5] <= psum_base_addr[5]+(i_ymove+1)*5+1;
													end
													else begin
														psum_base_addr[0] <= psum_base_addr[0]+1;
													end
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
							else begin
								
							end

							if (zmove_count==0 && i_bias_psum==0) begin
								o_bias_sel <= 0;
							end
							else begin
								o_bias_sel <= 1;
							end

							if (zmove_count<i_zmove && wgt_shift_finish==0) begin

								if (xmove_count==0 && ymove_count==0 && wgt_shift_count==0 && sld_count==0 && o_update_wgt==0) begin
									o_update_wgt <= 1;
									o_wmem_rd_addr <= (compute_start==0)? 0: (o_wmem_rd_addr+1);
									o_pmem_wr_en0 <= 0;
									o_pmem_wr_en1 <= 0;
									wgt_shift_finish <= 0;
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
												// if(o_shift) o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
												// else if (compute_start) o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
												o_pmem_wr_en0 <= 0;
												o_pmem_wr_en1 <= 0;
												if (sld_count==3'd5) begin
													o_pmem_rd_addr0 <= wgt_shift_finish? (psum_base_addr[0]+1) : psum_base_addr[0];
													o_pmem_rd_addr1 <= wgt_shift_finish? (psum_base_addr[0]+1) : psum_base_addr[0];
													o_pmem_rd_en0 <= ~xmove_count[0];
													o_pmem_rd_en1 <= xmove_count[0];
													// o_img_bf_rd_en <= 0;
												end
												else begin
													o_pmem_rd_en0 <= 0;
													o_pmem_rd_en1 <= 0;
													// o_img_bf_rd_en <= 1;
													o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
												end
											end
											else begin
												// sliding rf is full, do the computation
												compute_start <= 1;
												o_shift <= 0;
												if (i_stride==3'd1) begin
													if (wgt_shift_count == 0) begin
														o_wgt_shift <= 0;

														o_pmem_wr_en0 <= ~xmove_count[0];
														o_pmem_wr_en1 <= xmove_count[0];
														o_pmem_wr_addr0 <= psum_base_addr[0];
														o_pmem_wr_addr1 <= psum_base_addr[0];

														o_pmem_rd_en0 <= 1;
														o_pmem_rd_en1 <= 1;
														o_pmem_rd_addr0 <= psum_base_addr[1];
														o_pmem_rd_addr1 <= (xmove_count[0])? psum_base_addr[1]:(psum_base_addr[1]-(i_ymove+1)*3);
														wgt_shift_count <= wgt_shift_count+1;
													end
													else if (wgt_shift_count == 1) begin
														o_wgt_shift <= 1;

														if(xmove_count>0) begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_en1 <= 1;
															o_pmem_wr_addr0 <= psum_base_addr[1];
															o_pmem_wr_addr1 <= (xmove_count[0])? psum_base_addr[1]:(psum_base_addr[1]-(i_ymove+1)*3);
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
														o_pmem_rd_addr1 <= (xmove_count[0])? psum_base_addr[2]:(psum_base_addr[2]-(i_ymove+1)*3);
													
														wgt_shift_count <= wgt_shift_count+1;
													end
													else if (wgt_shift_count == 2) begin
														o_wgt_shift <= 2;
														wgt_shift_count <= 0;
														if(xmove_count>0) begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_en1 <= 1;
															o_pmem_wr_addr0 <= psum_base_addr[2];
															o_pmem_wr_addr1 <= (xmove_count[0])? psum_base_addr[2]:(psum_base_addr[2]-(i_ymove+1)*3);
														end
														else begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_en1 <= 0;
															o_pmem_wr_addr0 <= psum_base_addr[2];
															o_pmem_wr_addr1 <= psum_base_addr[2];
														end
														
														if (ymove_count<i_ymove) begin 
															sld_count <= 4;
														end 
														else begin
															sld_count <= 0;
														end

														wgt_shift_finish <= 1;
														o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
													end
													
												end
												else begin // strides >1
													wgt_shift_finish <= 1;

													o_pmem_wr_en0 <= ~xmove_count[0];
													o_pmem_wr_en1 <= xmove_count[0];
													o_pmem_wr_addr0 <= psum_base_addr[0];
													o_pmem_wr_addr1 <= psum_base_addr[0];

													o_wgt_shift <= 0;

													if (i_stride==3'd2) begin
														sld_count <= (ymove_count<i_ymove)? 2:0;
													end
													else begin
														sld_count <= 0;
													end
													o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
												end
											end
										end
										2'b01: begin
											// 4x4 mode
											if (sld_count<3'd4) begin
												wgt_shift_finish <= 0;
												o_shift <= 1;
												sld_count <= sld_count+1'b1;
												// if(o_shift) o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
            //                                     else if (compute_start) o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
												o_pmem_wr_en0 <= 0;
												o_pmem_wr_en1 <= 0;
												if (sld_count==3'd3) begin
													o_pmem_rd_addr0 <= wgt_shift_finish? (psum_base_addr[0]+1) : psum_base_addr[0];
													o_pmem_rd_addr1 <= wgt_shift_finish? (psum_base_addr[0]+1) : psum_base_addr[0];
													o_pmem_rd_en0 <= ~xmove_count[0];
													o_pmem_rd_en1 <= xmove_count[0];
												end
												else begin
													o_pmem_rd_en0 <= 0;
													o_pmem_rd_en1 <= 0;
													o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
												end
											end
											else begin 
												compute_start <= 1;
												o_shift <= 0;
												if (i_stride==3'd1) begin
													if (wgt_shift_count == 0) begin
														o_wgt_shift <= 0;

														o_pmem_wr_en0 <= ~xmove_count[0];
														o_pmem_wr_en1 <= xmove_count[0];
														o_pmem_wr_addr0 <= psum_base_addr[0];
														o_pmem_wr_addr1 <= psum_base_addr[0];

														o_pmem_rd_en0 <= 1;
														o_pmem_rd_en1 <= 1;
														o_pmem_rd_addr0 <= psum_base_addr[1];
														o_pmem_rd_addr1 <= (xmove_count[0])? psum_base_addr[1]:(psum_base_addr[1]-(i_ymove+1)*4);
														wgt_shift_count <= wgt_shift_count+1;
													end
													else if (wgt_shift_count == 1) begin
														o_wgt_shift <= 1;
														if(xmove_count>0) begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_en1 <= 1;
															o_pmem_wr_addr0 <= psum_base_addr[1];
															o_pmem_wr_addr1 <= (xmove_count[0])? psum_base_addr[1]:(psum_base_addr[1]-(i_ymove+1)*4);
														end
														else begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_addr0 <= psum_base_addr[1];
														end

														o_pmem_rd_en0 <= 1;
														o_pmem_rd_en1 <= 1;
														o_pmem_rd_addr0 <= psum_base_addr[2];
														o_pmem_rd_addr1 <= (xmove_count[0])? psum_base_addr[2]:(psum_base_addr[2]-(i_ymove+1)*4);
														wgt_shift_count <= wgt_shift_count+1;
													end
													else if (wgt_shift_count == 2) begin
														o_wgt_shift <= 2;
														if(xmove_count>0) begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_en1 <= 1;
															o_pmem_wr_addr0 <= psum_base_addr[2];
															o_pmem_wr_addr1 <= (xmove_count[0])? psum_base_addr[2]:(psum_base_addr[2]-(i_ymove+1)*4);
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
														o_pmem_rd_addr1 <= (xmove_count[0])? psum_base_addr[3]:(psum_base_addr[3]-(i_ymove+1)*4);
														wgt_shift_count <= 3;
													end
													else if (wgt_shift_count == 3) begin
														wgt_shift_count <= 0;

														o_wgt_shift <= 3;
														if(xmove_count>0) begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_addr0 <= psum_base_addr[3];
															o_pmem_wr_en1 <= 1;
															o_pmem_wr_addr1 <= (xmove_count[0])? psum_base_addr[3]:(psum_base_addr[3]-(i_ymove+1)*4);
														end
														else begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_en1 <= 0;
															o_pmem_wr_addr0 <= psum_base_addr[3];
															o_pmem_wr_addr1 <= psum_base_addr[3];
														end

														// o_pmem_rd_en0 <= ~xmove_count[0];
														// o_pmem_rd_en1 <= xmove_count[0];
														// o_pmem_rd_addr0 <= psum_base_addr[0];
														
														wgt_shift_finish <= 1;
														sld_count <= (ymove_count<i_ymove)? (sld_count-1):0;
														o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
													end
												end
												else if (i_stride==3'd2) begin
													if (wgt_shift_count == 0) begin
														o_wgt_shift <= 0;

														o_pmem_wr_en0 <= ~xmove_count[0];
														o_pmem_wr_en1 <= xmove_count[0];
														o_pmem_wr_addr0 <= psum_base_addr[0];
														o_pmem_wr_addr1 <= psum_base_addr[0];

														o_pmem_rd_en0 <= 1;
														o_pmem_rd_en1 <= 1;
														o_pmem_rd_addr0 <= psum_base_addr[1];
														o_pmem_rd_addr1 <= (xmove_count[0])? psum_base_addr[1]:(psum_base_addr[1]-(i_ymove+1)*2);
														wgt_shift_count <= wgt_shift_count+1;
													end
													else if (wgt_shift_count == 1) begin
														wgt_shift_finish <= 1;
														o_wgt_shift <= 2;
														if(xmove_count>0) begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_en1 <= 1;
															o_pmem_wr_addr0 <= psum_base_addr[1];
															o_pmem_wr_addr1 <= (xmove_count[0])? psum_base_addr[1]:(psum_base_addr[1]-(i_ymove+1)*2);
														end
														else begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_addr0 <= psum_base_addr[1];
														end

														// o_pmem_rd_en0 <= ~xmove_count[0];
														// o_pmem_rd_en1 <= xmove_count[0];
														// o_pmem_rd_addr0 <= psum_base_addr[0];
														// o_pmem_rd_addr1 <= psum_base_addr[0];
														wgt_shift_count <= 0;
														sld_count <= (ymove_count<i_ymove)? (sld_count-2):0;
														o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
													end
												end
												else begin
													wgt_shift_finish <= 1;

													o_pmem_wr_en0 <= ~xmove_count[0];
													o_pmem_wr_en1 <= xmove_count[0];
													o_pmem_wr_addr0 <= psum_base_addr[0];
													o_pmem_wr_addr1 <= psum_base_addr[0];

													// o_pmem_rd_en0 <= 1;
													// o_pmem_rd_en1 <= 1;
													// o_pmem_rd_addr0 <= psum_base_addr[0];
													// o_pmem_rd_addr1 <= psum_base_addr[0];
													o_wgt_shift <= 0;

													sld_count <= (ymove_count<i_ymove)? (sld_count-i_stride):0;
													o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
												end
											end

										end

										2'b10: begin
											// 5x5 mode
											if (sld_count<3'd5) begin
												wgt_shift_finish <= 0;
												o_shift <= 1;
												sld_count <= sld_count+1'b1;
												// o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
												// if(o_shift) o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
												// else if (compute_start) o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
												o_pmem_wr_en0 <= 0;
												o_pmem_wr_en1 <= 0;
												if (sld_count==3'd4) begin
													o_pmem_rd_addr0 <= wgt_shift_finish? (psum_base_addr[0]+1) : psum_base_addr[0];
													o_pmem_rd_addr1 <= wgt_shift_finish? (psum_base_addr[0]+1) : psum_base_addr[0];
													o_pmem_rd_en0 <= ~xmove_count[0];
													o_pmem_rd_en1 <= xmove_count[0];
												end
												else begin
													o_pmem_rd_en0 <= 0;
													o_pmem_rd_en1 <= 0;
													o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
												end
											end
											else begin
												compute_start <= 1;
												o_shift <= 0;
												if (i_stride==3'd1) begin
													if (wgt_shift_count == 0) begin
														o_wgt_shift <= 0;
									
														o_pmem_wr_en0 <= ~xmove_count[0];
														o_pmem_wr_en1 <= xmove_count[0];
														o_pmem_wr_addr0 <= psum_base_addr[0];
														o_pmem_wr_addr1 <= psum_base_addr[0];

														o_pmem_rd_en0 <= 1;
														o_pmem_rd_en1 <= 1;
														o_pmem_rd_addr0 <= psum_base_addr[1];
														o_pmem_rd_addr1 <= (xmove_count[0])? psum_base_addr[1]:(psum_base_addr[1]-(i_ymove+1)*5);
														wgt_shift_count <= wgt_shift_count+1;
													end
													else if (wgt_shift_count == 1) begin
														o_wgt_shift <= 1;
														if(xmove_count>0) begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_en1 <= 1;
															o_pmem_wr_addr0 <= psum_base_addr[1];
															o_pmem_wr_addr1 <= (xmove_count[0])? psum_base_addr[1]:(psum_base_addr[1]-(i_ymove+1)*5);
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
														o_pmem_rd_addr1 <= (xmove_count[0])? psum_base_addr[2]:(psum_base_addr[2]-(i_ymove+1)*5);
														wgt_shift_count <= wgt_shift_count+1;
													end
													else if (wgt_shift_count == 2) begin
														o_wgt_shift <= 2;
														if(xmove_count>0) begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_en1 <= 1;
															o_pmem_wr_addr0 <= psum_base_addr[2];
															o_pmem_wr_addr1 <= (xmove_count[0])? psum_base_addr[2]:(psum_base_addr[2]-(i_ymove+1)*5);
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
														o_pmem_rd_addr1 <= (xmove_count[0])? psum_base_addr[3]:(psum_base_addr[3]-(i_ymove+1)*5);
														wgt_shift_count <= wgt_shift_count+1;
													end
													else if (wgt_shift_count == 3) begin
														o_wgt_shift <= 3;
														if(xmove_count>0) begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_en1 <= 1;
															o_pmem_wr_addr0 <= psum_base_addr[3];
															o_pmem_wr_addr1 <= (xmove_count[0])? psum_base_addr[3]:(psum_base_addr[3]-(i_ymove+1)*5);
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
														o_pmem_rd_addr1 <= (xmove_count[0])? psum_base_addr[4]:(psum_base_addr[4]-(i_ymove+1)*5);
														wgt_shift_count <= wgt_shift_count+1;
													end
													else if (wgt_shift_count == 4) begin
														wgt_shift_finish <= 1;
														sld_count <= (ymove_count<i_ymove)? (sld_count-1):0;
														o_img_bf_rd_addr <= o_img_bf_rd_addr+1;

														o_wgt_shift <= 4;
														if(xmove_count>0) begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_addr0 <= psum_base_addr[4];
															o_pmem_wr_en1 <= 1;
															o_pmem_wr_addr1 <= (xmove_count[0])? psum_base_addr[4]:(psum_base_addr[4]-(i_ymove+1)*5);
														end
														else begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_addr0 <= psum_base_addr[4];
															o_pmem_wr_en1 <= 0;
															o_pmem_wr_addr1 <= psum_base_addr[4];
														end

														// o_pmem_rd_en0 <= ~xmove_count[0];
														// o_pmem_rd_en1 <= xmove_count[0];
														// o_pmem_rd_addr0 <= psum_base_addr[0];
														wgt_shift_count <= 0;
													end
												end
												else begin // strides > 1
													wgt_shift_finish <= 1;
													o_img_bf_rd_addr <= o_img_bf_rd_addr+1;

													o_pmem_wr_en0 <= ~xmove_count[0];
													o_pmem_wr_en1 <= xmove_count[0];
													o_pmem_wr_addr0 <= psum_base_addr[0];
													o_pmem_wr_addr1 <= psum_base_addr[0];

													// o_pmem_rd_en0 <= 1;
													// o_pmem_rd_en1 <= 1;
													// o_pmem_rd_addr0 <= psum_base_addr[0];
													// o_pmem_rd_addr1 <= psum_base_addr[0];
													o_wgt_shift <= 0;

													sld_count <= (ymove_count<i_ymove)? (sld_count-i_stride):0;
												end
											end

										end
										2'b11: begin
											// 6x6 mode
											if (sld_count<3'd6) begin
												wgt_shift_finish <= 0;
												o_shift <= 1;
												sld_count <= sld_count+1'b1;
												//o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
												// if(o_shift) o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
            //                                     else if (compute_start) o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
												o_pmem_wr_en0 <= 0;
												o_pmem_wr_en1 <= 0;
												if (sld_count==3'd5) begin
													o_pmem_rd_addr0 <= wgt_shift_finish? (psum_base_addr[0]+1) : psum_base_addr[0];
													o_pmem_rd_addr1 <= wgt_shift_finish? (psum_base_addr[0]+1) : psum_base_addr[0];
													o_pmem_rd_en0 <= ~xmove_count[0];
													o_pmem_rd_en1 <= xmove_count[0];
												end
												else begin
													o_pmem_rd_en0 <= 0;
													o_pmem_rd_en1 <= 0;
													o_img_bf_rd_addr <= o_img_bf_rd_addr+1;
												end
											end
											else begin
												compute_start <= 1;
												o_shift <= 0;
												if (i_stride==3'd1) begin
													if (wgt_shift_count == 0) begin
														o_wgt_shift <= 0;

														o_pmem_wr_en0 <= ~xmove_count[0];
														o_pmem_wr_en1 <= xmove_count[0];
														o_pmem_wr_addr0 <= psum_base_addr[0];
														o_pmem_wr_addr1 <= psum_base_addr[0];

														o_pmem_rd_en0 <= 1;
														o_pmem_rd_en1 <= 1;
														o_pmem_rd_addr0 <= psum_base_addr[1];
														o_pmem_rd_addr1 <= (xmove_count[0])? psum_base_addr[1]:(psum_base_addr[1]-(i_ymove+1)*6);
														wgt_shift_count <= wgt_shift_count+1;
													end
													else if (wgt_shift_count == 1) begin
														o_wgt_shift <= 1;
														if(xmove_count>0) begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_en1 <= 1;
															o_pmem_wr_addr0 <= psum_base_addr[1];
															o_pmem_wr_addr1 <= (xmove_count[0])? psum_base_addr[1]:(psum_base_addr[1]-(i_ymove+1)*6);
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
														o_pmem_rd_addr1 <= (xmove_count[0])? psum_base_addr[2]:(psum_base_addr[2]-(i_ymove+1)*6);
														wgt_shift_count <= wgt_shift_count+1;
													end
													else if (wgt_shift_count == 2) begin
														o_wgt_shift <= 2;
														if(xmove_count>0) begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_en1 <= 1;
															o_pmem_wr_addr0 <= psum_base_addr[2];
															o_pmem_wr_addr1 <= (xmove_count[0])? psum_base_addr[2]:(psum_base_addr[2]-(i_ymove+1)*6);
														end
														else begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_en1 <= 0;
															o_pmem_wr_addr0 <= psum_base_addr[2];
														end

														o_pmem_rd_en0 <= 1;
														o_pmem_rd_en1 <= 1;
														o_pmem_rd_addr0 <= psum_base_addr[3];
														o_pmem_rd_addr1 <= (xmove_count[0])? psum_base_addr[3]:(psum_base_addr[3]-(i_ymove+1)*6);
														wgt_shift_count <= wgt_shift_count+1;
													end
													else if (wgt_shift_count == 3) begin
														o_wgt_shift <= 3;
														if(xmove_count>0) begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_en1 <= 1;
															o_pmem_wr_addr0 <= psum_base_addr[3];
															o_pmem_wr_addr1 <=  (xmove_count[0])? psum_base_addr[3]:(psum_base_addr[3]-(i_ymove+1)*6);
														end
														else begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_en1 <= 0;
															o_pmem_wr_addr0 <= psum_base_addr[3];
														end

														o_pmem_rd_en0 <= 1;
														o_pmem_rd_en1 <= 1;
														o_pmem_rd_addr0 <= psum_base_addr[4];
														o_pmem_rd_addr1 <= (xmove_count[0])? psum_base_addr[4]:(psum_base_addr[4]-(i_ymove+1)*6);
														wgt_shift_count <= wgt_shift_count+1;
													end
													else if (wgt_shift_count == 4) begin
														o_wgt_shift <= 4;
														if(xmove_count>0) begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_en1 <= 1;
															o_pmem_wr_addr0 <= psum_base_addr[4];
															o_pmem_wr_addr1 <= (xmove_count[0])? psum_base_addr[4]:(psum_base_addr[4]-(i_ymove+1)*6);
														end
														else begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_en1 <= 0;
															o_pmem_wr_addr0 <= psum_base_addr[4];
														end

														o_pmem_rd_en0 <= 1;
														o_pmem_rd_en1 <= 1;
														o_pmem_rd_addr0 <= psum_base_addr[5];
														o_pmem_rd_addr1 <= (xmove_count[0])? psum_base_addr[5]:(psum_base_addr[5]-(i_ymove+1)*6);
														wgt_shift_count <= 5;
													end
													else if (wgt_shift_count == 5) begin
														wgt_shift_finish <= 1;
														sld_count <= (ymove_count<i_ymove)? (sld_count-1):0;
														o_img_bf_rd_addr <= o_img_bf_rd_addr+1;

														o_wgt_shift <= 5;
														if(xmove_count>0) begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_addr0 <= psum_base_addr[5];
															o_pmem_wr_en1 <= 1;
															o_pmem_wr_addr1 <= (xmove_count[0])? psum_base_addr[5]:(psum_base_addr[5]-(i_ymove+1)*6);
														end
														else begin
															o_pmem_wr_en0 <= 1;
															o_pmem_wr_en1 <= 0;
															o_pmem_wr_addr0 <= psum_base_addr[5];
														end

														// o_pmem_rd_en0 <= ~xmove_count[0];
														// o_pmem_rd_en1 <= xmove_count[0];
														// o_pmem_rd_addr0 <= psum_base_addr[0];
														// o_pmem_rd_addr1 <= psum_base_addr[0];
														wgt_shift_count <= 0;
													end
												end
												else begin // strides > 1
													wgt_shift_finish <= 1;
													o_img_bf_rd_addr <= o_img_bf_rd_addr+1;

													o_pmem_wr_en0 <= ~xmove_count[0];
													o_pmem_wr_en1 <= xmove_count[0];
													o_pmem_wr_addr0 <= psum_base_addr[0];
													o_pmem_wr_addr1 <= psum_base_addr[0];

													// o_pmem_rd_en0 <= 1;
													// o_pmem_rd_en1 <= 1;
													// o_pmem_rd_addr0 <= psum_base_addr[0];
													// o_pmem_rd_addr1 <= psum_base_addr[0];
													o_wgt_shift <= 0;

													sld_count <= (ymove_count<i_ymove)? (sld_count-i_stride):0;
												end
											end
										end
									endcase
								end
							end
							else begin
								o_pmem_wr_en0 <= 0;
								o_pmem_wr_en1 <= 0;
							end
						end
						else begin
							o_pmem_wr_en0 <= 0;
							o_pmem_wr_en1 <= 0;
							o_update_wgt <= 0;
						end
					end	
				end

				BURST: begin
					o_shift <= 0;

					if(status_reset<4'b1111) begin
						status_reset <= status_reset+1;
					end
					else if (pre_finish) begin
						status <= RESET;
						o_finish <= 1;
					end
					else if (xmove_count<=i_xmove) begin
						if (i_pool==0) begin
							o_pmem_rd_en0 <= ~xmove_count[0];
							o_pmem_rd_en1 <= xmove_count[0];
							
							if ((ymove_count<psum_base_addr[0]) && (xmove_count<i_xmove)) begin
								ymove_count <= ymove_count+1;
							end
							else if ((ymove_count<i_ymove) && (xmove_count==i_xmove)) begin
                                                                ymove_count <= ymove_count+1;
                                                        end
							else begin
								ymove_count <= 0;
								xmove_count <= xmove_count+1;
							end

							if (xmove_count==0 && ymove_count==0) begin
								o_pmem_rd_addr0 <= 0;
								o_pmem_rd_addr1 <= 0;
							end
							else if (ymove_count==0 && xmove_count[0]==1) begin
								o_pmem_rd_addr0 <= o_pmem_rd_addr0 - psum_base_addr[0];
								o_pmem_rd_addr1 <= o_pmem_rd_addr1 - psum_base_addr[0];
							end
							else begin
								o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
								o_pmem_rd_addr1 <= o_pmem_rd_addr1+1;
							end
						end

						else begin // 2x2 max pool
							pool_count <= pool_count+1;
							case (i_mode)
								2'b00: begin // 3x3 mode
//									if (ymove_count==psum_base_addr[3]) begin
//										xmove_count <= xmove_count+2;
//										ymove_count <= 0;
//									end
//									else begin
//										ymove_count <= ymove_count+1;
//									end
									if(i_xmove==1) begin
										if (ymove_count==psum_base_addr[2]) begin
											xmove_count <= xmove_count+2;
											ymove_count <= 0;
										end
										else begin
											ymove_count <= ymove_count+1;
										end	
									end
									else begin
										if ((ymove_count<psum_base_addr[3]) && (xmove_count<i_xmove)) begin
											ymove_count <= ymove_count+1;
										end
										else if ((ymove_count<i_ymove) && (xmove_count==i_xmove)) begin
						                                        ymove_count <= ymove_count+1;
						                                end
										else begin
											ymove_count <= 0;
											xmove_count <= xmove_count+2;
										end
									end
									case (pool_count)
										2'b00: begin
											
											if (ymove_count<psum_base_addr[2]) begin
												o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
												o_pmem_rd_en0 <= 1;
												o_pmem_rd_en1 <= 0;
											end
											else begin
												o_pmem_rd_addr1 <= o_pmem_rd_addr1+1;
												o_pmem_rd_en0 <= 0;
												o_pmem_rd_en1 <= 1;
											end
										end
										2'b01: begin
											
											if(ymove_count>psum_base_addr[1]) begin
												if (ymove_count<psum_base_addr[2]) begin
													o_pmem_rd_addr1 <= (o_pmem_rd_addr1==0)?0:(o_pmem_rd_addr1+1);
													o_pmem_rd_en0 <= 0;
													o_pmem_rd_en1 <= 1;	
												end
												else begin
													o_pmem_rd_addr1 <= o_pmem_rd_addr1+i_ymove;
													o_pmem_rd_en0 <= 0;
													o_pmem_rd_en1 <= 1;		
												end
											end
											else begin
												o_pmem_rd_addr0 <= o_pmem_rd_addr0+i_ymove;
												o_pmem_rd_en0 <= 1;
												o_pmem_rd_en1 <= 0;

												
											end
										end
										2'b10: begin
											
											if (ymove_count<psum_base_addr[1]) begin
												o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
												o_pmem_rd_en0 <= 1;
												o_pmem_rd_en1 <= 0;

										
											end
											else begin
												o_pmem_rd_addr1 <= o_pmem_rd_addr1+1;
												o_pmem_rd_en0 <= 0;
												o_pmem_rd_en1 <= 1;

												
											end	
										end
										2'b11: begin
											if (ymove_count==0 && xmove_count==0) begin
												o_pmem_rd_addr0 <= 0;
												o_pmem_rd_en0 <= 1;
												o_pmem_rd_en1 <= 0;
											end
											else begin
												
												//o_dma_wr_addr <= o_dma_wr_addr+1;
												if(ymove_count>psum_base_addr[1]) begin

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
															o_pmem_rd_en0 <= 1;
															o_pmem_rd_en1 <= 0;
														end
														else begin
															o_pmem_rd_addr1 <= o_pmem_rd_addr1-i_ymove;
															o_pmem_rd_en0 <= 0;
															o_pmem_rd_en1 <= 1;
														end
													end
												end
												else begin
													o_pmem_rd_en0 <= 1;
													o_pmem_rd_en1 <= 0;

													if (ymove_count==psum_base_addr[1]) begin
														o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
													end
													else begin
														o_pmem_rd_addr0 <= o_pmem_rd_addr0-i_ymove;
													end
												end
											end
										end
									endcase
								end
								2'b01: begin // 4x4 mode
//									if (ymove_count==psum_base_addr[2]) begin
//										xmove_count <= xmove_count+1;
//										ymove_count <= 0;
//									end
//									else begin
//										ymove_count <= ymove_count+1;
//									end

									if ((ymove_count<psum_base_addr[2]) && (xmove_count<i_xmove)) begin
										ymove_count <= ymove_count+1;
									end
									else if ((ymove_count<i_ymove) && (xmove_count==i_xmove)) begin
					                                        ymove_count <= ymove_count+1;
					                                end
									else begin
										ymove_count <= 0;
										xmove_count <= xmove_count+1;
									end

									o_pmem_rd_en0 <= ~xmove_count[0];
									o_pmem_rd_en1 <= xmove_count[0];
									case (pool_count)
										2'b00: begin
											
											if (xmove_count[0]==0) begin
												o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
												
											end
											else begin
												o_pmem_rd_addr1 <= o_pmem_rd_addr1+1;
												
											end
										end
										2'b01: begin
											

											if (xmove_count[0]==0) begin
												o_pmem_rd_addr0 <= o_pmem_rd_addr0+i_ymove;
												
											end
											else begin
												o_pmem_rd_addr1 <= o_pmem_rd_addr1+i_ymove;
												
											end
										end
										2'b10: begin
											
											if (xmove_count[0]==0) begin
												o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
												
											end
											else begin
												o_pmem_rd_addr1 <= o_pmem_rd_addr1+1;
												
											end
										end
										2'b11: begin
											
											//o_dma_wr_addr <= o_dma_wr_addr+1;
											if (ymove_count==0 && xmove_count==0) begin
												o_pmem_rd_addr0 <= 0;
											end
											else begin
												if(ymove_count==psum_base_addr[1]) begin
													if (xmove_count[0]==0) begin
														o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
														
													end
													else begin
														o_pmem_rd_addr1 <= o_pmem_rd_addr1+1;
														
													end
												end
												else if(ymove_count==psum_base_addr[2])  begin
													if (xmove_count[0]==0) begin
														o_pmem_rd_addr1 <= (o_pmem_rd_addr1==0)? 0:o_pmem_rd_addr1+1;
														
													end
													else begin
														o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
														
													end
													
												end
												else begin
													if (xmove_count[0]==0) begin
														o_pmem_rd_addr0 <= o_pmem_rd_addr0-i_ymove+1;
														
													end
													else begin
														o_pmem_rd_addr1 <= o_pmem_rd_addr1-i_ymove+1;
														
													end
												end
											end
										end
									endcase
								end
								2'b10: begin // 5*5, 2*2 max-pool
//									if (ymove_count==psum_base_addr[5]) begin
//										xmove_count <= xmove_count+2;
//										ymove_count <= 0;
//									end
//									else begin
//										ymove_count <= ymove_count+1;
//									end
									if (i_xmove==1'b1) begin
										if (ymove_count==psum_base_addr[3]) begin
											xmove_count <= xmove_count+2;
											ymove_count <= 0;
										end
										else begin
											ymove_count <= ymove_count+1;
										end
									end
									else begin
										if ((ymove_count<psum_base_addr[5]) && (xmove_count<i_xmove)) begin
											ymove_count <= ymove_count+1;
										end
										else if ((ymove_count<i_ymove) && (xmove_count==i_xmove)) begin
							                                ymove_count <= ymove_count+1;
							                        end
										else begin
											ymove_count <= 0;
											xmove_count <= xmove_count+2;
										end
									end
									case (pool_count)
										2'b00: begin
											
											if (ymove_count<psum_base_addr[3]) begin
												o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
												o_pmem_rd_en0 <= 1;
												o_pmem_rd_en1 <= 0;
												
											end
											else begin
												o_pmem_rd_addr1 <= o_pmem_rd_addr1+1;
												o_pmem_rd_en0 <= 0;
												o_pmem_rd_en1 <= 1;
												
											end
										end
										2'b01: begin
											
											if(ymove_count>psum_base_addr[2]) begin
												if (ymove_count<psum_base_addr[3]) begin
													o_pmem_rd_addr1 <= (o_pmem_rd_addr1==0)?0:(o_pmem_rd_addr1+1);
													o_pmem_rd_en0 <= 0;
													o_pmem_rd_en1 <= 1;

													
												end
												else begin
													o_pmem_rd_addr1 <= o_pmem_rd_addr1+i_ymove;
													o_pmem_rd_en0 <= 0;
													o_pmem_rd_en1 <= 1;

													
												end
											end
											else begin
												o_pmem_rd_addr0 <= o_pmem_rd_addr0+i_ymove;
												o_pmem_rd_en0 <= 1;
												o_pmem_rd_en1 <= 0;

												
											end
										end
										2'b10: begin
											
											if (ymove_count<psum_base_addr[2]) begin
												o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
												o_pmem_rd_en0 <= 1;
												o_pmem_rd_en1 <= 0;

										
											end
											else begin
												o_pmem_rd_addr1 <= o_pmem_rd_addr1+1;
												o_pmem_rd_en0 <= 0;
												o_pmem_rd_en1 <= 1;

												
											end	
										end
										2'b11: begin
											
											//o_dma_wr_addr <= o_dma_wr_addr+1;
											if(ymove_count>psum_base_addr[2]) begin
												if (ymove_count<=psum_base_addr[3]) begin
													if (ymove_count==psum_base_addr[3]) begin
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
													if (ymove_count==psum_base_addr[5]) begin
														o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
														o_pmem_rd_en0 <= 1;
														o_pmem_rd_en1 <= 0;
													end
													else if (ymove_count==psum_base_addr[4]) begin
														o_pmem_rd_addr1 <= o_pmem_rd_addr1+1;
														o_pmem_rd_en0 <= 0;
														o_pmem_rd_en1 <= 1;
													end
													else begin
														o_pmem_rd_addr1 <= o_pmem_rd_addr1-i_ymove;
														o_pmem_rd_en0 <= 0;
														o_pmem_rd_en1 <= 1;
													end
												end
											end
											else if (ymove_count==0 && xmove_count==0) begin
												o_pmem_rd_addr0 <= 0;
												o_pmem_rd_en0 <= 1;
												o_pmem_rd_en1 <= 0;
											end
											else begin
												if (ymove_count==psum_base_addr[1] || ymove_count==psum_base_addr[2]) begin
													o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
													o_pmem_rd_en0 <= 1;
													o_pmem_rd_en1 <= 0;
												end
												else begin
													o_pmem_rd_addr0 <= o_pmem_rd_addr0-i_ymove;
													o_pmem_rd_en0 <= 1;
													o_pmem_rd_en1 <= 0;
												end
											end
										end
									endcase
									
								end
								2'b11: begin
/*									if (ymove_count==psum_base_addr[3]) begin
										xmove_count <= xmove_count+1;
										ymove_count <= 0;
									end
									else begin
										ymove_count <= ymove_count+1;
									end*/
									if ((ymove_count<psum_base_addr[3]) && (xmove_count<i_xmove)) begin
										ymove_count <= ymove_count+1;
									end
									else if ((ymove_count<i_ymove) && (xmove_count==i_xmove)) begin
						                                ymove_count <= ymove_count+1;
						                        end
									else begin
										ymove_count <= 0;
										xmove_count <= xmove_count+2;
									end

									o_pmem_rd_en0 <= ~xmove_count[0];
									o_pmem_rd_en1 <= xmove_count[0];
									case (pool_count)
										2'b00: begin
											if (xmove_count[0]==0) begin
												o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
												
											end
											else begin
												o_pmem_rd_addr1 <= o_pmem_rd_addr1+1;
												
											end
										end
										2'b01: begin
											if (xmove_count[0]==0) begin
												o_pmem_rd_addr0 <= o_pmem_rd_addr0+i_ymove;
												
											end
											else begin
												o_pmem_rd_addr1 <= o_pmem_rd_addr1+i_ymove;
												
											end
										end
										2'b10: begin
											if (xmove_count[0]==0) begin
												o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
												
											end
											else begin
												o_pmem_rd_addr1 <= o_pmem_rd_addr1+1;
												
											end
										end
										2'b11: begin
											
											//o_dma_wr_addr <= o_dma_wr_addr+1;
											if (ymove_count==0 && xmove_count==0) begin
												o_pmem_rd_addr0 <= 0;
											end
											else begin
												if(ymove_count==psum_base_addr[1] || ymove_count==psum_base_addr[2]) begin
													if (xmove_count[0]==0) begin
														o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
														
													end
													else begin
														o_pmem_rd_addr1 <= o_pmem_rd_addr1+1;
														
													end
												end
												else if(ymove_count==psum_base_addr[3])  begin
													if (xmove_count[0]==0) begin
														
														o_pmem_rd_addr1 <= (o_pmem_rd_addr1==0)? 0:o_pmem_rd_addr1+1;
														
													end
													else begin
														
														o_pmem_rd_addr0 <= o_pmem_rd_addr0+1;
														
													end
													
												end
												else begin
													if (xmove_count[0]==0) begin
														o_pmem_rd_addr0 <= o_pmem_rd_addr0-i_ymove+1;
													end
													else begin
														o_pmem_rd_addr1 <= o_pmem_rd_addr1-i_ymove+1;
													end
												end
											end
										end
									endcase
								end
							endcase
						end
					end
					else begin
						if (PE_sel==4'd15) begin
							o_pmem_rd_en0 <= 0;
							o_pmem_rd_en1 <= 0;
							if (~pmem_rd_en0_d1 && ~pmem_rd_en1_d1) begin
								pre_finish <= 1;
							end
						end
						else begin
							PE_sel <= PE_sel+1;
							zmove_count <= 0;
							xmove_count <= 0;
							ymove_count <= 0;
							o_pmem_rd_en0 <= 0;
							o_pmem_rd_en1 <= 0;
							o_pmem_rd_addr0 <= 0;
							o_pmem_rd_addr1 <= 0;
							pool_count <= 2'd3;
						end
					end
				o_PE_sel <= PE_sel;
				end
			endcase
		end
		else begin
		//	o_pmem_rd_en0<=0;
		//	o_pmem_rd_en1<=0;
		end
	end

	reg dma_hand_shaked_d1, dma_hand_shaked_d2, dma_hand_shaked_d3;
	reg [1:0] dma_wr_delay_num, delay_count;
	reg double_delay, delete_delay;

	always @(posedge i_clk) begin
		dma_hand_shaked_d1 <= dma_hand_shaked;
		dma_hand_shaked_d2 <= dma_hand_shaked_d1;
		dma_hand_shaked_d3 <= dma_hand_shaked_d2;
		if (dma_hand_shaked_d3) begin
			dma_wr_data_reg[0] <= dma_wr_data;
			dma_wr_data_reg[1] <= dma_wr_data_reg[0];
			dma_wr_data_reg[2] <= dma_wr_data_reg[1];
			dma_wr_data2_reg[0] <= dma_wr_data2;
			dma_wr_data2_reg[1] <= dma_wr_data2_reg[0];
			dma_wr_data2_reg[2] <= dma_wr_data2_reg[1];
		end
	end

	always @(*) begin
		if(dma_wr_delay_num==2'b11) begin
			dma_wr_data_wire = dma_wr_data;
			dma_wr_data2_wire = dma_wr_data2;
		end
		else begin
			dma_wr_data_wire = dma_wr_data_reg[dma_wr_delay_num];
			dma_wr_data2_wire = dma_wr_data2_reg[dma_wr_delay_num];
		end
	end


	always @(posedge i_clk) begin
		if (i_rst) begin
			wr_flag <= 0;
			o_dma_wr_addr <= 0;
			o_dma_wr_data <= 0;
			o_dma_wr_en <= 0;
			dma_hand_shaked <= 1;
			dma_wr_delay_num <= 2'b11;
			double_delay <= 0;
			delay_count <= 0;
			delete_delay <= 0;
		end
		else begin
			if (status==BURST) begin
				if(dma_hand_shaked & (dma_wr_en|(~dma_wr_en&delete_delay)) & ~double_delay) begin
				//	if (dma_wr_en) begin
						double_delay <= 0;
						delete_delay <= 0;
						if(dma_wr_delay_num!=2'b11 && delay_count>1) begin
							dma_wr_delay_num <= dma_wr_delay_num-1;
						end

						if (i_result_scale) begin // w/o scale
							if (wr_flag==0) begin
								o_dma_wr_data[15:0] <= {dma_wr_data_wire, dma_wr_data2_wire};
								wr_flag <= 1;
								o_dma_wr_en <= 0;
								if(delay_count<2'b11) delay_count <= delay_count+1   ;
							end
							else begin
								o_dma_wr_data[31:16] <= {dma_wr_data_wire, dma_wr_data2_wire};
								wr_flag <= 0;
								o_dma_wr_en <= 1;
								dma_hand_shaked <= 0;
								delay_count <= 0;
								o_dma_wr_addr <= o_dma_wr_addr+1;
							end
						end
						else begin
							case(wr_flag)
								2'b00: begin
									o_dma_wr_data[7:0] <= dma_wr_data_wire;
									o_dma_wr_en <= 0;
									wr_flag <= 2'b01;
									if(delay_count<2'b11) delay_count <= delay_count+1;
								end
								2'b01: begin
									o_dma_wr_data[15:8] <= dma_wr_data_wire;
									o_dma_wr_en <= 0;
									wr_flag <= 2'b10;
								end
								2'b10: begin
									o_dma_wr_data[23:16] <= dma_wr_data_wire;
									o_dma_wr_en <= 0;
									wr_flag <= 2'b11;
								end
								2'b11: begin
									o_dma_wr_data[31:24] <= dma_wr_data_wire;
									o_dma_wr_en <= 1;
									dma_hand_shaked <= 0;
									delay_count <= 0;
									o_dma_wr_addr <= o_dma_wr_addr+1;
									wr_flag <= 2'b00;
								end
							endcase
						end
				//	end
				end
				else begin
					if(~dma_hand_shaked) begin
        	                		dma_hand_shaked <= i_hand_shaked;
	                                	if(delay_count<3 & dma_wr_en) begin
                	                        	dma_wr_delay_num <= dma_wr_delay_num+1;
                        	        	end
					
						if(~dma_wr_en) double_delay <= 1;
					//	else double_delay <= 0;
						
						if(delay_count<2'b11) delay_count <= delay_count+1      ;
						delete_delay <= 0;
                	                end
					else  begin
						if (~dma_hand_shaked_d2 && ~i_pool) begin 
							delete_delay <= 1;
							double_delay <= 0;
						end
						else begin 
							double_delay <= 0;
							delete_delay <= 0;
						end
						if(double_delay & delay_count<3 & dma_wr_en)  
							dma_wr_delay_num <= dma_wr_delay_num+1;
					end
				end
			end
			else begin
				dma_hand_shaked <= 1;
				o_dma_wr_addr <= i_dma_wr_base_addr;
				o_dma_wr_en <= 0;
			end
		end
	end

	always @(posedge i_clk) begin
		if(i_rst) begin
			dma_wr_data <= 8'b1000_0000;
			dma_wr_en <= 0;
		end
		else if(status==BURST && (status_reset==4'b1111)) begin
			if (i_pool==0) begin
				if (pmem_rd_en0_d1 || pmem_rd_en1_d1) begin 
					if (~i_result_scale) begin // w/i scale
						if (pmem_rd_en0_d1) dma_wr_data <= pmem_rd_data0;
						else dma_wr_data <= pmem_rd_data1;
					end
					else begin // w/o scale
						dma_wr_data <= i_pmem_rd_data0[15:8];
						dma_wr_data2 <= i_pmem_rd_data0[7:0];
					end
					dma_wr_en <= 1;
				end
				else begin
					dma_wr_en <= 0;
				end
			end 
			else begin
				if (pmem_rd_en0_d1) begin
					if (pool_count==2'b01) begin
						dma_wr_data <= pmem_rd_data0;
					end
					else if (pmem_rd_data0>dma_wr_data) begin
						dma_wr_data <= pmem_rd_data0;
					end
					if (pool_count==2'b00) begin
						dma_wr_en <= 1;
					end
					else begin
						dma_wr_en <= 0;
					end
				end
				else if (pmem_rd_en1_d1) begin
					if (pool_count==2'b01) begin
						dma_wr_data <= pmem_rd_data1;
					end
					else if (pmem_rd_data1>dma_wr_data) begin
						dma_wr_data <= pmem_rd_data1;
					end
					if (pool_count==2'b00) begin
						dma_wr_en <= 1;
					end
					else begin
						dma_wr_en <= 0;
					end
				end
			end
		end
		else begin
			dma_wr_en <= 0;
		end
	end

endmodule










