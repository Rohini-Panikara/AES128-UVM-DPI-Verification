// ============================================================
// aes_c_dut.sv
// DESIGN UNDER TEST = the AES-128 C design (aes128_ref.c),
// called through DPI-C (aes128_dpi.c).
//
// This wrapper gives the C design a clocked, hardware-like
// interface so the UVM testbench can drive it like an RTL block:
//
//   start (1-cycle pulse) -> inputs sampled
//   ENC_CYCLES clocks     -> encryption  (C function dpi_aes128_encrypt)
//   DEC_CYCLES clocks     -> decryption  (C function dpi_aes128_decrypt)
//   o_done (1-cycle pulse) with o_Cipher_Text / o_Recovered_Plain_Text
//
// Port names are the same as AES_TOP_iterative, so the same UVM
// environment can also drive the Verilog RTL later.
// ============================================================
module aes_c_dut #(
    parameter int ENC_CYCLES = 11,     // 1 initial AddRoundKey + 10 rounds
    parameter int DEC_CYCLES = 11
)(
    input  logic         clk,
    input  logic         rst_n,              // active-low synchronous reset
    input  logic         start,
    input  logic [127:0] i_key,
    input  logic [127:0] i_Plain_Text,
    output logic [127:0] o_Cipher_Text,
    output logic [127:0] o_Recovered_Plain_Text,
    output logic         o_done,
    output logic         o_busy
);

    // ---------------- C design (DPI-C imports) ----------------
    import "DPI-C" function void dpi_aes128_encrypt(input  bit [127:0] key,
                                                    input  bit [127:0] pt,
                                                    output bit [127:0] ct);
    import "DPI-C" function void dpi_aes128_decrypt(input  bit [127:0] key,
                                                    input  bit [127:0] ct,
                                                    output bit [127:0] pt);

    typedef enum logic [1:0] {S_IDLE, S_ENC, S_DEC, S_DONE} state_e;
    state_e      state;
    logic [4:0]  cycle_cnt;
    bit   [127:0] key_reg, pt_reg, ct_reg, rec_reg;

    assign o_busy = (state != S_IDLE);

    always_ff @(posedge clk) begin : fsm
        bit [127:0] c_tmp, p_tmp;     // results returned by the C functions
        if (!rst_n) begin
            state                  <= S_IDLE;
            cycle_cnt              <= '0;
            key_reg                <= '0;
            pt_reg                 <= '0;
            ct_reg                 <= '0;
            rec_reg                <= '0;
            o_Cipher_Text          <= '0;
            o_Recovered_Plain_Text <= '0;
            o_done                 <= 1'b0;
        end
        else begin
            o_done <= 1'b0;
            case (state)
                S_IDLE: if (start) begin
                    key_reg   <= i_key;
                    pt_reg    <= i_Plain_Text;
                    cycle_cnt <= 5'd1;
                    state     <= S_ENC;
                end

                S_ENC: begin
                    if (cycle_cnt == ENC_CYCLES) begin
                        dpi_aes128_encrypt(key_reg, pt_reg, c_tmp);       // C design: encrypt
                        ct_reg        <= c_tmp;
                        o_Cipher_Text <= c_tmp;
                        cycle_cnt     <= 5'd1;
                        state         <= S_DEC;
                    end
                    else cycle_cnt <= cycle_cnt + 5'd1;
                end

                S_DEC: begin
                    if (cycle_cnt == DEC_CYCLES) begin
                        dpi_aes128_decrypt(key_reg, ct_reg, p_tmp);       // C design: decrypt
                        rec_reg                <= p_tmp;
                        o_Recovered_Plain_Text <= p_tmp;
                        state                  <= S_DONE;
                    end
                    else cycle_cnt <= cycle_cnt + 5'd1;
                end

                S_DONE: begin
                    o_done <= 1'b1;
                    state  <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
