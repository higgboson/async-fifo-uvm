// Read monitor: samples the read port every rclk (just before the edge).
// Because rdata is registered, an accepted read at edge k shows its data at
// the sample of edge k+1; the monitor remembers that a read is pending and
// tags the next item with data_valid=1.
class fifo_rd_monitor extends uvm_monitor;

        `uvm_component_utils(fifo_rd_monitor)

        virtual fifo_rd_if.MON vif;
        fifo_rd_agent_cfg      cfg;

        uvm_analysis_port #(fifo_rd_item) ap;

        function new(string name, uvm_component parent);
                super.new(name, parent);
                ap = new("ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                if (!uvm_config_db #(fifo_rd_agent_cfg)::get(this, "", "cfg", cfg))
                        `uvm_fatal("NOCFG", "fifo_rd_agent_cfg not set for the read monitor")
        endfunction

        function void connect_phase(uvm_phase phase);
                vif = cfg.vif;
        endfunction

        task run_phase(uvm_phase phase);
                fifo_rd_item t;
                bit          in_rst  = 1'b0;
                bit          pending = 1'b0;
                forever begin
                        @(vif.mon_cb);
                        if (vif.mon_cb.rrst_n !== 1'b1) begin
                                if (!in_rst) begin
                                        t     = fifo_rd_item::type_id::create("t");
                                        t.rst = 1'b1;
                                        ap.write(t);
                                end
                                in_rst  = 1'b1;
                                pending = 1'b0;     // a read in flight is killed by the reset
                                continue;
                        end
                        in_rst = 1'b0;

                        t            = fifo_rd_item::type_id::create("t");
                        t.rd_en      = vif.mon_cb.rd_en;
                        t.empty      = vif.mon_cb.empty;
                        t.underflow  = vif.mon_cb.underflow;
                        t.accepted   = t.rd_en && !t.empty;
                        t.data_valid = pending;
                        t.rdata      = vif.mon_cb.rdata;
                        pending      = t.accepted;
                        `uvm_info("RD_MON", t.convert2string(), UVM_DEBUG)
                        ap.write(t);
                end
        endtask

endclass: fifo_rd_monitor
