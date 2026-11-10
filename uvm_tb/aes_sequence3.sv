// ============================================================
// aes_sequence3.sv  -  CONSTRAINED-RANDOM sequence
// Uses the weighted pattern distribution of aes_seq_item:
// 50% random values + all-zero / all-one / walking-one /
// walking-zero / repeated-byte keys and plain texts.
// ============================================================
class aes_sequence3 extends uvm_sequence #(aes_seq_item);
    `uvm_object_utils(aes_sequence3)

    int unsigned num_trans = 200;

    function new(string name = "aes_sequence3");
        super.new(name);
    endfunction

    virtual task body();
        aes_seq_item req;
        repeat (num_trans) begin
            req = aes_seq_item::type_id::create("crand_req");
            start_item(req);
            if (!req.randomize())
                `uvm_error(get_type_name(), "randomize failed")
            finish_item(req);
        end
    endtask
endclass
