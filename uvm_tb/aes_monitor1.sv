// ============================================================
// aes_monitor1.sv  -  INPUT monitor (inside the active agent)
// Captures key + plain text when start is seen, and measures the
// idle gap since the previous o_done. Sends the transaction to
// the scoreboard (expected path) and to the coverage subscriber.
// ============================================================
class aes_monitor1 extends uvm_monitor;
    `uvm_component_utils(aes_monitor1)

    virtual aes_interface inter;
    uvm_analysis_port #(aes_seq_item) m_port1;
    int unsigned count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_port1 = new("m_port1", this);
        if (!uvm_config_db#(virtual aes_interface)::get(this, "", "aes_interface", inter))
            `uvm_fatal(get_type_name(), "config_db: aes_interface not found")
    endfunction

    virtual task run_phase(uvm_phase phase);
        aes_seq_item tr;
        int unsigned cycles_since_done = 0;

        forever begin
            @(posedge inter.clk);
            if (inter.rst_n !== 1'b1) begin
                cycles_since_done = 0;
                continue;
            end

            if (inter.start === 1'b1) begin
                tr = aes_seq_item::type_id::create("mon1_tr");
                tr.key        = inter.key;
                tr.plain_text = inter.plain_text;
                tr.gap_cycles = cycles_since_done;
                count++;
                `uvm_info(get_type_name(), $sformatf("[%0d] input  : key=%h pt=%h gap=%0d",
                          count, tr.key, tr.plain_text, tr.gap_cycles), UVM_MEDIUM)
                m_port1.write(tr);
            end

            if (inter.done === 1'b1) cycles_since_done = 0;
            else                     cycles_since_done++;
        end
    endtask
endclass
