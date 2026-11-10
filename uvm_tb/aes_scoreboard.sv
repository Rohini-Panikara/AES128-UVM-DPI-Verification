// ============================================================
// aes_scoreboard.sv
//   DUT       = AES-128 C design (via DPI-C, inside aes_c_dut)
//   Reference = independent SystemVerilog model (aes_ref_model)
//
// m_imp1 (_before) : input transactions from aes_monitor1
//                    -> expected result from aes_ref_model
// m_imp2 (_after)  : output transactions from aes_monitor2
//                    -> compared with the expected result
//
// Known-answer vectors (FIPS-197 / NIST SP 800-38A):
//   * the SV reference model is checked against them at the start
//   * when a KAT input is driven, the DUT output is also compared
//     with the NIST cipher text
// ============================================================
`uvm_analysis_imp_decl(_before)
`uvm_analysis_imp_decl(_after)

class aes_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(aes_scoreboard)

    uvm_analysis_imp_before #(aes_seq_item, aes_scoreboard) m_imp1;
    uvm_analysis_imp_after  #(aes_seq_item, aes_scoreboard) m_imp2;

    aes_seq_item exp_q[$];                 // expected results, in order
    bit [127:0]  kat_db[bit [255:0]];      // {key, plain_text} -> NIST cipher text

    int unsigned pass_cnt, fail_cnt;
    int unsigned kat_cnt,  kat_fail_cnt;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_imp1 = new("m_imp1", this);
        m_imp2 = new("m_imp2", this);

        kat_db[{128'h2b7e151628aed2a6abf7158809cf4f3c, 128'h3243f6a8885a308d313198a2e0370734}] = 128'h3925841d02dc09fbdc118597196a0b32;
        kat_db[{128'h000102030405060708090a0b0c0d0e0f, 128'h00112233445566778899aabbccddeeff}] = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
        kat_db[{128'h2b7e151628aed2a6abf7158809cf4f3c, 128'h6bc1bee22e409f96e93d7e117393172a}] = 128'h3ad77bb40d7a3660a89ecaf32466ef97;
        kat_db[{128'h2b7e151628aed2a6abf7158809cf4f3c, 128'hae2d8a571e03ac9c9eb76fac45af8e51}] = 128'hf5d3d58503b9699de785895a96fdbaaf;
        kat_db[{128'h2b7e151628aed2a6abf7158809cf4f3c, 128'h30c81c46a35ce411e5fbc1191a0a52ef}] = 128'h43b1cd7f598ece23881b00e3ed030688;
        kat_db[{128'h2b7e151628aed2a6abf7158809cf4f3c, 128'hf69f2445df4f9b17ad2b417be66c3710}] = 128'h7b0c785e27e8ad3f8223207104725dd4;
    endfunction

    // ---------------- reference model self-check (NIST vectors) ----------------
    virtual function void start_of_simulation_phase(uvm_phase phase);
        bit [255:0] kp;
        bit [127:0] ct, pt;
        int bad = 0;
        super.start_of_simulation_phase(phase);
        foreach (kat_db[kp]) begin
            ct = aes_ref_model::encrypt(kp[255:128], kp[127:0]);
            pt = aes_ref_model::decrypt(kp[255:128], ct);
            if (ct !== kat_db[kp] || pt !== kp[127:0]) begin
                bad++;
                `uvm_error(get_type_name(), $sformatf("REF MODEL != NIST  key=%h pt=%h ref=%h NIST=%h",
                           kp[255:128], kp[127:0], ct, kat_db[kp]))
            end
        end
        if (bad == 0)
            `uvm_info(get_type_name(), $sformatf("Reference model validated against %0d NIST known-answer vectors",
                      kat_db.num()), UVM_NONE)
    endfunction

    // ---------------- expected path (input monitor) ----------------
    virtual function void write_before(aes_seq_item t);
        aes_seq_item exp = aes_seq_item::type_id::create("exp");
        exp.key            = t.key;
        exp.plain_text     = t.plain_text;
        exp.cipher_text    = aes_ref_model::encrypt(t.key, t.plain_text);
        exp.recovered_text = aes_ref_model::decrypt(t.key, exp.cipher_text);
        exp_q.push_back(exp);
    endfunction

    // ---------------- actual path (output monitor) ----------------
    virtual function void write_after(aes_seq_item t);
        aes_seq_item exp;
        bit ok, is_kat;

        if (exp_q.size() == 0) begin
            `uvm_error(get_type_name(), "output seen with no matching input transaction")
            return;
        end
        exp = exp_q.pop_front();

        ok = (t.cipher_text    === exp.cipher_text)    &&
             (t.recovered_text === exp.recovered_text) &&
             (t.recovered_text === exp.plain_text);

        // Known-answer input: the C design must also match the NIST value
        is_kat = kat_db.exists({exp.key, exp.plain_text});
        if (is_kat) begin
            kat_cnt++;
            if (t.cipher_text !== kat_db[{exp.key, exp.plain_text}]) begin
                ok = 0;
                kat_fail_cnt++;
            end
        end

        if (ok) begin
            pass_cnt++;
            `uvm_info(get_type_name(), $sformatf("%skey=%h pt=%h | ref ct=%h  C-design ct=%h | rec=%h",
                      is_kat ? "[KAT] " : "", exp.key, exp.plain_text, exp.cipher_text,
                      t.cipher_text, t.recovered_text), UVM_LOW)
            `uvm_info(get_type_name(), "----------------------------PASSED------------------------------------", UVM_LOW)
        end
        else begin
            fail_cnt++;
            `uvm_error(get_type_name(), $sformatf("MISMATCH key=%h pt=%h | ref ct=%h C-design ct=%h | ref rec=%h C-design rec=%h",
                       exp.key, exp.plain_text, exp.cipher_text, t.cipher_text, exp.recovered_text, t.recovered_text))
            `uvm_info(get_type_name(), "----------------------------FAILED------------------------------------", UVM_NONE)
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), "==================== SCOREBOARD SUMMARY ====================", UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("Transactions checked : %0d", pass_cnt + fail_cnt), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("PASSED               : %0d", pass_cnt), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("FAILED               : %0d", fail_cnt), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("Known-answer vectors : %0d (failures: %0d)", kat_cnt, kat_fail_cnt), UVM_NONE)
        if (exp_q.size() != 0)
            `uvm_error(get_type_name(), $sformatf("%0d inputs never produced an output", exp_q.size()))
        `uvm_info(get_type_name(), "============================================================", UVM_NONE)
    endfunction
endclass
