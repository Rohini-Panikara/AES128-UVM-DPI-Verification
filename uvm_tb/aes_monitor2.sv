// ============================================================
// aes_monitor2.sv  -  OUTPUT monitor (inside the passive agent)
// Captures cipher text + recovered plain text when o_done is high
// and sends them to the scoreboard (actual path).
// ============================================================
class aes_monitor2 extends uvm_monitor;
    `uvm_component_utils(aes_monitor2)

    virtual aes_interface inter;
    uvm_analysis_port #(aes_seq_item) m_port2;
    int unsigned count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_port2 = new("m_port2", this);
        if (!uvm_config_db#(virtual aes_interface)::get(this, "", "aes_interface", inter))
            `uvm_fatal(get_type_name(), "config_db: aes_interface not found")
    endfunction

    virtual task run_phase(uvm_phase phase);
        aes_seq_item tr;
        forever begin
            @(posedge inter.clk);
            if (inter.rst_n === 1'b1 && inter.done === 1'b1) begin
                tr = aes_seq_item::type_id::create("mon2_tr");
                tr.key            = inter.key;          // still held by the driver
                tr.plain_text     = inter.plain_text;
                tr.cipher_text    = inter.cipher_text;
                tr.recovered_text = inter.recovered_text;
                count++;
                `uvm_info(get_type_name(), $sformatf("[%0d] output : ct=%h rec=%h",
                          count, tr.cipher_text, tr.recovered_text), UVM_MEDIUM)
                m_port2.write(tr);
            end
        end
    endtask
endclass
