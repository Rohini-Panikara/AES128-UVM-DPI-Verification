// ============================================================
// aes_sequence1.sv  -  KNOWN-ANSWER TEST sequence
// Standard AES-128 vectors from FIPS-197 and NIST SP 800-38A.
// The scoreboard checks: C model == NIST expected, and DUT == C model.
// ============================================================
class aes_sequence1 extends uvm_sequence #(aes_seq_item);
    `uvm_object_utils(aes_sequence1)

    bit [127:0] kat_key[6] = '{128'h2b7e151628aed2a6abf7158809cf4f3c,
                               128'h000102030405060708090a0b0c0d0e0f,
                               128'h2b7e151628aed2a6abf7158809cf4f3c,
                               128'h2b7e151628aed2a6abf7158809cf4f3c,
                               128'h2b7e151628aed2a6abf7158809cf4f3c,
                               128'h2b7e151628aed2a6abf7158809cf4f3c};

    bit [127:0] kat_pt[6]  = '{128'h3243f6a8885a308d313198a2e0370734,
                               128'h00112233445566778899aabbccddeeff,
                               128'h6bc1bee22e409f96e93d7e117393172a,
                               128'hae2d8a571e03ac9c9eb76fac45af8e51,
                               128'h30c81c46a35ce411e5fbc1191a0a52ef,
                               128'hf69f2445df4f9b17ad2b417be66c3710};

    function new(string name = "aes_sequence1");
        super.new(name);
    endfunction

    virtual task body();
        aes_seq_item req;
        foreach (kat_key[i]) begin
            req = aes_seq_item::type_id::create($sformatf("kat_req%0d", i));
            start_item(req);
            if (!req.randomize() with { key_type   == PAT_RANDOM;
                                        pt_type    == PAT_RANDOM;
                                        key        == local::kat_key[i];
                                        plain_text == local::kat_pt[i]; })
                `uvm_error(get_type_name(), "randomize failed")
            finish_item(req);
        end
    endtask
endclass
