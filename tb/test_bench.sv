module test_bench

localparam addr_width_lp        = 10;
localparam data_width_lp        = 32;
localparam x_cord_width_lp      = 2 ;
localparam y_cord_width_lp      = 2 ;
localparam cycle_time_lp = 50;


logic clk, reset, finish;


     mesh_nn_accelerator
  #(
       .x_cord_width_p   (x_cord_width_lp )
      ,.y_cord_width_p   (y_cord_width_lp )
      ,.data_width_p     (data_width_lp   )
      ,.addr_width_p     (addr_width_lp   )
  )nn_accel
   (  .clk_i(clk)
    , .reset_i(reset)

    // mesh network
    , .link_sif_i       ( 0)
    , .link_sif_o       ( 0)

    , .my_x_i           ( x_cord_width_p'(0) )
    , .my_y_i           ( y_cord_width_p'(0) )

    , .dest_x_i         ( x_cord_width_p'(1) )
    , .dest_y_i         ( y_cord_width_p'(1) )

    , .finish_o(finish)
    );


   always #10 clk = ~clk;

   initial begin
        clk = 0;
        reset = 0;
        #1000
        $finish();
   end

endmodule