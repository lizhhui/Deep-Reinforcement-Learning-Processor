module test_bench;

localparam addr_width_lp        = 10;
localparam data_width_lp        = 32;
localparam x_cord_width_lp      = 2 ;
localparam y_cord_width_lp      = 2 ;
localparam cycle_time_lp = 50;


logic clk, reset, finish;


     mesh_nn
  #(
       .x_cord_width_p   (2 )
      ,.y_cord_width_p   (2 )
      ,.data_width_p     (32 )
      ,.addr_width_p     (10 )
  )nn_accel
   (  .clk_i(clk)
    , .reset_i(reset)

    // mesh network
    , .link_sif_i       ( 0)
    , .link_sif_o       ( )

    , .my_x_i           ( 2'b0 )
    , .my_y_i           ( 2'b0 )

    , .dest_x_i         ( 2'b1 )
    , .dest_y_i         ( 2'b1 )

    // , .finish_o(finish)
    );


   always #10 clk = ~clk;

   initial begin
        clk = 0;
        reset = 1;
	#20
	reset = 0;
	#20
	reset = 1;
        #1000
        $finish();
   end

endmodule
