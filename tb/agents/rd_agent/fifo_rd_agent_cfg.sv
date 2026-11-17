class fifo_rd_agent_cfg extends uvm_object;

        virtual fifo_rd_if        vif;
        uvm_active_passive_enum   is_active = UVM_ACTIVE;

        `uvm_object_utils(fifo_rd_agent_cfg)

        function new(string name = "fifo_rd_agent_cfg");
                super.new(name);
        endfunction

endclass: fifo_rd_agent_cfg
