// Testbench for nn
module tb_nn();

reg clk, rst_n;
reg [15:0] cfg;
reg [1:0] cfg_addr;
reg cfg_wr_en;

reg start;

wire [5:0] dma_wr_addr;
wire dma_wr_en;
wire [15:0] dma_wr_data;
wire dma_rd_en;
wire [5:0] dma_rd_addr;


wire [15:0] dma_rd_data;

nn nn_inst(
	.i_clk(clk),
	.i_rst(rst_n),
	.i_cfg(cfg),
	.i_cfg_addr(cfg_addr),
	.i_cfg_wr_en(cfg_wr_en),
	.i_dma_rd_data(dma_rd_data),

	.i_start(start),

	.o_dma_wr_addr(dma_wr_addr),
	.o_dma_wr_en(dma_wr_en),
	.o_dma_wr_data(dma_wr_data),
	.o_dma_rd_en(dma_rd_en),
	.o_dma_rd_addr(dma_rd_addr)
	);

dram dram_inst(
  .i_clk(clk), 
  .i_wr_en(dma_wr_en),
  .i_wr_addr(dma_wr_addr),
  .i_wr_data(dma_wr_data), 
  .i_rd_en(dma_rd_en),   
  .i_rd_addr(dma_rd_addr), 
  .o_rd_data(dma_rd_data)
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
	start = 0;
	cfg = 16'b0000_0000_0000_0000;
	cfg_addr = 2'b00;
	cfg_wr_en = 0;

	#45
	cfg = 16'b000_0001_000000100;
	cfg_addr = 2'b00;
	cfg_wr_en = 1;
	// mode: 4-3x3; stride: 1; # input channel: 4

	#20
	cfg = 16'b00000010_00000001;
	cfg_addr = 2'b01;
	cfg_wr_en = 1;
	// out width: 2; # output channel: 2

	#20
	cfg = 16'b000_0000_000000_000;
	cfg_addr = 2'b10;
	cfg_wr_en = 1;

	#20
	cfg = {10'd64, 6'd0};
	cfg_addr = 2'b11;
	cfg_wr_en = 1;
	

	#20
	cfg_wr_en = 0;
	start = 1;

end


endmodule


module dram
(
  input i_clk, 
  input i_wr_en,
  input [9:0] i_wr_addr,
  input [15:0] i_wr_data, 
  input i_rd_en,   
  input [9:0] i_rd_addr, 

  output wire [15:0] o_rd_data
);


// Here for the fake memory, only 4 will be implemented
reg [15:0] REG [0:1023];

reg [9:0] rd_addr;


assign o_rd_data = i_rd_en? 16'h01_01:0;

// always @ (posedge i_clk) begin
//   if(i_rd_en) o_rd_data <= 1;
//   else o_rd_data <= 0;
//   // rd_addr <= i_rd_addr;
// end


always @ (posedge i_clk) begin
 	if(i_wr_en) REG[i_wr_addr] <= i_wr_data; // Write behavior
end

endmodule