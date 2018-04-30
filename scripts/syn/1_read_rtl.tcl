# LOAD DESIGN FILES:
# -----------------------------------------------------------------------------
set DESIGN_SRC  ~/workspace/DRLP/src/verilog


read_file $DESIGN_SRC/MAC_column.v
read_file $DESIGN_SRC/wgt_rf.v
read_file $DESIGN_SRC/mult.V      
read_file $DESIGN_SRC/pmem_fake.v
read_file $DESIGN_SRC/wmem_fake.v
read_file $DESIGN_SRC/PE.v

read_file $DESIGN_SRC/nn_cfg.v
read_file $DESIGN_SRC/nn_img_bf.v
read_file $DESIGN_SRC/nn_sld_rf.v
read_file $DESIGN_SRC/nn_fsm.v
read_file $DESIGN_SRC/nn_relu.v
read_file $DESIGN_SRC/nn.v   

current_design $DESIGN_NAME

link