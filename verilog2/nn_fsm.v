// nn_fsm

module nn_fsm
#(parameter
	DATA_WIDTH = 8,
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
	input i_rst,

	input i_start,

	input [2:0] i_mode,
	input [3:0] i_stride,
	input [8:0] i_img_c,
	input [7:0] i_out_w,
	input [7:0] i_out_c,

	input [15:0] i_dma_rd_data,
	input [IMEM_ADDR_WIDTH-1:0] i_img_wr_count,

	output reg [2:0] o_wgt_shift,
	output reg o_bias_sel, // 0: add bias; 1: add psum

	output reg [3:0] o_psum_shift,
	output reg [DATA_WIDTH-1:0] o_bias,
	output reg o_update_bias,

	output reg o_img_bf_wr_en,
	output reg [IMEM_ADDR_WIDTH-1:0] o_img_bf_wr_addr,
	// output reg [IMEM_DATA_WIDTH-1:0] o_img_bf_wr_data,
	output reg [IMEM_ADDR_WIDTH-1:0] o_img_bf_rd_addr,

	output reg o_pmem_wr_en,
	output reg [PMEM_ADDR_WIDTH-1:0] o_pmem_wr_addr0,
	output reg [PMEM_ADDR_WIDTH-1:0] o_pmem_wr_addr1,
	output reg [PMEM_ADDR_WIDTH-1:0] o_pmem_rd_addr0,
	output reg [PMEM_ADDR_WIDTH-1:0] o_pmem_rd_addr1,

	output reg o_wmem_wr_en,
	output reg [WMEM_ADDR_WIDTH-1:0] o_wmem_wr_addr,
	output reg [TOTAL_IN_WIDTH-1:0] o_wmem_wr_data,
	output reg [WMEM_ADDR_WIDTH-1:0] o_wmem_rd_addr,
	output reg o_update_wgt

};
	reg [1:0] status; // 2'b00: initial/reset; 2'b01: wrt img bf
					  // 2'b10: compute/wrt wgt bf; 2'b11: burst (relu/pool) 

	reg change;
	reg [1:0] img_wr_flag;
	reg [IMEM_ADDR_WIDTH-1:0] img_wr_count;

	// always @(posedge i_clk or negedge i_rst) begin
	// 	if (~i_rst) begin
	// 		status <= 2'b00;
	// 	end
	// 	else if(change) begin
	// 		status <= status + 1'b1;
	// 	end
	// end

	always @(posedge i_clk or negedge i_rst) begin
		if (~i_rst) begin
			status <= 2'b00;
			img_wr_flag <= 2'b00;
		end
		else begin
			case (status)
				2'b00: begin
					o_img_bf_wr_addr <= 0;
					o_img_bf_wr_data <= 0;
					o_img_bf_wr_en <= 0;
					img_wr_flag <= 2'b00;
					img_wr_count <= 0;
					if (i_start) begin
						status <= 2'b01;
					end			
				end
				2'b01: begin
					o_img_bf_wr_addr <= o_img_bf_wr_addr + 1'b1;
					if (img_wr_flag==2'b00) begin
						img_wr_flag <= 2'b01;
						o_img_bf_wr_data[15:0] <= i_dma_rd_data;
						o_img_bf_wr_en <= 0;
					end
					else if (img_wr_flag==2'b01) begin
						img_wr_flag <= 2'b10;
						o_img_bf_wr_data[31:16] <= i_dma_rd_data;
					end
					else if (img_wr_flag==2'b10) begin
						img_wr_flag <= 2'b00;
						o_img_bf_wr_data[47:32] <= i_dma_rd_data;
						o_img_bf_wr_en <= 1;

						if (img_wr_count == i_img_wr_count)
							img_wr_count <= 0;
							status <= 2'b01;
						else 
							img_wr_count <= img_wr_count+1'b1;
					end
					else begin
						o_img_bf_wr_en <= 0;
					end
				end
				2'b10: begin
					o_img_bf_wr_en <= 0;


					
				end
			endcase
		end
	end

endmodule



