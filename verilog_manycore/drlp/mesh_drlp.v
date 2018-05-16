//====================================================================
// mesh_drlp.v
// 05/07/2018, hwpeng@uw.com
//====================================================================
// This module connects a neural network accelerator (drlp) to the mesh network

`include "bsg_manycore_packet.vh"

module mesh_drlp #( x_cord_width_p         = "inv"
                            ,y_cord_width_p         = "inv"
                            ,data_width_p           = 32
                            ,addr_width_p           = 3
                            ,packet_width_lp                = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                            ,return_packet_width_lp         = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p)
                            ,bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                           )
   (  input clk_i
    , input reset_i

    // mesh network
    , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

    , input   [x_cord_width_p-1:0]                my_x_i
    , input   [y_cord_width_p-1:0]                my_y_i

    , input   [x_cord_width_p-1:0]                dest_x_i
    , input   [y_cord_width_p-1:0]                dest_y_i

    );


    logic                               in_v_lo                 ;

    logic[data_width_p-1:0]             in_data_lo              ;
    logic[addr_width_p-1:0]             in_addr_lo              ;
    logic                               in_we_lo                ;
    
    ////////////////////////////////////////////////////////////////
    // instantiate the endpoint standard
    ////////////////////////////////////////////////////////////////
    // declare the bsg_manycore_packet sending to the network
   `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);
    bsg_manycore_packet_s       out_packet_li     ;
    logic                       out_v_li          ;
    logic                       out_ready_lo      ;

    logic                       returned_v_lo     ;
    logic[data_width_p-1:0]     returned_data_lo  ;

    logic wr_en, rd_en;

    logic  [ 31:0]          addr_w;
    logic  [ 31:0]          addr_r;
    logic  [ addr_width_p-1:0]          addr;
    logic  [ data_width_p-1:0]          dram_data_w;
    logic  [ data_width_p-1:0]          read_data_r;
    logic  [x_cord_width_p-1:0]         dest_x;
    logic  [y_cord_width_p-1:0]         dest_y;
    logic  [ data_width_p-1:0]		data_w;

    logic                               finish;
    logic 				finish_reg;
    logic  [ data_width_p-1:0]          finish_write;
    logic  [ addr_width_p-1:0]		finish_addr;
    logic  [x_cord_width_p-1:0]		finish_dest_x; 
    logic  [y_cord_width_p-1:0]         finish_dest_y;
    logic                               finish_wait;    

    logic				hand_shaked;

    drlp drlp_inst(
         .i_clk             (clk_i)
        ,.i_rst             (reset_i)

        ,.i_cfg             (in_data_lo)
        ,.i_cfg_addr        (in_addr_lo[2:0])
        ,.i_cfg_wr_en       (in_we_lo&in_v_lo)
        ,.i_cfg_rd_en	    (~in_we_lo&in_v_lo)
        ,.o_cfg		        (read_data_r)

        ,.i_dma_rd_data     (returned_data_lo)
        ,.i_dma_rd_ready    (returned_v_lo)

        ,.i_hand_shaked     (hand_shaked)
        ,.o_dma_wr_addr     (addr_w)
        ,.o_dma_wr_en       (wr_en)
        ,.o_dma_wr_data     (dram_data_w)
        ,.o_dma_rd_en       (rd_en)
        ,.o_dma_rd_addr     (addr_r)
        ,.o_finish          (finish)
        ,.o_finish_write    (finish_write)
        );


    always_ff@(posedge clk_i) begin
	if (reset_i) begin
		finish_wait <= 1'b1;
		finish_reg <= 1'b0;
	end
	else begin
		if(finish) begin
			finish_reg <= 1'b1;
			finish_addr <= {10'b0, finish_write[15:0]};
	    		finish_dest_x <= finish_write[31:24];
    			finish_dest_y <= finish_write[23:16];
			finish_wait <= 0;
		end
		else if(finish_wait) begin
			finish_reg <= 1'b0;
		end
		else if(hand_shaked) begin
			finish_wait <= 1'b1;
		end
	end		
    end

    ////////////////////////////////////////////////////////////////
    // instantiate the endpoint standard

    logic                             in_yumi_li        ;
    logic                             returning_v_r     ;
    bsg_manycore_endpoint_standard  #(
                              .x_cord_width_p        ( x_cord_width_p    )
                             ,.y_cord_width_p        ( y_cord_width_p    )
                             ,.fifo_els_p            ( 4                 )
                             ,.data_width_p          ( data_width_p      )
                             ,.addr_width_p          ( addr_width_p      )
                             ,.max_out_credits_p     ( 16                )
                        )endpoint_example

   ( .clk_i
    ,.reset_i

    // mesh network
    ,.link_sif_i
    ,.link_sif_o
    ,.my_x_i
    ,.my_y_i

    // local incoming data interface
    ,.in_v_o     ( in_v_lo              )
    ,.in_yumi_i  ( in_yumi_li           )
    ,.in_data_o  ( in_data_lo           )
    ,.in_mask_o  (                      )
    ,.in_addr_o  ( in_addr_lo           )
    ,.in_we_o    ( in_we_lo             )

    // The memory read value
    ,.returning_data_i  ( read_data_r   )
    ,.returning_v_i     ( returning_v_r )

    // local outgoing data interface (does not include credits)
    // Tied up all the outgoing signals
    ,.out_v_i           ( out_v_li                )
    ,.out_packet_i      ( out_packet_li           )
    ,.out_ready_o       ( out_ready_lo            )
   // local returned data interface
   // Like the memory interface, processor should always ready be to
   // handle the returned data
    ,.returned_data_r_o(  returned_data_lo     )
    ,.returned_v_r_o   (  returned_v_lo        )


    ,.out_credits_o     (               )
    ,.freeze_r_o        (               )
    ,.reverse_arb_pr_o  (               )
    );

    ////////////////////////////////////////////////////////////////
    // assign the signals to endpoint
    assign  in_yumi_li  =       in_v_lo   ;     //we can always handle the reqeust

    //the returning data is only avaliable when it is a read request
    always_ff@(posedge clk_i)
        if( reset_i ) returning_v_r <= 1'b0;
        else          returning_v_r <= (in_yumi_li & ~in_we_lo);


    ////////////////////////////////////////////////////////////////
    // SEND REQUEST TO THE NETWORK
    ////////////////////////////////////////////////////////////////

    // assign the valid, packet signals
    wire   eOp_n            = (wr_en|finish_reg)? `ePacketOp_remote_store
                                     : `ePacketOp_remote_load   ;
    assign out_v_li    =   wr_en|rd_en|finish_reg;

    assign addr = (finish_reg)?(finish_addr>>2) : ((wr_en)? addr_w[25:0]:addr_r[25:0]);
    assign dest_y = (finish_reg)?finish_dest_y:dest_y_i;
    assign dest_x = (finish_reg)?finish_dest_x:dest_x_i;
    assign data_w = (finish_reg)?1 : dram_data_w;

    assign out_packet_li    = '{
                                 addr           :       addr
                                ,op             :       eOp_n
                                ,op_ex          :       {(data_width_p>>3){1'b1}}
                                ,data           :       data_w
                                ,src_y_cord     :       my_y_i
                                ,src_x_cord     :       my_x_i
                                ,y_cord         :       dest_y
                                ,x_cord         :       dest_x
                                };
     assign   hand_shaked    = out_v_li  & out_ready_lo                 ;
     

endmodule
