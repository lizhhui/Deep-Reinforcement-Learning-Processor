// nn_cfg

module nn_cfg(
	input i_clk,
	input i_cfg,
	input i_addr,
	input i_wr_en,
	output wire [15:0] o_cfg0,
	output wire [15:0] o_cfg1,
	output wire [15:0] o_cfg2,
	output wire [15:0] o_cfg3
	);

	reg [15:0] cfg[0:3];
	always @(posedge i_clk) begin
		if (i_wr_en) begin
			cfg[i_addr] <= i_cfg; 
		end
	end

	assign o_cfg0 = cfg[0];
	assign o_cfg1 = cfg[1];
	assign o_cfg2 = cfg[2];
	assign o_cfg3 = cfg[3];

endmodule