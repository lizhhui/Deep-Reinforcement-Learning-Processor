`include "bsg_padmapping.v"

`include "bsg_iopad_macros.v"

module bsg_chip

   import bsg_tag_pkg::bsg_tag_s;
   import bsg_chip_pkg::*;

// pull in BSG Two's top-level module signature, and the definition of the pads
`include "bsg_pinout.v"

`include "bsg_iopads.v"

  // MBT: copied directly from bsg_two_loopback_clk_gen
  // as a reminder that these must now be set by bsg_two
  // pinouts.

   // disable sdi_tkn_ex_o[0..2]
   `BSG_IO_TIEHI_VEC(sdi_tkn_ex_oen_int,3)

   // enable sdi_tkn_ex[3] (this pin is used for clock inspection)
   `BSG_IO_TIELO_VEC_ONE(sdi_tkn_ex_oen_int,3)

   // disable sdo_sclk_ex[0..3]
   `BSG_IO_TIEHI_VEC(sdo_sclk_ex_oen_int,4)

   // disable misc_L_3_o
   `BSG_IO_TIEHI(misc_L_3_oen_int)

   // disable misc_R_3_o
   `BSG_IO_TIEHI(misc_R_3_oen_int)

   // disable sdo_A_data_8_o
   `BSG_IO_TIEHI(sdo_A_data_8_oen_int)

   // disable sdo_C_data_8_o
   `BSG_IO_TIEHI(sdo_C_data_8_oen_int)

   `BSG_IO_TIEHI(JTAG_TDO_oen_int)

// **********************************************************************
// BEGIN BSG CLK GENS
//

   logic [1:0]  clk_gen_iom_sel;
   logic [1:0]  clk_gen_core_sel;
   logic        clk_gen_iom_async_reset;
   logic        clk_gen_core_async_reset;

   // all of these should be shielded
   assign clk_gen_iom_sel[0]  = misc_L_6_i_int;
   assign clk_gen_iom_sel[1]  = misc_L_7_i_int;
   assign clk_gen_core_sel[0] = misc_R_6_i_int;
   assign clk_gen_core_sel[1] = misc_R_7_i_int;
   assign clk_gen_iom_async_reset  = sdo_tkn_ex_i_int[2];
   assign clk_gen_core_async_reset = JTAG_TRST_i_int;

`include "bsg_tag.vh"

   localparam bsg_tag_els_lp  = 4;
   localparam bsg_ds_width_lp = 8;
   localparam bsg_num_adgs_lp = 1;

   `declare_bsg_clk_gen_osc_tag_payload_s(bsg_num_adgs_lp)
   `declare_bsg_clk_gen_ds_tag_payload_s(bsg_ds_width_lp)

   localparam bsg_tag_max_payload_length_lp
     = `BSG_MAX($bits(bsg_clk_gen_osc_tag_payload_s),$bits(bsg_clk_gen_ds_tag_payload_s));

   localparam lg_bsg_tag_max_payload_length_lp = $clog2(bsg_tag_max_payload_length_lp+1);

   bsg_tag_s [bsg_tag_els_lp-1:0] tags;

   bsg_tag_master #(.els_p(bsg_tag_els_lp)
                    ,.lg_width_p(lg_bsg_tag_max_payload_length_lp)
                    ) btm
     (.clk_i       (JTAG_TCK_i_int)
      ,.data_i     (JTAG_TDI_i_int)
      ,.en_i       (JTAG_TMS_i_int) // shield
      ,.clients_r_o(tags)
      );

   // Clock signals coming out of clock generators
   logic core_clk_lo;
   logic iom_clk_lo;

   // core clock generator (bsg_tag ID's 0 and 1)
   bsg_clk_gen #(.downsample_width_p(bsg_ds_width_lp)
                 ,.num_adgs_p(bsg_num_adgs_lp)
                 ) clk_gen_core_inst
     (.bsg_osc_tag_i(tags[0])
      ,.bsg_ds_tag_i(tags[1])
      ,.async_osc_reset_i(clk_gen_core_async_reset)
      ,.ext_clk_i(misc_L_4_i_int)  // probably should be identified as clock
      ,.select_i (clk_gen_core_sel)
      ,.clk_o    (core_clk_lo)
      );

   // io clock generator (bsg_tag ID's 2 and 3)
   bsg_clk_gen #(.downsample_width_p(bsg_ds_width_lp)
                 ,.num_adgs_p(bsg_num_adgs_lp)
                 ) clk_gen_iom_inst
     (.bsg_osc_tag_i(tags[2])
      ,.bsg_ds_tag_i(tags[3])
      ,.async_osc_reset_i(clk_gen_iom_async_reset)
      ,.ext_clk_i(PLL_CLK_i_int) // probably should be identified as clock
      ,.select_i (clk_gen_iom_sel)
      ,.clk_o    (iom_clk_lo)
      );

   // Route the clock signals off chip to see life in the chip!
   logic [1:0]  clk_out_sel;
   logic        clk_out;

   assign clk_out_sel[0] = sdo_tkn_ex_i_int[3]; // shield
   assign clk_out_sel[1] = misc_R_5_i_int;      // shield
   assign sdi_tkn_ex_o_int[3] = clk_out;        // shield

   bsg_mux #(.width_p    (1)
             ,.els_p     (4)
             ,.balanced_p(1)
             ,.harden_p  (1)
             ) clk_out_mux_inst
     // being able to not output clock is a good idea
     // for noise; can also be used to see if chip is alive

     (.data_i({1'b1,1'b0,iom_clk_lo,core_clk_lo})
      ,.sel_i(clk_out_sel)
      ,.data_o(clk_out)
      );

