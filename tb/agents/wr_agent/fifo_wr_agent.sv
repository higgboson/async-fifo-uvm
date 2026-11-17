typedef uvm_sequencer #(fifo_wr_item) fifo_wr_sequencer;

class fifo_wr_agent extends uvm_agent;

        `uvm_component_utils(fifo_wr_agent)

        fifo_wr_agent_cfg  cfg;
        fifo_wr_driver     drv;
        fifo_wr_monitor    mon;
        fifo_wr_sequencer  seqr;

        function new(string name, uvm_component parent);
                super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                if (!uvm_config_db #(fifo_wr_agent_cfg)::get(this, "", "cfg", cfg))
                        `uvm_fatal("NOCFG", "fifo_wr_agent_cfg not set for the write agent")
                mon = fifo_wr_monitor::type_id::create("mon", this);
                if (cfg.is_active == UVM_ACTIVE) begin
                        drv  = fifo_wr_driver::type_id::create("drv", this);
                        seqr = fifo_wr_sequencer::type_id::create("seqr", this);
                end
        endfunction

        function void connect_phase(uvm_phase phase);
                if (cfg.is_active == UVM_ACTIVE)
                        drv.seq_item_port.connect(seqr.seq_item_export);
        endfunction

endclass: fifo_wr_agent
