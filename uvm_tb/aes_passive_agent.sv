// ============================================================
// aes_passive_agent.sv  -  output monitor only
// ============================================================
class aes_passive_agent extends uvm_agent;
    `uvm_component_utils(aes_passive_agent)

    aes_monitor2 mon2;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon2 = aes_monitor2::type_id::create("mon2", this);
    endfunction
endclass
