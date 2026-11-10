// ============================================================
// aes_subscriber.sv  -  FUNCTIONAL COVERAGE collector
// Samples every input transaction from aes_monitor1 and classifies
// the observed key / plain text into patterns.
//
//   cp_key       : key pattern        (6 bins)
//   cp_pt        : plain-text pattern (6 bins)
//   cp_key_x_pt  : key x plain-text   (36 cross bins)
//   cp_gap       : idle gap before start (back-to-back / short / long)
//   cp_key_msb   : top byte of the key (4 ranges)
//   cp_pt_msb    : top byte of the plain text (4 ranges)
// ============================================================
class aes_subscriber extends uvm_subscriber #(aes_seq_item);
    `uvm_component_utils(aes_subscriber)

    aes_seq_item  req;
    aes_pattern_e key_cls, pt_cls;
    int unsigned  sample_cnt;

    covergroup cvg;
        option.per_instance = 1;

        cp_key : coverpoint key_cls {
            bins all_zero     = {PAT_ALL_ZERO};
            bins all_one      = {PAT_ALL_ONE};
            bins walking_one  = {PAT_WALKING_ONE};
            bins walking_zero = {PAT_WALKING_ZERO};
            bins repeat_byte  = {PAT_REPEAT_BYTE};
            bins random       = {PAT_RANDOM};
        }
        cp_pt : coverpoint pt_cls {
            bins all_zero     = {PAT_ALL_ZERO};
            bins all_one      = {PAT_ALL_ONE};
            bins walking_one  = {PAT_WALKING_ONE};
            bins walking_zero = {PAT_WALKING_ZERO};
            bins repeat_byte  = {PAT_REPEAT_BYTE};
            bins random       = {PAT_RANDOM};
        }
        cp_key_x_pt : cross cp_key, cp_pt;

        cp_gap : coverpoint req.gap_cycles {
            bins back_to_back = {[0:3]};
            bins short_gap    = {[4:7]};
            bins long_gap     = {[8:$]};
        }
        cp_key_msb : coverpoint req.key[127:120] {
            bins q0 = {[0:63]};   bins q1 = {[64:127]};
            bins q2 = {[128:191]}; bins q3 = {[192:255]};
        }
        cp_pt_msb : coverpoint req.plain_text[127:120] {
            bins q0 = {[0:63]};   bins q1 = {[64:127]};
            bins q2 = {[128:191]}; bins q3 = {[192:255]};
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cvg = new();
    endfunction

    // Classify an observed 128-bit value into a pattern
    function aes_pattern_e classify(bit [127:0] v);
        if (v == 128'h0)                 return PAT_ALL_ZERO;
        if (v == {128{1'b1}})            return PAT_ALL_ONE;
        if ($countones(v) == 1)          return PAT_WALKING_ONE;
        if ($countones(v) == 127)        return PAT_WALKING_ZERO;
        if (v == {16{v[7:0]}})           return PAT_REPEAT_BYTE;
        return PAT_RANDOM;
    endfunction

    virtual function void write(aes_seq_item t);
        req     = t;
        key_cls = classify(t.key);
        pt_cls  = classify(t.plain_text);
        sample_cnt++;
        cvg.sample();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), "==================== FUNCTIONAL COVERAGE ===================", UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("Samples           : %0d",     sample_cnt), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("cp_key            : %6.2f %%", cvg.cp_key.get_coverage()), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("cp_pt             : %6.2f %%", cvg.cp_pt.get_coverage()), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("cp_key_x_pt       : %6.2f %%", cvg.cp_key_x_pt.get_coverage()), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("cp_gap            : %6.2f %%", cvg.cp_gap.get_coverage()), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("cp_key_msb        : %6.2f %%", cvg.cp_key_msb.get_coverage()), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("cp_pt_msb         : %6.2f %%", cvg.cp_pt_msb.get_coverage()), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("TOTAL COVERAGE    : %6.2f %%", cvg.get_inst_coverage()), UVM_NONE)
        `uvm_info(get_type_name(), "============================================================", UVM_NONE)
    endfunction
endclass
