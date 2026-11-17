// Write monitor: samples the write port every wclk (just before the edge)
// and broadcasts one item per cycle. On reset it sends a single item with
// rst=1 (only on the FIRST cycle of the reset, so the scoreboard flushes
// once, while both domains are guaranteed to still be in reset).
class fifo_wr_monitor extends uvm_monitor;

        `uvm_component_utils(fifo_wr_monitor)

        virtual fifo_wr_if.MON vif;
        fifo_wr_agent_cfg      cfg;

        uvm_analysis_port #(fifo_wr_item) ap;

        function new(string name, uvm_component parent);
                super.new(name, parent);
                ap = new("ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                if (!uvm_config_db #(fifo_wr_agent_cfg)::get(this, "", "cfg", cfg))
                        `uvm_fatal("NOCFG", "fifo_wr_agent_cfg not set for the write monitor")
        endfunction

        function void connect_phase(uvm_phase phase);
                vif = cfg.vif;
        endfunction

        task run_phase(uvm_phase phase);
                fifo_wr_item t;
                bit          in_rst = 1'b0;
                forever begin
                        @(vif.mon_cb);
                        if (vif.mon_cb.wrst_n !== 1'b1) begin
                                if (!in_rst) begin
                                        t     = fifo_wr_item::type_id::create("t");
                                        t.rst = 1'b1;
                                        ap.write(t);
                                end
                                in_rst = 1'b1;
                                continue;
                        end
                        in_rst = 1'b0;

                        t          = fifo_wr_item::type_id::create("t");
                        t.wr_en    = vif.mon_cb.wr_en;
                        t.wdata    = vif.mon_cb.wdata;
                        t.full     = vif.mon_cb.full;
                        t.overflow = vif.mon_cb.overflow;
                        t.accepted = t.wr_en && !t.full;
                        `uvm_info("WR_MON", t.convert2string(), UVM_DEBUG)
                        ap.write(t);
                end
        endtask

endclass: fifo_wr_monitor
