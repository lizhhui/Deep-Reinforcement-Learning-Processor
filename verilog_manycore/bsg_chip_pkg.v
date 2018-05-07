`ifndef BSG_CHIP_PKG_V
`define BSG_CHIP_PKG_V

package bsg_chip_pkg;
   // 180: 1024x32 --> 278K um^2  -> 270 um^2 per word
   //      2048x32 --> 478K um^2  -> 233 um^2 per word (16 percent more efficient)

   // for both bsg_test_node_master and bsg_test_node_client
   parameter bank_size_gp          = 1024; // in words
   parameter bank_num_gp           = 1;    // number of banks

//   parameter imem_size_gp          = 2048; // in words (e.g. instructions)
   parameter imem_size_gp          = 1024; // in words (e.g. instructions)
   parameter addr_width_gp         = 26;   // in words,(64M WORDS = 256M BYTES = 1G BITS)
   parameter data_width_gp         = 32;
   parameter hetero_type_vec_gp    = 0;
   parameter fsb_remote_credits_gp = 128;

   // 16 is the smallest because of credit decimation
   // parameter fsb_remote_credits_gp = 16;

   parameter num_tiles_x_gp        = 3;
   parameter num_tiles_y_gp        = 1;

   // for bsg_test_node_master
   parameter tile_id_ptr_gp  = -1;
   parameter max_cycles_gp   = 500000;

   parameter mem_size_gp     = (bank_num_gp*bank_size_gp+imem_size_gp)*4; // fixme: calc from bank size and num?

   parameter fsb_x_cord_gp      = 0;

   //dram controller
   parameter dram_ctrl_x_cord_gp = 1;
   parameter dram_ctrl_dwidth_gp = 128 ;
   parameter dram_ctrl_awidth_gp = addr_width_gp + 2;

   parameter dram_dfi_width_gp   = 32 ; //for x16 dram
   parameter dram_ba_width_gp    = 2  ; //for x16 1Mb dram
   parameter dram_addr_width_gp  = 14 ; //for x16 1Mb dram

   //FSB configuration
   parameter fsb_mesh_node_idx          =  0;
   parameter fsb_outspace_node_idx      =  1;

endpackage

`endif
