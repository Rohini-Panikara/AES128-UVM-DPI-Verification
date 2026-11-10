// ============================================================
// aes_ref_model.sv
// INDEPENDENT AES-128 reference model written in SystemVerilog
// (FIPS-197). Used by the scoreboard to check the C design.
//
// The DUT is the C code, so the reference must be a separate
// implementation - comparing the C code with itself would not
// verify anything. Both are additionally checked against the
// FIPS-197 / NIST known-answer vectors.
//
// 128-bit value layout: byte 0 = bits [127:120] ... byte 15 = [7:0]
// State is column-major: row r, column c -> byte 4*c + r
// ============================================================
class aes_ref_model;

    static bit [7:0] SBOX [256] = '{
      8'h63,8'h7c,8'h77,8'h7b,8'hf2,8'h6b,8'h6f,8'hc5,8'h30,8'h01,8'h67,8'h2b,8'hfe,8'hd7,8'hab,8'h76,
      8'hca,8'h82,8'hc9,8'h7d,8'hfa,8'h59,8'h47,8'hf0,8'had,8'hd4,8'ha2,8'haf,8'h9c,8'ha4,8'h72,8'hc0,
      8'hb7,8'hfd,8'h93,8'h26,8'h36,8'h3f,8'hf7,8'hcc,8'h34,8'ha5,8'he5,8'hf1,8'h71,8'hd8,8'h31,8'h15,
      8'h04,8'hc7,8'h23,8'hc3,8'h18,8'h96,8'h05,8'h9a,8'h07,8'h12,8'h80,8'he2,8'heb,8'h27,8'hb2,8'h75,
      8'h09,8'h83,8'h2c,8'h1a,8'h1b,8'h6e,8'h5a,8'ha0,8'h52,8'h3b,8'hd6,8'hb3,8'h29,8'he3,8'h2f,8'h84,
      8'h53,8'hd1,8'h00,8'hed,8'h20,8'hfc,8'hb1,8'h5b,8'h6a,8'hcb,8'hbe,8'h39,8'h4a,8'h4c,8'h58,8'hcf,
      8'hd0,8'hef,8'haa,8'hfb,8'h43,8'h4d,8'h33,8'h85,8'h45,8'hf9,8'h02,8'h7f,8'h50,8'h3c,8'h9f,8'ha8,
      8'h51,8'ha3,8'h40,8'h8f,8'h92,8'h9d,8'h38,8'hf5,8'hbc,8'hb6,8'hda,8'h21,8'h10,8'hff,8'hf3,8'hd2,
      8'hcd,8'h0c,8'h13,8'hec,8'h5f,8'h97,8'h44,8'h17,8'hc4,8'ha7,8'h7e,8'h3d,8'h64,8'h5d,8'h19,8'h73,
      8'h60,8'h81,8'h4f,8'hdc,8'h22,8'h2a,8'h90,8'h88,8'h46,8'hee,8'hb8,8'h14,8'hde,8'h5e,8'h0b,8'hdb,
      8'he0,8'h32,8'h3a,8'h0a,8'h49,8'h06,8'h24,8'h5c,8'hc2,8'hd3,8'hac,8'h62,8'h91,8'h95,8'he4,8'h79,
      8'he7,8'hc8,8'h37,8'h6d,8'h8d,8'hd5,8'h4e,8'ha9,8'h6c,8'h56,8'hf4,8'hea,8'h65,8'h7a,8'hae,8'h08,
      8'hba,8'h78,8'h25,8'h2e,8'h1c,8'ha6,8'hb4,8'hc6,8'he8,8'hdd,8'h74,8'h1f,8'h4b,8'hbd,8'h8b,8'h8a,
      8'h70,8'h3e,8'hb5,8'h66,8'h48,8'h03,8'hf6,8'h0e,8'h61,8'h35,8'h57,8'hb9,8'h86,8'hc1,8'h1d,8'h9e,
      8'he1,8'hf8,8'h98,8'h11,8'h69,8'hd9,8'h8e,8'h94,8'h9b,8'h1e,8'h87,8'he9,8'hce,8'h55,8'h28,8'hdf,
      8'h8c,8'ha1,8'h89,8'h0d,8'hbf,8'he6,8'h42,8'h68,8'h41,8'h99,8'h2d,8'h0f,8'hb0,8'h54,8'hbb,8'h16};

    static bit [7:0] INV_SBOX [256];      // built from SBOX on first use
    static bit       inv_ready = 0;

    // ---------------- byte access ----------------
    static function bit [7:0] get_b(bit [127:0] s, int i);
        return s[127 - 8*i -: 8];
    endfunction

    static function void set_b(ref bit [127:0] s, input int i, input bit [7:0] v);
        s[127 - 8*i -: 8] = v;
    endfunction

    // ---------------- GF(2^8) ----------------
    static function bit [7:0] xtime(bit [7:0] b);
        return {b[6:0], 1'b0} ^ (b[7] ? 8'h1b : 8'h00);
    endfunction

    static function bit [7:0] gmul(bit [7:0] a, bit [7:0] b);
        bit [7:0] p = 8'h00;
        for (int i = 0; i < 8; i++) begin
            if (b[i]) p ^= a;
            a = xtime(a);
        end
        return p;
    endfunction

    static function void build_inv_sbox();
        if (inv_ready) return;
        foreach (SBOX[i]) INV_SBOX[SBOX[i]] = i[7:0];
        inv_ready = 1;
    endfunction

    // ---------------- round operations ----------------
    static function bit [127:0] sub_bytes(bit [127:0] s, bit inv);
        bit [127:0] r;
        build_inv_sbox();
        for (int i = 0; i < 16; i++)
            set_b(r, i, inv ? INV_SBOX[get_b(s, i)] : SBOX[get_b(s, i)]);
        return r;
    endfunction

    // row r rotates left by r (inverse: right by r)
    static function bit [127:0] shift_rows(bit [127:0] s, bit inv);
        bit [127:0] r;
        for (int c = 0; c < 4; c++)
            for (int row = 0; row < 4; row++)
                set_b(r, 4*c + row, get_b(s, 4*((inv ? (c - row + 4) : (c + row)) % 4) + row));
        return r;
    endfunction

    static function bit [127:0] mix_columns(bit [127:0] s, bit inv);
        bit [127:0] r;
        bit [7:0] a0, a1, a2, a3;
        for (int c = 0; c < 4; c++) begin
            a0 = get_b(s, 4*c); a1 = get_b(s, 4*c+1); a2 = get_b(s, 4*c+2); a3 = get_b(s, 4*c+3);
            if (!inv) begin
                set_b(r, 4*c,   gmul(a0,2)  ^ gmul(a1,3)  ^ a2          ^ a3);
                set_b(r, 4*c+1, a0          ^ gmul(a1,2)  ^ gmul(a2,3)  ^ a3);
                set_b(r, 4*c+2, a0          ^ a1          ^ gmul(a2,2)  ^ gmul(a3,3));
                set_b(r, 4*c+3, gmul(a0,3)  ^ a1          ^ a2          ^ gmul(a3,2));
            end else begin
                set_b(r, 4*c,   gmul(a0,14) ^ gmul(a1,11) ^ gmul(a2,13) ^ gmul(a3,9));
                set_b(r, 4*c+1, gmul(a0,9)  ^ gmul(a1,14) ^ gmul(a2,11) ^ gmul(a3,13));
                set_b(r, 4*c+2, gmul(a0,13) ^ gmul(a1,9)  ^ gmul(a2,14) ^ gmul(a3,11));
                set_b(r, 4*c+3, gmul(a0,11) ^ gmul(a1,13) ^ gmul(a2,9)  ^ gmul(a3,14));
            end
        end
        return r;
    endfunction

    // ---------------- key expansion: 11 round keys ----------------
    static function void key_expansion(bit [127:0] key, ref bit [127:0] rk [11]);
        bit [31:0] w [44];
        bit [31:0] t;
        bit [7:0]  rcon = 8'h01;
        for (int i = 0; i < 4; i++) w[i] = key[127 - 32*i -: 32];
        for (int i = 4; i < 44; i++) begin
            t = w[i-1];
            if (i % 4 == 0) begin
                t = {t[23:0], t[31:24]};                                   // RotWord
                t = {SBOX[t[31:24]], SBOX[t[23:16]], SBOX[t[15:8]], SBOX[t[7:0]]};  // SubWord
                t[31:24] ^= rcon;                                          // Rcon
                rcon = xtime(rcon);
            end
            w[i] = w[i-4] ^ t;
        end
        for (int r = 0; r < 11; r++) rk[r] = {w[4*r], w[4*r+1], w[4*r+2], w[4*r+3]};
    endfunction

    // ---------------- encrypt / decrypt ----------------
    static function bit [127:0] encrypt(bit [127:0] key, bit [127:0] pt);
        bit [127:0] rk [11];
        bit [127:0] s;
        key_expansion(key, rk);
        s = pt ^ rk[0];
        for (int round = 1; round <= 10; round++) begin
            s = shift_rows(sub_bytes(s, 0), 0);
            if (round != 10) s = mix_columns(s, 0);
            s = s ^ rk[round];
        end
        return s;
    endfunction

    static function bit [127:0] decrypt(bit [127:0] key, bit [127:0] ct);
        bit [127:0] rk [11];
        bit [127:0] s;
        key_expansion(key, rk);
        s = ct ^ rk[10];
        for (int round = 9; round >= 0; round--) begin
            s = sub_bytes(shift_rows(s, 1), 1);
            s = s ^ rk[round];
            if (round != 0) s = mix_columns(s, 1);
        end
        return s;
    endfunction

endclass
