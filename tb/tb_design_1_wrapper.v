module tb_design_1_wrapper();

reg clk, rst_n;
reg [15:0] cfg;
reg [1:0] cfg_addr;
reg cfg_wr_en;

reg start;

reg dma_rd_ready;


wire finish;

design_1_wrapper design_1_wrapper_inst(
	.i_cfg(cfg),
	.i_cfg_addr(cfg_addr),
	.i_cfg_wr_en(cfg_wr_en),
	.i_clk(clk),
	.i_dma_rd_ready(dma_rd_ready),
	.i_rst(rst_n),
	.i_start(start),
	.o_finish(finish)
	);

initial begin
	clk = 1'b0;
	rst_n = 1'b1;
	dma_rd_ready <= 1;
	
	repeat(2) #10 clk = ~clk;
	rst_n = 1'b0;
	
	repeat(2) #10 clk = ~clk;
	rst_n = 1'b1;
	
	forever #10 clk = ~clk;
end

initial begin
	start = 0;
	cfg = 16'b0000_0000_0000_0000;
	cfg_addr = 2'b00;
	cfg_wr_en = 0;

	#45
	cfg = 16'b11_00_1_110_0000_0000;
	cfg_addr = 2'b00;
	cfg_wr_en = 1;
	// mode_pool_relu_stride_psumshift_TBD0

	#20
	cfg = 16'b0000010_0000001_00;
	cfg_addr = 2'b01;
	cfg_wr_en = 1;
	// zmove_ymove_TBD1

	#20
	cfg = 16'b00000_00000_000011;
	cfg_addr = 2'b10;
	cfg_wr_en = 1;
	// dma_img_base_addr, dma_wgt_base_addr, xmove

	#20
	cfg = 16'd200;
	cfg_addr = 2'b11;
	cfg_wr_en = 1;
	// dma_wr_base_addr, img_wr_count

	#20
	cfg_wr_en = 0;
	start = 1;

	#20 
	start = 0;

end

endmodule