// Virtual sequencer: holds the two real sequencers (one per clock domain)
// plus the env config, so virtual sequences can also reach the clock /
// reset interface (mid-test resets, clock-ratio changes).
class fifo_vsequencer extends uvm_sequencer;

        `uvm_component_utils(fifo_vsequencer)

        fifo_wr_sequencer wr_seqr;
        fifo_rd_sequencer rd_seqr;
        fifo_env_cfg      cfg;

        function new(string name, uvm_component parent);
                super.new(name, parent);
        endfunction

endclass: fifo_vsequencer
