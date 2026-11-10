// ============================================================
// aes_seq_item.sv
// One AES transaction: key + plain text in, cipher text +
// recovered plain text out.
// ============================================================
typedef enum bit [2:0] {
    PAT_RANDOM,        // fully random 128 bits
    PAT_ALL_ZERO,      // 0000...0000
    PAT_ALL_ONE,       // ffff...ffff
    PAT_WALKING_ONE,   // exactly one bit set
    PAT_WALKING_ZERO,  // exactly one bit clear
    PAT_REPEAT_BYTE    // same byte repeated 16 times
} aes_pattern_e;

class aes_seq_item extends uvm_sequence_item;

    // ---------------- stimulus (randomized) ----------------
    rand aes_pattern_e key_type;
    rand aes_pattern_e pt_type;
    rand bit [127:0]   key;
    rand bit [127:0]   plain_text;
    rand int unsigned  idle_cycles;     // idle clocks before this operation

    // ---------------- response (filled by monitors) --------
    bit [127:0]  cipher_text;
    bit [127:0]  recovered_text;
    int unsigned gap_cycles;            // measured clocks between previous done and start

    `uvm_object_utils_begin(aes_seq_item)
        `uvm_field_enum(aes_pattern_e, key_type, UVM_ALL_ON)
        `uvm_field_enum(aes_pattern_e, pt_type,  UVM_ALL_ON)
        `uvm_field_int(key,            UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(plain_text,     UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(cipher_text,    UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(recovered_text, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(idle_cycles,    UVM_ALL_ON | UVM_DEC)
    `uvm_object_utils_end

    function new(string name = "aes_seq_item");
        super.new(name);
    endfunction

    // ---------------- constraints ----------------
    // Default: mostly random values, some corner-case patterns
    constraint c_pattern_dist {
        key_type dist {PAT_RANDOM := 50, PAT_ALL_ZERO := 10, PAT_ALL_ONE := 10,
                       PAT_WALKING_ONE := 10, PAT_WALKING_ZERO := 10, PAT_REPEAT_BYTE := 10};
        pt_type  dist {PAT_RANDOM := 50, PAT_ALL_ZERO := 10, PAT_ALL_ONE := 10,
                       PAT_WALKING_ONE := 10, PAT_WALKING_ZERO := 10, PAT_REPEAT_BYTE := 10};
    }

    // Key value follows the selected pattern
    constraint c_key_pattern {
        (key_type == PAT_ALL_ZERO)     -> (key == 128'h0);
        (key_type == PAT_ALL_ONE)      -> (key == {128{1'b1}});
        (key_type == PAT_WALKING_ONE)  -> ($countones(key) == 1);
        (key_type == PAT_WALKING_ZERO) -> ($countones(key) == 127);
        (key_type == PAT_REPEAT_BYTE)  -> (key == {16{key[7:0]}});
    }

    // Plain-text value follows the selected pattern
    constraint c_pt_pattern {
        (pt_type == PAT_ALL_ZERO)     -> (plain_text == 128'h0);
        (pt_type == PAT_ALL_ONE)      -> (plain_text == {128{1'b1}});
        (pt_type == PAT_WALKING_ONE)  -> ($countones(plain_text) == 1);
        (pt_type == PAT_WALKING_ZERO) -> ($countones(plain_text) == 127);
        (pt_type == PAT_REPEAT_BYTE)  -> (plain_text == {16{plain_text[7:0]}});
    }

    // Idle time between operations: back-to-back, short and long gaps
    constraint c_idle {
        idle_cycles dist {0 := 30, [1:5] := 40, [6:10] := 30};
    }

    function string convert2string();
        return $sformatf("key=%h pt=%h ct=%h rec=%h", key, plain_text, cipher_text, recovered_text);
    endfunction

endclass
