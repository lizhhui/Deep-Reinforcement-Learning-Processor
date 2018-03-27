// MAC_4x8
// Author: Huwan MACng
// Create Date: Mar.26, 2018

module MAC_4x8
#(parameter
	DATA_WIDTH = 8,
	INTER_WIDTH = 2*DATA_WIDTH,
	OUT_WIDTH = 4*DATA_WIDTH
	)
(
	// inputs
	input signed [DATA_WIDTH-1:0] a0,
	input signed [DATA_WIDTH-1:0] a1,
	input signed [DATA_WIDTH-1:0] a2,
	input signed [DATA_WIDTH-1:0] a3,
	input signed [DATA_WIDTH-1:0] b0,
	input signed [DATA_WIDTH-1:0] b1,
	input signed [DATA_WIDTH-1:0] b2,
	input signed [DATA_WIDTH-1:0] b3,
	// input sel, // 0: 4*8bit MAC, 1: 1*16bit MAC

	// outputs
	output signed [OUT_WIDTH-1:0] result
	);

wire signed [INTER_WIDTH-1:0] r0;
wire signed [INTER_WIDTH-1:0] r1;
wire signed [INTER_WIDTH-1:0] r2;
wire signed [INTER_WIDTH-1:0] r3;
// wire signed [OUT_WIDTH-1:0] r0_sl16;
// wire signed [INTER_WIDTH:0] r2_r3;
// wire signed [INTER_WIDTH+8:0] r2_r3_sl8;


assign r0 = a0*b0;
assign r1 = a1*b1;
assign r2 = a2*b2;
assign r3 = a3*b3;

// assign r0_sl16 = (sel==0)? r0:(r0<<<16);
// assign r2_r3 = r2+r3;
// assign r2_r3_sl8 = (sel==0)? r2_r3:(r2_r3<<<8);

// assign result = r0_sl16 + r2_r3_sl8 + r2;

assign result = r0+r1+r2+r3;

endmodule