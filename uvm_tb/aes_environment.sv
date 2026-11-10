// ============================================================
// aes_environment.sv
//   act1 (active agent)  : seqr, dri, mon1 --+--> score.m_imp1 (expected, C model)
//                                            +--> sub (coverage)
//   act2 (passive agent) : mon2 -------------> score.m_imp2 (actual, DUT)
// ============================================================
class aes_environment extends uvm_env;
    `uvm_component_utils(aes_environment)

    aes_active_agent  act1;
    aes_passive_agent act2;
    aes_scoreboard    score;
    aes_subscriber    sub;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        act1  = aes_active_agent ::type_id::create("act1",  this);
        act2  = aes_passive_agent::type_id::create("act2",  this);
        score = aes_scoreboard   ::type_id::create("score", this);
        sub   = aes_subscriber   ::type_id::create("sub",   this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        act1.mon1.m_port1.connect(score.m_imp1);
        act2.mon2.m_port2.connect(score.m_imp2);
        act1.mon1.m_port1.connect(sub.analysis_export);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction
endclass
