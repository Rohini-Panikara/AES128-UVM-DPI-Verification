// ============================================================
// aes_interface.sv
// Pin-level interface between the UVM testbench and the AES DUT
// (aes_c_dut: AES-128 C design called through DPI-C)
// ============================================================
interface aes_interface(input logic clk, input logic rst_n);

    logic         start;            // 1-cycle pulse: begin encrypt + decrypt
    logic [127:0] key;              // i_key
    logic [127:0] plain_text;       // i_Plain_Text
    logic [127:0] cipher_text;      // o_Cipher_Text
    logic [127:0] recovered_text;   // o_Recovered_Plain_Text
    logic         done;             // o_done (1-cycle pulse)

    modport tb (input clk, rst_n, cipher_text, recovered_text, done,
                output start, key, plain_text);

endinterface
