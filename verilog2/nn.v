module nn
#(parameter
	DATA_WIDTH = 8,
	DMA_ADDR_WIDTH = 10,
	COLUMN_NUM = 6,
	ROW_NUM = 6,
	PMEM_ADDR_WIDTH = 8,
	WMEM_ADDR_WIDTH = 7,
	IMEM_ADDR_WIDTH = 10, // depth = 1024, 4KB
  	IMEM_DATA_WIDTH = DATA_WIDTH*6,
	COLUMN_DATA_WIDTH = DATA_WIDTH*COLUMN_NUM,
	ROW_DATA_WIDTH = DATA_WIDTH*ROW_NUM,
	OUT_WIDTH = 2*DATA_WIDTH,
	COLUMN_OUT_WIDTH = OUT_WIDTH+3,
	TOTAL_IN_WIDTH = DATA_WIDTH*COLUMN_NUM*ROW_NUM
	)
(
	input i_clk,
	input [15:0] i_cfg,
	input [1:0] i_cfg_addr,
	input i_cfg_wr_en,
	input [15:0] i_dma_rd_data,

	output wire [DMA_ADDR_WIDTH-1:0] o_dma_wr_addr,
	output wire o_dma_wr_en,
	output wire [15:0] o_dma_wr_data,
	output wire [DMA_ADDR_WIDTH-1:0] o_dma_rd_addr

	);

	wire [2:0] mode;
	wire [3:0] stride;
	wire [8:0] img_c;
	wire [7:0] out_w;
	wire [7:0] out_c;
	wire [12:0] TBD;
	wire [1:0] pool; // 0: wo/pool; 1: 2x2 pool; 2: 3x3 pool; 3: 4x4 pool
	wire relu; // 1: w/relu; 0: wo/relu


	wire [2:0] wgt_shift; // shift RIGHT how many 8 bits
	wire bias_sel; // 0: add bias; 1: add psum

	wire [3:0] psum_shift;
	wire [DATA_WIDTH-1:0] bias;
	wire update_bias;
	wire bias_sel; // 0: add bias; 1: add psum


	wire img_bf_wr_en;
	wire [IMEM_ADDR_WIDTH-1:0] img_bf_wr_addr;
	wire [IMEM_DATA_WIDTH-1:0] img_bf_wr_data;
	wire [IMEM_ADDR_WIDTH-1:0] img_bf_rd_addr;

	wire pmem_wr_en;
	wire [PMEM_ADDR_WIDTH-1:0] pmem_wr_addr0;
	wire [PMEM_ADDR_WIDTH-1:0] pmem_wr_addr1;
	wire [PMEM_ADDR_WIDTH-1:0] pmem_rd_addr0;
	wire [PMEM_ADDR_WIDTH-1:0] pmem_rd_addr1;

	wire [COLUMN_NUM-1:0] wmem_wr_en;
	wire [WMEM_ADDR_WIDTH-1:0] wmem_wr_addr;
	wire [TOTAL_IN_WIDTH-1:0] wmem_wr_data;
	wire [WMEM_ADDR_WIDTH-1:0] wmem_rd_addr;
	wire update_wgt;



	wire [IMEM_ADDR_WIDTH-1:0] img_bf_wr_addr;
	wire [IMEM_DATA_WIDTH-1:0] img_bf_wr_data;
	wire [IMEM_ADDR_WIDTH-1:0] img_bf_rd_addr;

	wire shift;
	wire sel_3x3;

	wire wmem0_state, wmem1_state;

	nn_cfg cfg(
		.i_clk(i_clk),
		.i_cfg(i_cfg),
		.i_addr(i_cfg_addr),
		.i_wr_en(i_cfg_wr_en),
		.o_cfg0({mode,stride,imgc}),
		.o_cfg1({out_w,out_c}),
		.o_cfg2({TBD,pool,relu}),
		.o_cfg3()
		);


	nn_fsm fsm(
		.i_clk(i_clk),
		.i_rst(i_rst),
		.i_start(i_start),
		.i_mode(mode),
		.i_stirde(stride),
		.i_img_c(img_c),
		.i_out_w(out_w),
		.i_out_c(out_c),
		.i_img_wr_count(),//????
		.i_dma_rd_data(i_dma_rd_data),
		.o_img_bf_wr_addr(img_bf_wr_addr),
		.o_img_bf_wr_data(img_bf_wr_data),
		.o_img_bf_rd_addr(img_bf_rd_addr),
		.o_shift(shift),
		.o_3x3(sel_3x3),
		.o_wmem0_state(wmem0_state), // 0: to be wrote; 1: to be read
		.o_wmem1_state(wmem1_state), // 0: to be wrote; 1: to be read
		.o_wmem_wr_en(wmem_wr_en),
		.o_wmem_wr_addr(wmem_wr_addr),
		.o_wmem_wr_data(wmem_wr_data),
		.o_wmem_rd_addr(wmem_rd_addr),

		.o_wgt_shift(wgt_shift),
		.o_bias_sel(), // 0: add bias; 1: add psum ???

		.o_psum_shift(), // ??????
		.o_bias(),
		.o_update_bias(), //???????

		.o_pmem_wr_en0,
		.o_pmem_wr_en1,
		.o_pmem_rd_en0,
		.o_pmem_rd_en1,
		.o_pmem_wr_addr0(pmem_wr_addr0),
		.o_pmem_wr_addr1(pmem_wr_addr1),
		.o_pmem_rd_addr0(pmem_rd_addr0),
		.o_pmem_rd_addr1(pmem_rd_addr1),

		.o_update_wgt(update_wgt)

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


	PE PE_inst(
		.i_clk(i_clk),
		.i_img(img),

		.i_mode(mode), // 2'b00: 2-3x3, 2'b01: 4x4, 2'b10: 5x5, 2'b11: 6x6
		.i_wgt_shift(wgt_shift), // shift RIGHT how many 8 bits


		.i_psum_shift(psum_shift),
		.i_bias(),
		.i_update_bias(),
		.i_bias_sel(bias_sel), // 0: add bias; 1: add psum


		.i_pmem_wr_en0(pmem_wr_en0),
		.i_pmem_wr_en1(pmem_wr_en1),
		.i_pmem_rd_en0(pmem_rd_en0),
		.i_pmem_rd_en1(pmem_rd_en1),
		.i_pmem_wr_addr0(pmem_wr_addr0),
		.i_pmem_wr_addr1(pmem_wr_addr1),
		.i_pmem_rd_addr0(pmem_rd_addr0),
		.i_pmem_rd_addr1(pmem_rd_addr1),

		.i_wmem_wr_en(wmem_wr_en),
		.i_wmem_wr_addr(wmem_wr_addr),
		.i_wmem_wr_data(wmem_wr_data),
		.i_wmem_rd_addr(wmem_rd_addr),
		.i_update_wgt(update_wgt),


		.o_result0(),
		.o_result1()

		);

endmodule