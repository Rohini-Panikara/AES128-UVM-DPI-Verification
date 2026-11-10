// ============================================================
// aes_top_tb.sv  -  top module: includes the whole UVM testbench
// (same structure as the SRAM sequence_item_tb.sv)
//
// DUT       : aes_c_dut  (AES-128 C design called through DPI-C)
// Reference : aes_ref_model (independent SystemVerilog AES)
// ============================================================
`include "uvm_macros.svh"
import uvm_pkg::*;

`include "aes_ref_model.sv"
`include "aes_seq_item.sv"
`include "aes_sequence1.sv"
`include "aes_sequence2.sv"
`include "aes_sequence3.sv"
`include "aes_sequence4.sv"
`include "aes_sequencer.sv"
`include "aes_driver.sv"
`include "aes_monitor1.sv"
`include "aes_active_agent.sv"
`include "aes_monitor2.sv"
`include "aes_passive_agent.sv"
`include "aes_scoreboard.sv"
`include "aes_subscriber.sv"
`include "aes_environment.sv"
`include "aes_test.sv"
`include "aes_assertion_module.sv"
`include "aes_interface.sv"
`include "aes_c_dut.sv"

module top;

    bit clk;
    bit rst_n;

    always #5 clk = ~clk;                       // 100 MHz

    aes_interface inter(clk, rst_n);

    // ---------------- DUT: C design wrapped as a clocked block ----------------
    aes_c_dut dut (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .start                  (inter.start),
        .i_key                  (inter.key),
        .i_Plain_Text           (inter.plain_text),
        .o_Cipher_Text          (inter.cipher_text),
        .o_Recovered_Plain_Text (inter.recovered_text),
        .o_done                 (inter.done),
        .o_busy                 ()
    );

    // ---------------- Assertions (bound into the DUT) ----------------
    bind aes_c_dut aes_assertion_module #(.ENC_CYCLES(ENC_CYCLES), .DEC_CYCLES(DEC_CYCLES)) u_sva (
        .clk(clk), .rst_n(rst_n), .start(start), .i_key(i_key), .i_Plain_Text(i_Plain_Text),
        .o_Cipher_Text(o_Cipher_Text), .o_Recovered_Plain_Text(o_Recovered_Plain_Text),
        .o_done(o_done), .o_busy(o_busy), .state(state), .cycle_cnt(cycle_cnt));

    // ---------------- Reset + config ----------------
    initial begin
        uvm_config_db#(virtual aes_interface)::set(null, "*", "aes_interface", inter);
        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
    end

    initial begin
        run_test("testcase");                   // override with +UVM_TESTNAME=testcase2 etc.
    end

endmodule
