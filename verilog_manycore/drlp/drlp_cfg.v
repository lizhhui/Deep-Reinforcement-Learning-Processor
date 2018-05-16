// nn_cfg

module drlp_cfg(
	input i_clk,
	input [31:0] i_cfg,
	input [2:0] i_addr,
	input i_wr_en,
	input i_rd_en,
	output wire [31:0] o_cfg,
	// config0
	output wire [1:0] o_mode, // 2'd0: 4-3x3, 2'd1: 4x4, 2'd2: 5x5, 2'd3: 6x6
	output wire o_pool, // 0: w/o pool, 1: 2x2 pool,
	output wire o_relu, // 1: w/i relu, 0: w/o relu
	output wire [2:0] o_stride,
	output wire [2:0] o_psum_shift,
	output wire [5:0] o_xmove,
	output wire [7:0] o_zmove,
	output wire [7:0] o_ymove,

	// config1
	output wire [11:0] o_img_wr_count,

	// output wire [11:0] o_TBD0, 

	// config2
	output wire [31:0] o_dma_img_base_addr,
	// config3
	output wire [31:0] o_dma_wgt_base_addr,
	// config4
	output wire [31:0] o_dma_wr_base_addr,
	// config5
	output wire [31:0] o_finish_write,

	// config6
	output wire o_result_scale, // 0: w/i scale, 1: w/o scale
	output wire [2:0] o_result_shift,
	output wire o_img_bf_update,
	output wire o_wgt_mem_update,
	output wire o_bias_psum, // 0: add bias, 1: add psum
	output wire o_wo_compute, //0: compute, 1: just output
	output wire o_start

	);

	reg [31:0] cfg[0:5];
	reg [2:0] rd_addr;

	always @(posedge i_clk) begin
		if (i_wr_en) begin
			cfg[i_addr] <= i_cfg; 
		end
		if (i_rd_en) begin
			rd_addr <= i_addr;
		end
		else begin
			rd_addr <= 3'bx;
		end
	end

	assign o_cfg = cfg[rd_addr];
	
	// config 0 
	assign o_mode = cfg[0][31:30];
	assign o_pool = cfg[0][29];
	assign o_relu = cfg[0][28];
	assign o_stride = cfg[0][27:25];
	assign o_psum_shift = cfg[0][24:22];
	assign o_xmove = cfg[0][21:16];
	assign o_zmove = cfg[0][15:8];
	assign o_ymove = cfg[0][7:0];

	// config 1
	assign o_dma_img_base_addr = cfg[1];

	// config 2
	assign o_dma_wgt_base_addr = cfg[2];

	// config 3
	assign o_dma_wr_base_addr = cfg[3];

	// config 4
	assign o_finish_write = cfg[4];

	// config 5
	assign o_img_wr_count = cfg[5][31:20];
	assign o_result_scale = cfg[5][19];	
	assign o_result_shift = cfg[5][18:16];
	assign o_img_bf_update = cfg[5][15];
	assign o_wgt_mem_update = cfg[5][14];
	assign o_bias_psum = cfg[5][13];
	assign o_wo_compute = cfg[5][12];
	
	assign o_start = cfg[5][0];



endmodule
