# CONFIGURATION
# ----------------------------------------------------------------------------
set DESIGN_NAME nn
set DESIGN_LIB  nn
set TSMCPATH    /home/cxchen2/youthRef
set TARGETCELLLIB $TSMCPATH/digtal_front_end/timing_pwr_noise_ccs
set MEMLIB $TSMCPATH/memory/db

# LIBRARY SETUP
# ----------------------------------------------------------------------------
# set target_library "$TARGETCELLLIB/tcbn28hpcbwp7t30p140tt0p9v25c_ccs.db $TARGETCELLLIB/tcbn28hpcbwp7t30p140ulvttt0p9v25c_ccs.db"
# set symbol_library "$TARGETCELLLIB/tcbn28hpcbwp7t30p140tt0p9v25c_ccs.db"
# set link_library "* $TARGETCELLLIB/tcbn28hpcbwp7t30p140tt0p9v25c_ccs.db $TARGETCELLLIB/tcbn28hpcbwp7t30p140ulvttt0p9v25c_ccs.db"

# Create Milkyway library and add the reference library
# set mw_techfile_path $TSMCPATH/Back_End/milkyway/tcbn65gplus_200a/techfiles
# set mw_tech_file $mw_techfile_path/tsmcn65_9lmT2.tf
# set mw_reference_library $TSMCPATH/Back_End/milkyway/tcbn65gplus_200a/frame_only/tcbn65gplus
# create_mw_lib -technology $mw_tech_file -mw_reference_library $mw_reference_library $DESIGN_LIB
# open_mw_lib $DESIGN_LIB

set_units -current mA
set target_library "$TARGETCELLLIB/tcbn28hpcbwp7t30p140hvttt0p9v25c.db"
set symbol_library "$TARGETCELLLIB/tcbn28hpcbwp7t30p140hvttt0p9v25c.db"
set link_library "* $MEMLIB/tsmc28hpc_2prf_256x16_tt0p9v25c.db $MEMLIB/tsmc28hpc_2prf_64x8_tt0p9v25c.db"
 