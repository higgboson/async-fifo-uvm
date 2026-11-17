// Read driver: one item = one rclk cycle (idle cycle when no item).
// Writes empty / accepted back into the item before item_done().
class fifo_rd_driver extends uvm_driver #(fifo_rd_item);

        `uvm_component_utils(fifo_rd_driver)

        virtual fifo_rd_if  vif;
        fifo_rd_agent_cfg      cfg;

        function new(string name, uvm_component parent);
                super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                if (!uvm_config_db #(fifo_rd_agent_cfg)::get(this, "", "cfg", cfg))
                        `uvm_fatal("NOCFG", "fifo_rd_agent_cfg not set for the read driver")
        endfunction

        function void connect_phase(uvm_phase phase);
                vif = cfg.vif;
        endfunction

        // Drive the pins for the next cycle. Normally through the clocking
        // block (1ns output skew). Verilator mis-schedules a clocking drive
        // issued after UVM's NBA-region wait inside try_next_item(), so there
        // the same 1ns skew is applied by hand.
        task drive_pins(bit en);
`ifdef VERILATOR
                #1 vif.rd_en = en;
`else
                vif.drv_cb.rd_en <= en;
`endif
        endtask

        task run_phase(uvm_phase phase);
                drive_pins(1'b0);
                @(vif.drv_cb);
                forever begin
                        seq_item_port.try_next_item(req);
                        if (req == null) begin
                                drive_pins(1'b0);
                                @(vif.drv_cb);
                        end else begin
                                drive_pins(req.rd_en);
                                @(vif.drv_cb);
                                req.empty    = vif.drv_cb.empty;
                                req.accepted = req.rd_en && !req.empty && (vif.drv_cb.rrst_n === 1'b1);
                                `uvm_info("RD_DRV", req.convert2string(), UVM_HIGH)
                                seq_item_port.item_done();
                        end
                end
        endtask

endclass: fifo_rd_driver
