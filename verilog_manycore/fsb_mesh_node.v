`include "bsg_manycore_packet.vh"

//
// this instantiates a bsg_manycore array and also
// a converter between the south side of the manycore array
// and the FSB network.

module  fsb_mesh_node
   import bsg_noc_pkg::*; // {P=0, W, E, N, S}
   import bsg_fsb_pkg::*;
   import bsg_chip_pkg::*;
   import bsg_dram_ctrl_pkg::*;
  #(parameter ring_width_p="inv"
    , parameter master_p="inv"
    , parameter master_id_p="inv"
    , parameter client_id_p="inv"
    )

  (  input clk_i
   , input reset_i

   // control
   , input en_i   // FIXME unused

   // input channel
   , input  v_i
   , input [ring_width_p-1:0] data_i
   , output ready_o

   // output channel
   , output v_o
   , output [ring_width_p-1:0] data_o
   , input yumi_i   // late

   //----------------------------------------------------------------
   //  Memory contoller
   , input                              dfi_clk
   , input                              dfi_clk_2x

   , output[(dram_dfi_width_gp>>4)-1:0] dm_oe_n
   , output[(dram_dfi_width_gp>>4)-1:0] dm_o
   , output[(dram_dfi_width_gp>>4)-1:0] dqs_p_oe_n
   , output[(dram_dfi_width_gp>>4)-1:0] dqs_p_o
   , input [(dram_dfi_width_gp>>4)-1:0] dqs_p_i
   , output[(dram_dfi_width_gp>>4)-1:0] dqs_n_oe_n
   , output[(dram_dfi_width_gp>>4)-1:0] dqs_n_o
   , input [(dram_dfi_width_gp>>4)-1:0] dqs_n_i

   , output[(dram_dfi_width_gp>>1)-1:0] dq_oe_n
   , output[(dram_dfi_width_gp>>1)-1:0] dq_o
   , input [(dram_dfi_width_gp>>1)-1:0] dq_i

   , output                             ddr_ck_p
   , output                             ddr_ck_n
   , output                             ddr_cke
   , output                      [2:0]  ddr_ba      //this is the maximum width.
   , output                     [15:0]  ddr_addr    //this is the maximum width.
   , output                             ddr_cs_n
   , output                             ddr_ras_n
   , output                             ddr_cas_n
   , output                             ddr_we_n
   , output                             ddr_reset_n
   , output                             ddr_odt
   );
   localparam dest_id_lp         = master_id_p;

   // shared with client; factor
   localparam bank_size_lp       = bsg_chip_pkg::bank_size_gp;
   localparam bank_num_lp        = bsg_chip_pkg::bank_num_gp;
   localparam imem_size_lp       = bsg_chip_pkg::imem_size_gp;

   localparam addr_width_lp      = bsg_chip_pkg::addr_width_gp;
   localparam data_width_lp      = bsg_chip_pkg::data_width_gp;
   localparam hetero_type_vec_lp = bsg_chip_pkg::hetero_type_vec_gp;
   localparam remote_credits_lp  = bsg_chip_pkg::fsb_remote_credits_gp;

   localparam num_tiles_x_lp     = bsg_chip_pkg::num_tiles_x_gp;
   localparam num_tiles_y_lp     = bsg_chip_pkg::num_tiles_y_gp;


   localparam debug_lp           = 0;

   localparam x_cord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_lp);

   // extra row for I/O at bottom of chip
   localparam y_cord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_lp+1);

  `declare_bsg_manycore_link_sif_s(addr_width_lp,data_width_lp,x_cord_width_lp,y_cord_width_lp);

   // code arrange N to S as these repeater blocks are placed on the chip
   logic [ring_width_p-1:0] data_i_inv, data_i_rep, data_o_inv, data_o_prerep;

   bsg_inv #(.width_p(ring_width_p)
             ,.harden_p(1)
             ,.vertical_p(0)
             ) data_i_hi
   (.i(data_i)
    ,.o(data_i_inv)
    );

   bsg_inv #(.width_p(ring_width_p)
             ,.harden_p(1)
             ,.vertical_p(0)
             ) data_i_mid
   (.i(data_i_inv)
    ,.o(data_i_rep)
    );

   bsg_inv #(.width_p(ring_width_p)
             ,.harden_p(1)
             ,.vertical_p(0)
             ) data_o_mid
   (
    .o(data_o)
    ,.i(data_o_inv)
    );

   bsg_inv #(.width_p(ring_width_p)
             ,.harden_p(1)
             ,.vertical_p(0)
             ) data_o_lo
   (
    .o(data_o_inv)
    ,.i(data_o_prerep)
    );


   //----------------------------------------------------------------
   // Manycore instantion
   // horizontal -- {E,W}
   bsg_manycore_link_sif_s [E:W][num_tiles_y_lp-1:0]  hor_link_sif_li;
   bsg_manycore_link_sif_s [E:W][num_tiles_y_lp-1:0]  hor_link_sif_lo;

   // vertical -- {S,N}
   bsg_manycore_link_sif_s [S:N][num_tiles_x_lp-1:0]  ver_link_sif_li;
   bsg_manycore_link_sif_s [S:N][num_tiles_x_lp-1:0]  ver_link_sif_lo;

   bsg_manycore #(.bank_size_p       (bank_size_lp) // all in words
                  ,.imem_size_p      (imem_size_lp) // all in words
                  ,.num_banks_p      (bank_num_lp)
                  ,.num_tiles_x_p    (num_tiles_x_lp)
                  ,.num_tiles_y_p    (num_tiles_y_lp)
                  ,.extra_io_rows_p  (1)

                  ,.stub_w_p     ({num_tiles_y_lp{1'b1}})
                  ,.stub_e_p     ({num_tiles_y_lp{1'b1}})
                  ,.stub_n_p     ({num_tiles_x_lp{1'b1}})

                  //  (0)= FSB
                  //  (1)= DRAM
                  ,.stub_s_p     ({ {(num_tiles_x_lp-2){1'b1}}, 2'b0})

                  ,.hetero_type_vec_p(hetero_type_vec_lp)
                  ,.debug_p          (debug_lp)
                  ,.addr_width_p     (addr_width_lp)
                  ,.data_width_p     (data_width_lp)

		  // 0 1
		  // 2 3   (1000 1000)
		  // 4 5   (0100 0100)
		  // 6 7
		  // 8 9
		  //                          9    8    7    6    5   4     3    2    1    0
		  ,.repeater_output_p ( ((num_tiles_y_lp == 5)
					&& (num_tiles_x_lp == 2))
				       ? 40'b0000_0000_0000_0000_0100_0100_1000_1000_0000_0000      // snew
				       : 0)
                  ) bm
     (.clk_i
      ,.reset_i

      // these are actually stubbed out and ignored
      ,.hor_link_sif_i(hor_link_sif_li)
      ,.hor_link_sif_o(hor_link_sif_lo)

      // north side is stubbed out and ignored
      ,.ver_link_sif_i(ver_link_sif_li)
      ,.ver_link_sif_o(ver_link_sif_lo)
      );

   //----------------------------------------------------------------
   //  FSB instantion
   //
   // the FSB network uses the bsg_fsb_pkt_client_data_t format
   // (see bsg_fsb_pkg.v) which adds up to 80 bits. Currently it is:
   //
   //  4 bits   1 bit  75 bits
   //
   //  destid   cmd     bsg_fsb_pkt_client_data_t
   //
   //  The 75 bits are split into up to two pieces:
   //
   //  <tag> <bsg_manycore_packet_s>
   //
   //  The tag encodes the channel number. For every link
   //  that is exposed to the outside world, there are
   //  two channels (one for credits and one for return).
   //

   bsg_manycore_link_sif_s links_sif_li, links_sif_lo;

   bsg_manycore_links_to_fsb
     #(.ring_width_p     (ring_width_p     )
       ,.dest_id_p       (dest_id_lp       )
       ,.num_links_p     ( 1               )
       ,.addr_width_p    (addr_width_lp    )
       ,.data_width_p    (data_width_lp    )
       ,.x_cord_width_p  (x_cord_width_lp  )
       ,.y_cord_width_p  (y_cord_width_lp  )
       ,.remote_credits_p(remote_credits_lp)

       // max bandwidth of incoming packets is 1 every 2.5 cycles
       // so a pseudo 1r1w large fifo, which can do a packet every 2 cycles
       // is appropriate
       ,.use_pseudo_large_fifo_p(1)
       ) l2f
       (.clk_i
        ,.reset_i

        // later we may change this to be the west side
        // changes must be mirrored in master node
        ,.links_sif_i(ver_link_sif_lo[S][fsb_x_cord_gp])
        ,.links_sif_o(ver_link_sif_li[S][fsb_x_cord_gp])

        ,.v_i
        ,.data_i(data_i_rep)
        ,.ready_o

        ,.v_o
        ,.data_o(data_o_prerep)
        ,.yumi_i
        );
   //----------------------------------------------------------------
   //  Memory controller adapter
    bsg_dram_ctrl_if #( .addr_width_p ( dram_ctrl_awidth_gp )
                       ,.data_width_p ( dram_ctrl_dwidth_gp )
                      ) dram_if(
                      //synopsys translate_off
                      .clk_i
                      //synopsys translate_on
                      );

    bsg_manycore_link_to_dram_ctrl
    #(  .addr_width_p          ( addr_width_lp  )
      , .data_width_p          ( data_width_lp  )
      , .x_cord_width_p        ( x_cord_width_lp)
      , .y_cord_width_p        ( y_cord_width_lp)
      , .dram_ctrl_dwidth_p    ( dram_ctrl_dwidth_gp)
      , .dram_ctrl_awidth_p    ( dram_ctrl_awidth_gp)
    )dram_ctrl
  (
     .clk_i
   , .reset_i

   , .my_x_i    ( x_cord_width_lp'(dram_ctrl_x_cord_gp)    )
   , .my_y_i    ( y_cord_width_lp'(num_tiles_y_lp     )    )

   //input from the manycore
   , .link_sif_i( ver_link_sif_lo[S][ dram_ctrl_x_cord_gp ] )
   , .link_sif_o( ver_link_sif_li[S][ dram_ctrl_x_cord_gp ] )

   //Interface with DRAM controller
   , .dram_ctrl_if( dram_if )
   );

   dmc #
  (.UI_ADDR_WIDTH       ( dram_ctrl_awidth_gp )
  ,.UI_DATA_WIDTH       ( dram_ctrl_dwidth_gp )
  ,.DFI_DATA_WIDTH      ( dram_dfi_width_gp   )
  ) lpddr1_ctrl
  // Global asynchronous reset
  // TODO: This is active low !!!!
  (.sys_rst             ( ~reset_i               )
  // User interface signals
  // this is the SHORT address !!!!
  ,.app_addr            ( (dram_if.app_addr>>1)     )
  ,.app_cmd             ( dram_if.app_cmd           )
  ,.app_en              ( dram_if.app_en            )
  ,.app_rdy             ( dram_if.app_rdy           )
  ,.app_wdf_wren        ( dram_if.app_wdf_wren      )
  ,.app_wdf_data        ( dram_if.app_wdf_data      )
  ,.app_wdf_mask        ( dram_if.app_wdf_mask      )
  ,.app_wdf_end         ( dram_if.app_wdf_end       )
  ,.app_wdf_rdy         ( dram_if.app_wdf_rdy       )
  ,.app_rd_data_valid   ( dram_if.app_rd_data_valid )
  ,.app_rd_data         ( dram_if.app_rd_data       )
  ,.app_rd_data_end     ( dram_if.app_rd_data_end   )
  ,.app_ref_req         ( dram_if.app_ref_req       )
  ,.app_ref_ack         ( dram_if.app_ref_ack       )
  ,.app_zq_req          ( dram_if.app_zq_req        )
  ,.app_zq_ack          ( dram_if.app_zq_ack        )
  ,.app_sr_req          ( dram_if.app_sr_req        )
  ,.app_sr_active       ( dram_if.app_sr_ack        ) //TODO
  // Status signal
  ,.init_calib_complete ( dram_if.init_calib_complete)

  // DDR interface signals
  ,.ddr_ck_p
  ,.ddr_ck_n
  ,.ddr_cke
  ,.ddr_ba
  ,.ddr_addr
  ,.ddr_cs_n
  ,.ddr_ras_n
  ,.ddr_cas_n
  ,.ddr_we_n
  ,.ddr_reset_n //TODO
  ,.ddr_odt     //TODO

  ,.dm_oe_n
  ,.dm_o
  ,.dqs_p_oe_n
  ,.dqs_p_o
  ,.dqs_p_i
  ,.dqs_n_oe_n
  ,.dqs_n_o
  ,.dqs_n_i
  ,.dq_oe_n
  ,.dq_o
  ,.dq_i

  ,.ui_clk          ( clk_i    )
  ,.ui_clk_sync_rst (          ) //TODO
  ,.dfi_clk_2x
  ,.dfi_clk
  ,.device_temp     (          )
);
    
  //----------------------------------------------------------------
  //  neural network accelerator
    mesh_drlp
    #(  .x_cord_width_p                 (x_cord_width_lp)
      , .y_cord_width_p                 (y_cord_width_lp)
      , .data_width_p                   (data_width_lp)
      , .addr_width_p                   (addr_width_lp)
      , .packet_width_lp                ()
      , .return_packet_width_lp         ()
      , .bsg_manycore_link_sif_width_lp ()
     )drlp
    (
        .clk_i
      , .reset_i

      //input from the manycore
      , .link_sif_i(  )
      , .link_sif_o(  )

      , .my_x_i    (     )
      , .my_y_i    (     )

      , .dest_x_i  (     )

      , .dest_y_i  (     )
      );


endmodule

