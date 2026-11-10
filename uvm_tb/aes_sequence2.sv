// ============================================================
// aes_sequence2.sv  -  PURE RANDOM sequence
// Fully random keys and plain texts (no corner-case patterns).
// Used as the first step of coverage closure: it leaves coverage
// holes for the special patterns.
// ============================================================
class aes_sequence2 extends uvm_sequence #(aes_seq_item);
    `uvm_object_utils(aes_sequence2)

    int unsigned num_trans = 200;

    function new(string name = "aes_sequence2");
        super.new(name);
    endfunction

    virtual task body();
        aes_seq_item req;
        repeat (num_trans) begin
            req = aes_seq_item::type_id::create("rand_req");
            start_item(req);
            if (!req.randomize() with { key_type == PAT_RANDOM; pt_type == PAT_RANDOM; })
                `uvm_error(get_type_name(), "randomize failed")
            finish_item(req);
        end
    endtask
endclass
