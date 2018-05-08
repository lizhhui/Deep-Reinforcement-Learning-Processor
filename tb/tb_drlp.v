// Testbench for drlp
module tb_drlp();

reg clk, rst_n;
reg [31:0] cfg;
reg [2:0] cfg_addr;
reg cfg_wr_en;

reg start;

wire [31:0] dma_wr_addr;
wire dma_wr_en;
wire [31:0] dma_wr_data;
wire dma_rd_en;
wire [31:0] dma_rd_addr;


wire [31:0] dma_rd_data;

wire valid;

//wire finish;

drlp drlp_inst(
	.i_clk(clk),
	.i_rst(rst_n),
	.i_cfg(cfg),
	.i_cfg_addr(cfg_addr),
	.i_cfg_wr_en(cfg_wr_en),

	//.i_start(start),
	.i_dma_rd_data(dma_rd_data),
	.i_dma_rd_ready(valid),

	.o_dma_wr_addr(dma_wr_addr),
	.o_dma_wr_en(dma_wr_en),
	.o_dma_wr_data(dma_wr_data),
	.o_dma_rd_en(dma_rd_en),
	.o_dma_rd_addr(dma_rd_addr)

	//.o_finish(finish)
	);

dram dram_inst(
  .i_clk(clk), 
  .i_rst(rst_n),
  .i_wr_en(dma_wr_en),
  .i_wr_addr(dma_wr_addr),
  .i_wr_data(dma_wr_data), 
  .i_rd_en(dma_rd_en),   
  .i_rd_addr(dma_rd_addr), 
  .o_rd_data(dma_rd_data),
  .o_valid(valid)
);


initial begin
	clk = 1'b0;
	rst_n = 1'b1;
	
	repeat(2) #10 clk = ~clk;
	rst_n = 1'b0;
	
	repeat(2) #10 clk = ~clk;
	rst_n = 1'b1;
	
	forever #10 clk = ~clk;
end

initial begin
	cfg = 32'b0000_0000_0000_0000_0000_0000_0000_0000;
	cfg_addr = 3'd0;
	cfg_wr_en = 0;

	#45
	cfg = 32'b00_0_1_001_000_000001_00110000_00000001;
	cfg_addr = 3'd0;
	cfg_wr_en = 1;
	// mode_pool_relu_stride_psumshift_xmove_zmove_ymove

	// #20
	// cfg = 32'b00110000_00000001;
	// cfg_addr = 3'd1;
	// cfg_wr_en = 1;
	// // zmove_ymove
	// // 48_   1

	#20
	cfg = {12'd768, 1'b0, 3'd4, 16'b1100_0000_0000_0000};
	cfg_addr = 3'd1;
	cfg_wr_en = 1;
	// imgwrcount_resultscale_resultshift

	// #20
	// cfg = 32'b1100_0000_0000_0000;
	// cfg_addr = 3'd3;
	// cfg_wr_en = 1;
	// // TBD0

	#20
	cfg = 32'd0;
	cfg_addr = 3'd2;
	cfg_wr_en = 1;
	// dma_img_base_addr

	#20
	cfg = 32'd2040;
	cfg_addr = 3'd3;
	cfg_wr_en = 1;
	// dma_wgt_base_addr

	#20
	cfg = 32'd34000;
	cfg_addr = 3'd4;
	cfg_wr_en = 1;
	// dma_wr_base_addr

	#20
	cfg = 32'd0;
	cfg_addr = 3'd5;
	cfg_wr_en = 1;
	// dma_wr_base_addr

	#20
	cfg = 32'd1;
	cfg_addr = 3'd6;
	cfg_wr_en = 1;

	#20
	cfg_wr_en = 0;

	#200
	cfg = 32'd0;
	cfg_addr = 3'd6;
	cfg_wr_en = 1;

	#20
	cfg_wr_en = 0;
	
	

end

endmodule