// **********************************************************************
// BEGIN BSG GUTS
//
// Put this last because the previous lines define the wires that are inputs.
//
  //----------------------------------------------------------------
  //  Memory contoller
  wire                               dfi_clk_li    ;
  wire                               dfi_clk_2x_li ;

  wire  [(dram_dfi_width_gp>>4)-1:0] dm_oe_n_lo    ;
  wire  [(dram_dfi_width_gp>>4)-1:0] dm_o_lo       ;
  wire  [(dram_dfi_width_gp>>4)-1:0] dqs_p_oe_n_lo ;
  wire  [(dram_dfi_width_gp>>4)-1:0] dqs_p_o_lo    ;
  wire  [(dram_dfi_width_gp>>4)-1:0] dqs_p_i_li    ;
  wire  [(dram_dfi_width_gp>>4)-1:0] dqs_n_oe_n_lo ;
  wire  [(dram_dfi_width_gp>>4)-1:0] dqs_n_o_lo    ;
  wire  [(dram_dfi_width_gp>>4)-1:0] dqs_n_i_li    ;

  wire  [(dram_dfi_width_gp>>1)-1:0] dq_oe_n_lo    ;
  wire  [(dram_dfi_width_gp>>1)-1:0] dq_o_lo       ;
  wire  [(dram_dfi_width_gp>>1)-1:0] dq_i_li       ;

  wire                               ddr_ck_p_lo   ;
  wire                               ddr_ck_n_lo   ;
  wire                               ddr_cke_lo    ;
  wire                        [2:0]  ddr_ba_lo     ; //this is the maximum width.
  wire                       [15:0]  ddr_addr_lo   ; //this is the maximum width.
  wire                               ddr_cs_n_lo   ;
  wire                               ddr_ras_n_lo  ;
  wire                               ddr_cas_n_lo  ;
  wire                               ddr_we_n_lo   ;
  wire                               ddr_reset_n_lo;
  wire                               ddr_odt_lo    ;


   localparam num_channels_lp = 1;
   wire [7:0] sdi_data_i_int_packed [num_channels_lp-1:0];
   wire [7:0] sdo_data_o_int_packed [num_channels_lp-1:0];

   assign sdi_data_i_int_packed[0] = sdi_A_data_i_int           ;
   assign sdo_A_data_o_int         = sdo_data_o_int_packed[0]   ;

   bsg_chip_guts #(.uniqueness_p(1)
              ,.enabled_at_start_vec_p(1'b1)
              ,.num_channels_p( num_channels_lp )
              ) g
     (  .core_clk_i           (core_clk_lo    )
       ,.async_reset_i        (reset_i_int    )
       ,.io_master_clk_i      (iom_clk_lo     )
      // flip B and C input for PD
       ,.io_clk_tline_i       ( sdi_sclk_i_int[num_channels_lp-1:0]  )
       ,.io_valid_tline_i     ( sdi_ncmd_i_int[num_channels_lp-1:0]  )
       ,.io_data_tline_i      ( sdi_data_i_int_packed  )
       ,.io_token_clk_tline_o ( sdi_token_o_int[num_channels_lp-1:0] )
       ,.im_clk_tline_o       ( sdo_sclk_o_int[num_channels_lp-1:0] )
       ,.im_valid_tline_o     ( sdo_ncmd_o_int[num_channels_lp-1:0] )
       ,.im_data_tline_o      ( sdo_data_o_int_packed  )
       ,.token_clk_tline_i    ( sdo_token_i_int[num_channels_lp-1:0])
       ,.im_slave_reset_tline_r_o()             // unused by ASIC
       ,.core_reset_o            ()             // post calibration reset

       // DDR interface signals
       ,.ddr_ck_p   (  ddr_ck_p_lo   )
       ,.ddr_ck_n   (  ddr_ck_n_lo   )
       ,.ddr_cke    (  ddr_cke_lo    )
       ,.ddr_ba     (  ddr_ba_lo     )
       ,.ddr_addr   (  ddr_addr_lo   )
       ,.ddr_cs_n   (  ddr_cs_n_lo   )
       ,.ddr_ras_n  (  ddr_ras_n_lo  )
       ,.ddr_cas_n  (  ddr_cas_n_lo  )
       ,.ddr_we_n   (  ddr_we_n_lo   )
       ,.ddr_reset_n(  ddr_reset_n_lo)  //TODO
       ,.ddr_odt    (  ddr_odt_lo    )  //TODO

       ,.dm_oe_n    (  dm_oe_n_lo    )
       ,.dm_o       (  dm_o_lo       )
       ,.dqs_p_oe_n (  dqs_p_oe_n_lo )
       ,.dqs_p_o    (  dqs_p_o_lo    )
       ,.dqs_p_i    (  dqs_p_i_li    )
       ,.dqs_n_oe_n (  dqs_n_oe_n_lo )
       ,.dqs_n_o    (  dqs_n_o_lo    )
       ,.dqs_n_i    (  dqs_n_i_li    )
       ,.dq_oe_n    (  dq_oe_n_lo    )
       ,.dq_o       (  dq_o_lo       )
       ,.dq_i       (  dq_i_li       )

       ,.dfi_clk_2x      ( dfi_clk_2x_li     )
       ,.dfi_clk         ( dfi_clk_li        )
       );

  //----------------------------------------------------------------
  // ______ _______   ____  __ ______
  //|  ____|_   _\ \ / /  \/  |  ____|
  //| |__    | |  \ V /| \  / | |__
  //|  __|   | |   > < | |\/| |  __|
  //| |     _| |_ / . \| |  | | |____
  //|_|    |_____/_/ \_\_|  |_|______|
  //----------------------------------------------------------------
  // Memory moduel, simulation only

  // Emulate the bi-directional pins for DM, DQ and DQS
  wire  [(dram_dfi_width_gp>>4)-1:0] dm_pin       ;
  wire  [(dram_dfi_width_gp>>4)-1:0] dqs_p_pin    ;
  wire  [(dram_dfi_width_gp>>4)-1:0] dqs_n_pin    ; //used for DDR2/3 only
  wire  [(dram_dfi_width_gp>>1)-1:0] dq_pin       ;

  for(i=0;  i<(dram_dfi_width_gp>>4);  i=i+1) begin: dqs_dm_pin_ass
        assign dm_pin   [i]     = dm_oe_n_lo      [i] ? 1'bz: dm_o_lo   [i];
        assign dqs_p_pin[i]     = dqs_p_oe_n_lo   [i] ? 1'bz: dqs_p_o_lo[i];
        assign dqs_n_pin[i]     = dqs_n_oe_n_lo   [i] ? 1'bz: dqs_n_o_lo[i];

        assign dqs_p_i_li[i]    = dqs_p_pin     [i];
        assign dqs_n_i_li[i]    = dqs_n_pin     [i];
  end

  for(i=0; i<(dram_dfi_width_gp>>1);  i=i+1) begin: dq_pad_pin_ass
    assign dq_pin  [i] = dq_oe_n_lo[i]? 1'bz: dq_o_lo[i];
    assign dq_i_li [i] = dq_pin    [i] ;
  end

  //generate the clock for the DFI
  bsg_nonsynth_clock_gen #(.cycle_time_p( `CORE_0_PERIOD/2 ))  dfi_gen_clk_2x  (.o( dfi_clk_2x_li ));
  bsg_counter_clock_downsample #(.width_p(2)) dfi_clk_ds
    (.clk_i( dfi_clk_2x_li)
    ,.reset_i ( reset_i_int)
    ,.val_i( 2'b0 )
    ,.clk_r_o( dfi_clk_li )
    );

  // Now we can instantiate the DRAM model
  mobile_ddr  nonsynth_1024Mb_dram_model(
    .Clk        ( ddr_ck_p_lo   )
   ,.Clk_n      ( ddr_ck_n_lo   )
   ,.Cke        ( ddr_cke_lo    )
   ,.Cs_n       ( ddr_cs_n_lo   )
   ,.Ras_n      ( ddr_ras_n_lo  )
   ,.Cas_n      ( ddr_cas_n_lo  )
   ,.We_n       ( ddr_we_n_lo   )
   ,.Addr       ( ddr_addr_lo[dram_addr_width_gp-1:0] )
   ,.Ba         ( ddr_ba_lo  [dram_ba_width_gp-1:0]   )
   ,.Dq         ( dq_pin        )
   ,.Dqs        ( dqs_p_pin     )
   ,.Dm         ( dm_pin        )
  );

`include "bsg_pinout_end.v"
