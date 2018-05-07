module nn_rd_buffer
#(parameter
	INPUT_WIDTH = 32,
	OUTPUT_WIDTH = 48,
	DMA_ADDR_WIDTH = 32
	)
(
	input i_clk,
	input i_rst,

	input [DMA_ADDR_WIDTH-1:0] i_dma_base_addr,
	input i_rd_dma,

	input [INPUT_WIDTH-1:0] i_data,
	input i_ready,
	input [1:0] i_mode,

	output reg [DMA_ADDR_WIDTH-1:0] o_dma_rd_addr,
	output reg o_dma_rd_en,

	output reg [OUTPUT_WIDTH-1:0] o_buf_data,
	output reg o_buf_ready
	);
	
	reg [2:0] wr_flag;

	reg [23:0] tmp_data;

	always @(posedge i_clk) begin
		if (i_rd_dma) begin
			if (i_ready) begin
				o_dma_rd_addr <= o_dma_rd_addr+1;
			end
			else begin
				o_dma_rd_en <= 1;
				if (o_dma_rd_en) o_dma_rd_addr <= o_dma_rd_addr+1;
			end
		end
		else begin
			o_dma_rd_en <= 0;
			o_dma_rd_addr <= i_dma_base_addr;
		end
	end

	always @(posedge i_clk or negedge i_rst) begin
		if (~i_rst) begin
			o_buf_data <= 48'b0;
			o_buf_ready <= 1'b0;
			wr_flag <= 0;
			tmp_data <= 23'b0;
		end
		else if (i_ready) begin
			if (i_mode==2'b00 || i_mode==2'b11) begin // 3*3 or 6*6
				case (wr_flag)
					3'd0: begin
						o_buf_data[31:0] <= i_data;
						o_buf_ready <= 0;
						wr_flag <= 3'd1;
					end
					3'd1: begin
						o_buf_data[47:32] <= i_data[15:0];
						o_buf_ready <= 1;
						tmp_data[15:0] <= i_data[31:16];
						wr_flag <= 3'd2;
					end
					3'd2: begin
						o_buf_data <= {i_data, tmp_data[15:0]};
						o_buf_ready <= 1;
						wr_flag <= 3'd0;
					end
					default: begin
						o_buf_data <= 0;
						o_buf_ready <= 0;
						wr_flag <= 3'd0;
					end
				endcase
			end
			else if (i_mode==2'b01) begin // 4*4
				o_buf_data[47:32] <= 16'b0;
				o_buf_data[31:0] <= i_data;
				o_buf_ready <= 1;
			end
			else if (i_mode==2'b10) begin // 5*5
				o_buf_data[47:40] <= 8'b0;
				case (wr_flag)
					3'd0: begin
						o_buf_data[31:0] <= i_data;
						o_buf_ready <= 0;
						wr_flag <= 3'd1;
					end
					3'd1: begin
						o_buf_data[39:32] <= i_data[7:0];
						o_buf_ready <= 1;
						tmp_data <= i_data[31:8];
						wr_flag <= 3'd2;
					end
					3'd2: begin
						o_buf_data[39:0] <= {i_data[15:0], tmp_data};
						o_buf_ready <= 1;
						tmp_data[15:0] <= i_data[31:15];
						wr_flag <= 3'd3;
					end
					3'd3: begin
						o_buf_data[39:0] <= {i_data[23:0], tmp_data[15:0]};
						o_buf_ready <= 1;
						tmp_data[7:0] <= i_data[31:23];
						wr_flag <= 3'd4;
					end
					3'd4: begin
						o_buf_data[39:0] <= {i_data, tmp_data[7:0]};
						o_buf_ready <= 1;
						wr_flag <= 3'd0;
					end
				endcase
			end
		end
		else begin
			o_buf_ready <= 0;
		end
	end



endmodule