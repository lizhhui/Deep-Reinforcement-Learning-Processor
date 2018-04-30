# Define clocking constraints
# ----------------------------------------------------------------------------
create_clock -name "i_clk" -period 2.5 -waveform {0 1.25} [get_ports i_clk]
# create_generated_clock -divide_by 2 -source i_clk [get_pins ]
set_clock_uncertainty -setup 0.3 i_clk
set_clock_uncertainty -hold 0.1 i_clk
set_clock_transition 0.1 [get_clocks]
set_input_delay 0.45 -clock i_clk [remove_from_collection [all_inputs] [get_ports i_clk]]
set_output_delay 0.1 -clock i_clk [all_outputs]
set_fix_hold {i_clk}


# create_generated_clock -divide_by 2 -source i_clk [get_pins nslc0/i_clk]
# create_generated_clock -divide_by 2 -source i_clk [get_ports i_insch_clk_nslc]

set_timing_derate -early 0.95
set_timing_derate -late 1.05

# set_multicycle_path 2 -setup -from "i_insch_sldmod_3b*"
