//====================================================================
// mesh_slave_example.v
// 04/10/2018, shawnless.xie@gmail.com
//====================================================================
// This module connects a standard memory to the mesh network
`include "bsg_manycore_packet.vh"

module mesh_nn_accelerator #( x_cord_width_p         = "inv"
                            ,y_cord_width_p         = "inv"
                            ,data_width_p           = 32
                            ,addr_width_p           = 3
                            ,packet_width_lp                = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                            ,return_packet_width_lp         = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p)
                            // ,bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                           ,bsg_manycore_link_sif_width_lp = 32
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

    localparam mem_depth_lp     = 2 ** addr_width_p ;
    ////////////////////////////////////////////////////////////////
    // A behavior memory with 1 rw port
    // *_lo signals mean 'local output'

    //valid request
    logic                               in_v_lo                 ;

    // logic[data_width_p-1:0]             mem [ mem_depth_lp]     ;
    logic[data_width_p-1:0]             in_data_lo              ;
    logic[addr_width_p-1:0]             in_addr_lo              ;
    logic                               in_we_lo                ;
    // // write
    // always@( posedge clk_i)
    //     if( in_we_lo & in_v_lo )
    //             mem[ in_addr_lo ] <=  in_data_lo;

    // // read
    // logic[data_width_p-1:0]             read_data_r             ;
    // always@( posedge clk_i)
    //     if( ~in_we_lo & in_v_lo)
    //             read_data_r <= mem[ in_addr_lo ] ;
    
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

    logic  [ addr_width_p-1:0]          addr_w;
    logic  [ addr_width_p-1:0]          addr_r;
    logic  [ data_width_p-1:0]          data_r;

    nn_accelerator nn_inst(
        .i_clk(clk_i),
        .i_rst(reset_i),

        .i_cfg(in_data_lo),
        .i_cfg_addr(in_addr_lo),
        .i_cfg_wr_en(~in_we_lo),
        //input i_start(),

        .i_dma_rd_data(returned_data_lo),
        .i_dma_rd_ready(returned_v_lo),

        .o_dma_wr_addr(addr_w),
        .o_dma_wr_en(wr_en),
        .o_dma_wr_data(data_r),
        .o_dma_rd_en(rd_en),
        .o_dma_rd_addr(addr)
        );


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
    wire   eOp_n            = (wr_en)? `ePacketOp_remote_store
                                     : `ePacketOp_remote_load   ;
    assign  out_v_li    =   wr_en|rd_en;
    assign out_packet_li    = '{
                                 addr           :       addr_r
                                ,op             :       eOp_n
                                ,op_ex          :       {(data_width_p>>3){1'b1}}
                                ,data           :       data_r
                                ,src_y_cord     :       my_y_i
                                ,src_x_cord     :       my_x_i
                                ,y_cord         :       dest_y_i
                                ,x_cord         :       dest_x_i
                                };
     // // control the address and data send to the network
     // wire   launch_packet    = out_v_li  & out_ready_lo                 ;
     // wire   incr_data        = launch_packet & ( stat_r == eWriting)   ;
     // wire   incr_addr        = launch_packet                            ;

endmodule
