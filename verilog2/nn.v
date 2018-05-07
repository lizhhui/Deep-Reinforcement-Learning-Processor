module nn_accelerator
#(parameter
	DATA_WIDTH = 8,
	PE_NUM = 16,
	DMA_ADDR_WIDTH = 32,
	DMA_DATA_WIDTH = 32,
	CFG_WIDTH = 32,
	CFG_ADDR_WIDTH = 3,
	COLUMN_NUM = 6,
	ROW_NUM = 6,
	PMEM_ADDR_WIDTH = 8,
	WMEM_ADDR_WIDTH = 7,
	IMEM_ADDR_WIDTH = 12, // depth = 1024, 4KB
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

	input [CFG_WIDTH-1:0] i_cfg,
	input [CFG_ADDR_WIDTH-1:0] i_cfg_addr,
	input i_cfg_wr_en,
	//input i_start,

	input [DMA_DATA_WIDTH-1:0] i_dma_rd_data,
	input i_dma_rd_ready,

	output wire [DMA_ADDR_WIDTH-1:0] o_dma_wr_addr,
	output wire o_dma_wr_en,
	output wire [DMA_DATA_WIDTH-1:0] o_dma_wr_data,
	output wire o_dma_rd_en,
	output wire [DMA_ADDR_WIDTH-1:0] o_dma_rd_addr

	// output wire o_finish

	);

	// config0
	wire [1:0] mode; // 2'd0: 4-3x3, 2'd1: 4x4, 2'd2: 5x5, 2'd3: 6x6
	wire pool; // 0: w/o pool; 1: 2x2 pool;
	wire relu; // 1: w/i relu; 0: w/o relu
	wire [2:0] stride;
	wire [2:0] psum_shift;
	wire [5:0] xmove;
	wire [7:0] zmove;
	wire [7:0] ymove;

	// config1
	wire [11:0] img_wr_count;
	wire result_scale; // 0: w/i scale; 1: w/o scale
	wire [2:0] result_shift;
	wire img_bf_update;
	wire wgt_mem_update;
	wire bias_psum; // 0: add bias; 1: add psum
	wire wo_compute; //0: compute; 1: just output
	wire [11:0] TBD0; 

	// config2
	wire [DMA_ADDR_WIDTH-1:0] dma_img_base_addr;
	// config3
	wire [DMA_ADDR_WIDTH-1:0] dma_wgt_base_addr;
	// config4
	wire [DMA_ADDR_WIDTH-1:0] dma_wr_base_addr;
	// config5
	wire [31:0] finish_write;
	// config6
	wire start;
	

	wire [2:0] wgt_shift; // shift RIGHT how many 8 bits

	wire [DATA_WIDTH-1:0] bias;
	wire update_bias;
	wire bias_sel; // 0: add bias; 1: add psum
	reg [PE_NUM-1:0] update_bias_pe;


	wire img_bf_wr_en;
	wire [IMEM_ADDR_WIDTH-1:0] img_bf_wr_addr;
	wire [IMEM_DATA_WIDTH-1:0] img_bf_wr_data;
	wire [IMEM_ADDR_WIDTH-1:0] img_bf_rd_addr;

	wire pmem_wr_en0;
	wire pmem_wr_en1;
	wire pmem_rd_en0;
	wire pmem_rd_en1;
	wire [PMEM_ADDR_WIDTH-1:0] pmem_wr_addr0;
	wire [PMEM_ADDR_WIDTH-1:0] pmem_wr_addr1;
	wire [PMEM_ADDR_WIDTH-1:0] pmem_rd_addr0;
	wire [PMEM_ADDR_WIDTH-1:0] pmem_rd_addr1;

	wire [COLUMN_NUM-1:0] wmem_wr_en;
	reg [COLUMN_NUM-1:0] wmem_wr_en_pe[0:PE_NUM-1];
	wire [WMEM_ADDR_WIDTH-1:0] wmem_wr_addr;
	wire [ROW_DATA_WIDTH-1:0] wmem_wr_data;
	wire [WMEM_ADDR_WIDTH-1:0] wmem_rd_addr;
	wire update_wgt;

	wire psum_sel;

	wire shift;
	wire sel_3x3;

	wire wmem0_state, wmem1_state;

	wire [15:0] pmem_rd_data0[0:PE_NUM-1], pmem_rd_data1[0:PE_NUM-1];
	wire [15:0] pmem_rd_data0_relu, pmem_rd_data1_relu;

	wire [PE_NUM-1:0] PE_en;

	wire [3:0] PE_sel;

	wire [47:0] buffer_data;
	wire buffer_ready;

	wire [31:0] dma_base_addr;
	wire rd_dma;

	wire finish;

	nn_cfg cfg(
		.i_clk(i_clk),
		.i_cfg(i_cfg),
		.i_addr(i_cfg_addr),
		.i_wr_en(i_cfg_wr_en),
		// config0
		.o_mode(mode), // 2'd0: 4-3x3, 2'd1: 4x4, 2'd2: 5x5, 2'd3: 6x6
		.o_pool(pool), // 0: w/o pool, 1: 2x2 pool,
		.o_relu(relu), // 1: w/i relu, 0: w/o relu
		.o_stride(stride),
		.o_psum_shift(psum_shift),
		.o_xmove(xmove),
		.o_zmove(zmove),
		.o_ymove(ymove),
		// config1
		.o_img_wr_count(img_wr_count),
		.o_result_scale(result_scale), // 0: w/i scale, 1: w/o scale
		.o_result_shift(result_shift),
		.o_img_bf_update(img_bf_update),
		.o_wgt_mem_update(wgt_mem_update),
		.o_bias_psum(bias_psum), // 0: add bias, 1: add psum
		.o_wo_compute(wo_compute), //0: compute, 1: just output 
		// config2
		.o_dma_img_base_addr(dma_img_base_addr),
		// config3
		.o_dma_wgt_base_addr(dma_wgt_base_addr),
		// config4
		.o_dma_wr_base_addr(dma_wr_base_addr),
		// config5
		.o_finish_write(finish_write),
		// config6
		.o_start(start)
		);

	nn_rd_buffer rd_buf(
		.i_clk(i_clk),
		.i_rst(i_rst),
		.i_dma_base_addr(dma_base_addr),
		.i_rd_dma(rd_dma),
		.i_data(i_dma_rd_data),
		.i_ready(i_dma_rd_ready),
		.i_mode(mode),
		.o_dma_rd_addr(o_dma_rd_addr),
		.o_dma_rd_en(o_dma_rd_en),
		.o_buf_data(buffer_data),
		.o_buf_ready(buffer_ready)
		);


	nn_fsm fsm(
		.i_clk(i_clk),
		.i_rst(i_rst),
		.i_start(start),

		.i_mode(mode),
		.i_pool(pool),
		.i_stride(stride),
		.i_xmove(xmove),
		.i_zmove(zmove),
		.i_ymove(ymove),
		.i_img_wr_count(img_wr_count),
		.i_result_scale(result_scale),
		.i_result_shift(result_shift),
		.i_img_bf_update(img_bf_update),
		.i_wgt_mem_update(wgt_mem_update),
		.i_bias_psum(bias_psum),
		.i_wo_compute(wo_compute),

		.i_dma_img_base_addr(dma_img_base_addr),
		.i_dma_wgt_base_addr(dma_wgt_base_addr),
		.i_dma_wr_base_addr(dma_wr_base_addr),

		.i_pmem_rd_data0(pmem_rd_data0_relu),
		.i_pmem_rd_data1(pmem_rd_data1_relu),

		.i_buffer_data(buffer_data),
		.i_buffer_ready(buffer_ready),

		.o_dma_rd_en(rd_dma),
		.o_dma_base_addr(dma_base_addr),

		.o_img_bf_wr_en(img_bf_wr_en),
		.o_img_bf_wr_addr(img_bf_wr_addr),
		.o_img_bf_wr_data(img_bf_wr_data),
		.o_img_bf_rd_addr(img_bf_rd_addr),
		.o_shift(shift),
		.o_3x3(sel_3x3),
		.o_wmem_wr_en(wmem_wr_en),
		.o_wmem_wr_addr(wmem_wr_addr),
		.o_wmem_wr_data(wmem_wr_data),
		.o_wmem_rd_addr(wmem_rd_addr),

		.o_wgt_shift(wgt_shift),

		.o_bias_sel(bias_sel), // 0: add bias; 1: add psum ???
		.o_bias(bias),
		.o_update_bias(update_bias),

		.o_psum_sel(psum_sel),
		.o_pmem_wr_en0(pmem_wr_en0),
		.o_pmem_wr_en1(pmem_wr_en1),
		.o_pmem_rd_en0(pmem_rd_en0),
		.o_pmem_rd_en1(pmem_rd_en1),
		.o_pmem_wr_addr0(pmem_wr_addr0),
		.o_pmem_wr_addr1(pmem_wr_addr1),
		.o_pmem_rd_addr0(pmem_rd_addr0),
		.o_pmem_rd_addr1(pmem_rd_addr1),
		//.o_PE_en(PE_en),
		.o_PE_sel(PE_sel),

		.o_update_wgt(update_wgt),
		.o_dma_wr_en(o_dma_wr_en),
		.o_dma_wr_addr(o_dma_wr_addr),
		.o_dma_wr_data(o_dma_wr_data),
		.o_finish(finish)
		);
	

	wire [ROW_DATA_WIDTH-1:0] new_img_row;
	wire [TOTAL_IN_WIDTH-1:0] img;

	nn_img_bf img_bf(
		.i_clk(i_clk), 
		.i_wr_en(img_bf_wr_en),
		.i_wr_addr0(img_bf_wr_addr),
		.i_wr_data0(img_bf_wr_data),
		.i_rd_en(1'b1),   
		.i_rd_addr0(img_bf_rd_addr),
		.o_rd_data0(new_img_row)
		);

	nn_sld_rf sld_rf(
		.i_clk(i_clk),
		.i_rst(i_rst),
		.i_data(new_img_row),
		.i_shift(shift),
		.i_mode(mode),
		.i_3x3(sel_3x3),
		.o_img(img)
		);

	always @(*) begin
		wmem_wr_en_pe[0] = 6'b0;
		wmem_wr_en_pe[1] = 6'b0;
		wmem_wr_en_pe[2] = 6'b0;
		wmem_wr_en_pe[3] = 6'b0;
		wmem_wr_en_pe[4] = 6'b0;
		wmem_wr_en_pe[5] = 6'b0;
		wmem_wr_en_pe[6] = 6'b0;
		wmem_wr_en_pe[7] = 6'b0;
		wmem_wr_en_pe[8] = 6'b0;
		wmem_wr_en_pe[9] = 6'b0;
		wmem_wr_en_pe[10] = 6'b0;
		wmem_wr_en_pe[11] = 6'b0;
		wmem_wr_en_pe[12] = 6'b0;
		wmem_wr_en_pe[13] = 6'b0;
		wmem_wr_en_pe[14] = 6'b0;
		wmem_wr_en_pe[15] = 6'b0;
		update_bias_pe = 0;
		wmem_wr_en_pe[PE_sel] = wmem_wr_en;
		update_bias_pe[PE_sel] = update_bias;
	end

	generate
		genvar i;
		for (i = 0; i < PE_NUM; i = i + 1)
		begin: multi_PEs
			PE PE_inst(
				.i_clk(i_clk),
				.i_img(img),

				.i_mode(mode), // 2'b00: 2-3x3, 2'b01: 4x4, 2'b10: 5x5, 2'b11: 6x6
				.i_wgt_shift(wgt_shift), // shift RIGHT how many 8 bits

				.i_psum_shift(psum_shift),
				.i_bias(bias),
				.i_update_bias(update_bias_pe[i]),
				.i_bias_sel(bias_sel), // 0: add bias; 1: add psum

				.i_psum_sel(psum_sel),
				.i_pmem_wr_en0(pmem_wr_en0),
				.i_pmem_wr_en1(pmem_wr_en1),
				.i_pmem_rd_en0(pmem_rd_en0),
				.i_pmem_rd_en1(pmem_rd_en1),
				.i_pmem_wr_addr0(pmem_wr_addr0),
				.i_pmem_wr_addr1(pmem_wr_addr1),
				.i_pmem_rd_addr0(pmem_rd_addr0),
				.i_pmem_rd_addr1(pmem_rd_addr1),

				.i_wmem_wr_en(wmem_wr_en_pe[i]),
				.i_wmem_wr_addr(wmem_wr_addr),
				.i_wmem_wr_data(wmem_wr_data),
				.i_wmem_rd_addr(wmem_rd_addr),
				.i_update_wgt(update_wgt),

				.o_result0(pmem_rd_data0[i]),
				.o_result1(pmem_rd_data1[i])
				);
		end
	endgenerate


	nn_relu relu_inst(
	.i_data0(pmem_rd_data0[PE_sel]),
	.i_data1(pmem_rd_data1[PE_sel]),
	.i_relu(relu),
	.o_data0(pmem_rd_data0_relu),
	.o_data1(pmem_rd_data1_relu)
	);

endmodule