// Write driver: one item = one wclk cycle.
// If the sequencer has nothing to send this cycle the driver drives an idle
// cycle (wr_en=0), so the pins are never left holding a stale request.
// After the cycle the driver writes the response fields back into the item
// (full as the DUT saw it, accepted or not) before item_done().
class fifo_wr_driver extends uvm_driver #(fifo_wr_item);

        `uvm_component_utils(fifo_wr_driver)

        virtual fifo_wr_if  vif;
        fifo_wr_agent_cfg      cfg;

        function new(string name, uvm_component parent);
                super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                if (!uvm_config_db #(fifo_wr_agent_cfg)::get(this, "", "cfg", cfg))
                        `uvm_fatal("NOCFG", "fifo_wr_agent_cfg not set for the write driver")
        endfunction

        function void connect_phase(uvm_phase phase);
                vif = cfg.vif;
        endfunction

        // Drive the pins for the next cycle. Normally through the clocking
        // block (1ns output skew). Verilator mis-schedules a clocking drive
        // issued after UVM's NBA-region wait inside try_next_item(), so there
        // the same 1ns skew is applied by hand.
        task drive_pins(bit en, bit [`FIFO_DATA_W-1:0] d);
`ifdef VERILATOR
                #1 vif.wr_en = en;
                   vif.wdata = d;
`else
                vif.drv_cb.wr_en <= en;
                vif.drv_cb.wdata <= d;
`endif
        endtask

        task run_phase(uvm_phase phase);
                drive_pins(1'b0, '0);
                @(vif.drv_cb);
                forever begin
                        seq_item_port.try_next_item(req);
                        if (req == null) begin
                                drive_pins(1'b0, '0);
                                @(vif.drv_cb);
                        end else begin
                                drive_pins(req.wr_en, req.wdata);
                                @(vif.drv_cb);                  // the DUT samples it on this edge
                                req.full     = vif.drv_cb.full;
                                req.accepted = req.wr_en && !req.full && (vif.drv_cb.wrst_n === 1'b1);
                                `uvm_info("WR_DRV", req.convert2string(), UVM_HIGH)
                                seq_item_port.item_done();
                        end
                end
        endtask

endclass: fifo_wr_driver
