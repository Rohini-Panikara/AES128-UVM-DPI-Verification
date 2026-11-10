// ============================================================
// aes_assertion_module.sv
// SystemVerilog Assertions for the AES-128 C design wrapper
// (aes_c_dut). Bound with "bind" from top.
//
//   Protocol properties     : reset, start/done handshake,
//                             input stability, latency, no X/Z
//   Architectural properties: FSM sequencing (IDLE->ENC->DEC->DONE),
//                             cycle counter range, encryption result
//                             available before decryption ends
// ============================================================
module aes_assertion_module #(
    parameter int ENC_CYCLES = 11,
    parameter int DEC_CYCLES = 11
)(
    input logic         clk,
    input logic         rst_n,
    input logic         start,
    input logic [127:0] i_key,
    input logic [127:0] i_Plain_Text,
    input logic [127:0] o_Cipher_Text,
    input logic [127:0] o_Recovered_Plain_Text,
    input logic         o_done,
    input logic         o_busy,
    input logic [1:0]   state,
    input logic [4:0]   cycle_cnt
);
    localparam logic [1:0] S_IDLE = 2'd0, S_ENC = 2'd1, S_DEC = 2'd2, S_DONE = 2'd3;
    // start sampled -> o_done sampled high
    localparam int LATENCY = ENC_CYCLES + DEC_CYCLES + 2;

    // ======================= PROTOCOL =======================
    // After reset: idle, no done
    property p_reset;
        @(posedge clk) !rst_n |=> (state == S_IDLE && !o_done && !o_busy);
    endproperty

    // start is a single-cycle pulse
    property p_start_pulse;
        @(posedge clk) disable iff (!rst_n) start |=> !start;
    endproperty

    // start only when the design is idle
    property p_start_when_idle;
        @(posedge clk) disable iff (!rst_n) start |-> !o_busy;
    endproperty

    // Inputs must stay stable while an operation is in progress
    property p_inputs_stable;
        @(posedge clk) disable iff (!rst_n) (o_busy && $past(o_busy)) |-> ($stable(i_key) && $stable(i_Plain_Text));
    endproperty

    // Fixed latency from start to o_done
    property p_latency;
        @(posedge clk) disable iff (!rst_n) (start && !o_busy) |-> ##LATENCY o_done;
    endproperty

    // o_done is a single-cycle pulse
    property p_done_pulse;
        @(posedge clk) disable iff (!rst_n) o_done |=> !o_done;
    endproperty

    // No X/Z on the outputs when o_done is high
    property p_no_x;
        @(posedge clk) disable iff (!rst_n) o_done |-> !$isunknown({o_Cipher_Text, o_Recovered_Plain_Text});
    endproperty

    // End-to-end: decryption returns the original plain text
    property p_round_trip;
        @(posedge clk) disable iff (!rst_n) o_done |-> (o_Recovered_Plain_Text == i_Plain_Text);
    endproperty

    // ===================== ARCHITECTURAL =====================
    // start in IDLE moves to ENC with counter = 1
    property p_start_to_enc;
        @(posedge clk) disable iff (!rst_n) (start && state == S_IDLE) |=> (state == S_ENC && cycle_cnt == 5'd1);
    endproperty

    // ENC is always followed by DEC, DEC by DONE, DONE by IDLE
    property p_enc_to_dec;
        @(posedge clk) disable iff (!rst_n) (state == S_ENC && cycle_cnt == ENC_CYCLES) |=> (state == S_DEC);
    endproperty
    property p_dec_to_done;
        @(posedge clk) disable iff (!rst_n) (state == S_DEC && cycle_cnt == DEC_CYCLES) |=> (state == S_DONE);
    endproperty
    property p_done_to_idle;
        @(posedge clk) disable iff (!rst_n) (state == S_DONE) |=> (state == S_IDLE && o_done);
    endproperty

    // Cycle counter stays in range while running
    property p_cnt_range;
        @(posedge clk) disable iff (!rst_n)
            (state == S_ENC || state == S_DEC) |-> (cycle_cnt >= 5'd1 && cycle_cnt <= ((state == S_ENC) ? ENC_CYCLES : DEC_CYCLES));
    endproperty

    // Cipher text is produced (and held) before decryption finishes
    property p_ct_before_dec;
        @(posedge clk) disable iff (!rst_n) (state == S_DEC && cycle_cnt > 5'd1) |-> $stable(o_Cipher_Text);
    endproperty

    // o_busy matches the FSM
    property p_busy;
        @(posedge clk) disable iff (!rst_n) o_busy == (state != S_IDLE);
    endproperty

    // ---------------- assertions ----------------
    A_RESET          : assert property (p_reset)           else $error("SVA: reset behaviour violated");
    A_START_PULSE    : assert property (p_start_pulse)     else $error("SVA: start is not a single-cycle pulse");
    A_START_IDLE     : assert property (p_start_when_idle) else $error("SVA: start asserted while busy");
    A_INPUTS_STABLE  : assert property (p_inputs_stable)   else $error("SVA: key/plain text changed while busy");
    A_LATENCY        : assert property (p_latency)         else $error("SVA: o_done not %0d cycles after start", LATENCY);
    A_DONE_PULSE     : assert property (p_done_pulse)      else $error("SVA: o_done is not a single-cycle pulse");
    A_NO_X           : assert property (p_no_x)            else $error("SVA: X/Z on outputs at o_done");
    A_ROUND_TRIP     : assert property (p_round_trip)      else $error("SVA: recovered text != plain text");
    A_START_TO_ENC   : assert property (p_start_to_enc)    else $error("SVA: start did not enter ENC");
    A_ENC_TO_DEC     : assert property (p_enc_to_dec)      else $error("SVA: ENC not followed by DEC");
    A_DEC_TO_DONE    : assert property (p_dec_to_done)     else $error("SVA: DEC not followed by DONE");
    A_DONE_TO_IDLE   : assert property (p_done_to_idle)    else $error("SVA: DONE not followed by IDLE + o_done");
    A_CNT_RANGE      : assert property (p_cnt_range)       else $error("SVA: cycle counter out of range");
    A_CT_BEFORE_DEC  : assert property (p_ct_before_dec)   else $error("SVA: cipher text changed during decryption");
    A_BUSY           : assert property (p_busy)            else $error("SVA: o_busy inconsistent with FSM");

    C_FULL_OPERATION : cover property (@(posedge clk) disable iff (!rst_n) (start && !o_busy) ##LATENCY o_done);
endmodule
