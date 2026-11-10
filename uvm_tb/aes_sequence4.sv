// ============================================================
// aes_sequence4.sv  -  TARGETED (coverage-closure) sequence
// Written after looking at the coverage report of the random test:
// it hits every key-pattern x plain-text-pattern combination
// (6 x 6 = 36 cross bins) and every idle-gap range.
// ============================================================
class aes_sequence4 extends uvm_sequence #(aes_seq_item);
    `uvm_object_utils(aes_sequence4)

    function new(string name = "aes_sequence4");
        super.new(name);
    endfunction

    virtual task body();
        aes_seq_item  req;
        aes_pattern_e kp, pp;
        int unsigned  gaps[3] = '{0, 4, 10};   // back-to-back, short, long

        // 1) every key pattern x plain-text pattern
        for (int k = 0; k < 6; k++) begin
            for (int p = 0; p < 6; p++) begin
                kp  = aes_pattern_e'(k);
                pp  = aes_pattern_e'(p);
                req = aes_seq_item::type_id::create("tgt_req");
                start_item(req);
                if (!req.randomize() with { key_type == kp; pt_type == pp; })
                    `uvm_error(get_type_name(), "randomize failed")
                finish_item(req);
            end
        end

        // 2) every idle-gap range
        foreach (gaps[g]) begin
            req = aes_seq_item::type_id::create("gap_req");
            start_item(req);
            if (!req.randomize() with { idle_cycles == gaps[g]; })
                `uvm_error(get_type_name(), "randomize failed")
            finish_item(req);
        end
    endtask
endclass
