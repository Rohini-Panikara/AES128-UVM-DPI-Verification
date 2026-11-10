# ============================================================
# run.do  -  UVM verification of the AES-128 C design (DPI-C)
# QuestaSim 10.7c + UVM-1.1d   (same setup as the SRAM project)
#
# In QuestaSim, inside this folder:   do run.do
# Change +UVM_TESTNAME below to run another test:
#     testcase   - full regression (KAT + random + constrained + targeted)
#     testcase1  - known-answer tests only
#     testcase2  - pure random only            (coverage holes)
#     testcase3  - random + constrained-random
#     testcase4  - random + targeted sequences (coverage closure)
# ============================================================
catch {quit -sim}
if {[file exists work]} { vdel -all -lib work }
vlib work

# 1. UVM testbench + DUT wrapper (everything is `included by aes_top_tb.sv)
vlog -sv +acc +cover +incdir+C:/questasim64_10.7c/verilog_src/uvm-1.1d/src aes_top_tb.sv

# 2. AES-128 C design is loaded as a DLL (aes_dpi.dll, built once with MSYS2 gcc):
#      cd <repo>/uvm_tb
#      gcc -shared -std=gnu99 -static-libgcc -I/c/questasim64_10.7c/include -I../c_model \
#          -o aes_dpi.dll ../c_model/aes128_ref.c ../c_model/aes128_dpi.c
if {![file exists aes_dpi.dll]} {
    echo "*** aes_dpi.dll not found - build it with MSYS2 gcc first (see run.do step 2) ***"
    abort
}

# 3. Simulate
vsim work.top -coverage -assertdebug -voptargs=+acc \
     -sv_lib C:/questasim64_10.7c/uvm-1.1d/win64/uvm_dpi -sv_lib aes_dpi \
     +UVM_TESTNAME=testcase +UVM_VERBOSITY=UVM_LOW -l run.log

add wave -radix hex /top/clk /top/rst_n /top/inter/*
add wave -radix hex /top/dut/state /top/dut/cycle_cnt
# Assertions (bound instance u_sva inside the DUT): pass/fail markers in the wave
add wave -divider ASSERTIONS
foreach a {A_RESET A_START_PULSE A_START_IDLE A_INPUTS_STABLE A_LATENCY A_DONE_PULSE A_NO_X A_ROUND_TRIP A_START_TO_ENC A_ENC_TO_DEC A_DEC_TO_DONE A_DONE_TO_IDLE A_CNT_RANGE A_CT_BEFORE_DEC A_BUSY C_FULL_OPERATION} {
    if {[catch {add wave /top/dut/u_sva/$a}]} { echo "note: could not add $a to the wave" }
}
# Assertion window: pass / fail count of every assertion
view assertions
run -all

# 4. Coverage report (functional coverage + assertions)
coverage report -details -cvg -assert -file coverage_report.txt


