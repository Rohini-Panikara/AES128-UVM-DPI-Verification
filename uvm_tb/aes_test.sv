// ============================================================
// aes_test.sv  -  test classes
//
//   testcase   : full regression  (KAT + random + constrained + targeted)
//   testcase1  : known-answer tests only
//   testcase2  : pure random only          -> shows coverage HOLES
//   testcase3  : random + constrained-random
//   testcase4  : random + targeted          -> coverage CLOSURE
//
// Select with +UVM_TESTNAME=<name> (default in top: testcase)
// ============================================================
class aes_base_test extends uvm_test;
    `uvm_component_utils(aes_base_test)

    aes_environment env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = aes_environment::type_id::create("env", this);
    endfunction

    // Each test overrides this
    virtual task run_sequences();
    endtask

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        run_sequences();
        #100;                                   // let the last output reach the scoreboard
        phase.drop_objection(this);
    endtask

    virtual function void report_phase(uvm_phase phase);
        uvm_report_server svr = uvm_report_server::get_server();
        super.report_phase(phase);
        if (svr.get_severity_count(UVM_ERROR) + svr.get_severity_count(UVM_FATAL) == 0)
            `uvm_info(get_type_name(), "*************** TEST PASSED ***************", UVM_NONE)
        else
            `uvm_info(get_type_name(), "*************** TEST FAILED ***************", UVM_NONE)
    endfunction
endclass


// ---------------- full regression ----------------
class testcase extends aes_base_test;
    `uvm_component_utils(testcase)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_sequences();
        aes_sequence1 seq1 = aes_sequence1::type_id::create("seq1");
        aes_sequence2 seq2 = aes_sequence2::type_id::create("seq2");
        aes_sequence3 seq3 = aes_sequence3::type_id::create("seq3");
        aes_sequence4 seq4 = aes_sequence4::type_id::create("seq4");
        seq1.start(env.act1.seqr);     // known-answer
        seq2.start(env.act1.seqr);     // random
        seq3.start(env.act1.seqr);     // constrained-random
        seq4.start(env.act1.seqr);     // targeted
    endtask
endclass


// ---------------- known-answer only ----------------
class testcase1 extends aes_base_test;
    `uvm_component_utils(testcase1)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_sequences();
        aes_sequence1 seq1 = aes_sequence1::type_id::create("seq1");
        seq1.start(env.act1.seqr);
    endtask
endclass


// ---------------- random only (coverage holes) ----------------
class testcase2 extends aes_base_test;
    `uvm_component_utils(testcase2)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_sequences();
        aes_sequence2 seq2 = aes_sequence2::type_id::create("seq2");
        seq2.num_trans = 300;
        seq2.start(env.act1.seqr);
    endtask
endclass


// ---------------- random + constrained-random ----------------
class testcase3 extends aes_base_test;
    `uvm_component_utils(testcase3)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_sequences();
        aes_sequence2 seq2 = aes_sequence2::type_id::create("seq2");
        aes_sequence3 seq3 = aes_sequence3::type_id::create("seq3");
        seq2.num_trans = 300;
        seq2.start(env.act1.seqr);
        seq3.start(env.act1.seqr);
    endtask
endclass


// ---------------- random + targeted (coverage closure) ----------------
class testcase4 extends aes_base_test;
    `uvm_component_utils(testcase4)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_sequences();
        aes_sequence2 seq2 = aes_sequence2::type_id::create("seq2");
        aes_sequence4 seq4 = aes_sequence4::type_id::create("seq4");
        seq2.num_trans = 300;
        seq2.start(env.act1.seqr);
        seq4.start(env.act1.seqr);
    endtask
endclass
