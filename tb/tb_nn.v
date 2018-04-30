// Testbench for nn
module tb_nn();

reg clk, rst_n;
reg [15:0] cfg;
reg [1:0] cfg_addr;
reg cfg_wr_en;

reg start;

reg dma_rd_ready;

wire [4:0] dma_wr_addr;
wire dma_wr_en;
wire [7:0] dma_wr_data;
wire dma_rd_en;
wire [4:0] dma_rd_addr;


wire [7:0] dma_rd_data;

wire valid;

wire finish;

nn nn_inst(
	.i_clk(clk),
	.i_rst(rst_n),
	.i_cfg(cfg),
	.i_cfg_addr(cfg_addr),
	.i_cfg_wr_en(cfg_wr_en),

	.i_start(start),
	.i_dma_rd_data(dma_rd_data),
	.i_dma_rd_ready(valid),

	.o_dma_wr_addr(dma_wr_addr),
	.o_dma_wr_en(dma_wr_en),
	.o_dma_wr_data(dma_wr_data),
	.o_dma_rd_en(dma_rd_en),
	.o_dma_rd_addr(dma_rd_addr),


	.o_finish(finish),
	);

dram dram_inst(
  .i_clk(clk), 
  .i_wr_en(dma_wr_en),
  .i_wr_addr({5'b0,dma_wr_addr}),
  .i_wr_data(dma_wr_data), 
  .i_rd_en(dma_rd_en),   
  .i_rd_addr(dma_rd_addr), 
  .o_rd_data(dma_rd_data),
  .o_valid(valid)
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


module dram
(
  input i_clk, 
  input i_rst,
  input i_wr_en,
  input [9:0] i_wr_addr,
  input [7:0] i_wr_data, 
  input i_rd_en,   
  input [9:0] i_rd_addr, 

  output reg [7:0] o_rd_data,
  output reg o_valid
);


// Here for the fake memory, only 4 will be implemented
reg [7:0] REG [0:1023];


always @ (posedge i_clk or negedge i_rst) begin
	if (~i_rst) begin
		o_rd_data <= 0;
	  	o_valid <= 0;
	end
	else begin
	  if(i_rd_en) begin 
	  	o_rd_data <= REG[i_rd_addr];
	  	o_valid <= 1;
	  end
	  else begin 
	  	o_rd_data <= 8'bx;
	  	o_valid <= 0;
	  end
	end
end


always @ (posedge i_clk or negedge i_rst) begin
	if (~i_rst) begin
		REG[0] = 0;
		
	end
	else if(i_wr_en) begin
		REG[i_wr_addr] <= i_wr_data; // Write behavior
	end
end

endmodule