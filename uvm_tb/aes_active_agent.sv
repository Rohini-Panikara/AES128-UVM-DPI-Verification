// ============================================================
// aes_active_agent.sv  -  sequencer + driver + input monitor
// ============================================================
class aes_active_agent extends uvm_agent;
    `uvm_component_utils(aes_active_agent)

    aes_sequencer seqr;
    aes_driver    dri;
    aes_monitor1  mon1;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seqr = aes_sequencer::type_id::create("seqr", this);
        dri  = aes_driver   ::type_id::create("dri",  this);
        mon1 = aes_monitor1 ::type_id::create("mon1", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        dri.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass
