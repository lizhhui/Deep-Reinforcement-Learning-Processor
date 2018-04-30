set SCRIPTS_PATH ~/workspace/DRLP/src/scripts/syn

source $SCRIPTS_PATH/0_setup_v.tcl
source $SCRIPTS_PATH/1_read_rtl_v.tcl
source $SCRIPTS_PATH/2_constraints.tcl

# RUN SYNTHESIS
# -------------------------------------------------------------
set_host_options -max_cores 4
# compile_ultra -retime -incremental -gate_clock
compile_ultra -retime

source $SCRIPTS_PATH/3_report.tcl