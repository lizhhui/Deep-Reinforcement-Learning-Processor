# WRITEOUT RESULTS
# ---------------------------------------------------------------------
file mkdir design_files
file mkdir reports
# Reports
report_power -hierarchy > reports/$DESIGN_NAME.hierarchy.power
report_power > reports/$DESIGN_NAME.power
report_area > reports/$DESIGN_NAME.area
report_timing > reports/$DESIGN_NAME.timing
report_constraint -verbose > reports/$DESIGN_NAME.constraint
report_constraint -all_violators > reports/$DESIGN_NAME.violation
# Milkyway DB and DDC are alternate formats you can use to shuttle designs around
# (may be faster for very large designs)
write -h $DESIGN_NAME -output ./design_files/$DESIGN_NAME.db
write_file -format ddc -hierarchy -output ./design_files/$DESIGN_NAME.ddc
# Delays in SDF format for Verilog simulation
write_sdf -context verilog -version 1.0 ./design_files/$DESIGN_NAME.syn.sdf
# The post-syn Verilog netlist
write -h -f verilog $DESIGN_NAME -output ./design_files/$DESIGN_NAME.syn.v -pg
# Constraints in SDC format, for APR
write_sdc ./design_files/$DESIGN_NAME.sdc