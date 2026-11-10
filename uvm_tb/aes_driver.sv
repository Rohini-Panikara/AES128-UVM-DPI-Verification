// ============================================================
// aes_driver.sv
// Converts each aes_seq_item into pin activity on the DUT:
//   1. wait idle_cycles
//   2. apply key and plain text
//   3. wait 2 clocks (input set-up time before start)
//   4. pulse start for one clock
//   5. hold inputs until o_done
// Inputs are driven on the falling edge, so the DUT and the
// monitors sample stable values on the rising edge.
// ============================================================
class aes_driver extends uvm_driver #(aes_seq_item);
    `uvm_component_utils(aes_driver)

    virtual aes_interface inter;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual aes_interface)::get(this, "", "aes_interface", inter))
            `uvm_fatal(get_type_name(), "config_db: aes_interface not found")
    endfunction

    virtual task run_phase(uvm_phase phase);
        inter.start      <= 1'b0;
        inter.key        <= '0;
        inter.plain_text <= '0;
        wait (inter.rst_n === 1'b1);

        forever begin
            seq_item_port.get_next_item(req);
            drive_item(req);
            seq_item_port.item_done();
        end
    endtask

    virtual task drive_item(aes_seq_item req);
        repeat (req.idle_cycles) @(negedge inter.clk);

        @(negedge inter.clk);
        inter.key        <= req.key;
        inter.plain_text <= req.plain_text;

        repeat (2) @(negedge inter.clk);          // input set-up time
        inter.start <= 1'b1;
        @(negedge inter.clk);
        inter.start <= 1'b0;

        @(posedge inter.clk iff inter.done === 1'b1);   // wait for completion
        `uvm_info(get_type_name(), $sformatf("driven: key=%h pt=%h", req.key, req.plain_text), UVM_HIGH)
    endtask
endclass
