// Environment configuration: one object built by the test and handed down
// through uvm_config_db.
class fifo_env_cfg extends uvm_object;

        fifo_wr_agent_cfg        wr_cfg;
        fifo_rd_agent_cfg        rd_cfg;
        virtual fifo_clk_rst_if  clk_vif;

        bit  has_scoreboard = 1;
        bit  has_coverage   = 1;

        // clock periods applied at end_of_elaboration (plusargs override them)
        real wclk_period_ns = 10.0;
        real rclk_period_ns = 13.0;

        `uvm_object_utils(fifo_env_cfg)

        function new(string name = "fifo_env_cfg");
                super.new(name);
                wr_cfg = fifo_wr_agent_cfg::type_id::create("wr_cfg");
                rd_cfg = fifo_rd_agent_cfg::type_id::create("rd_cfg");
        endfunction

        function string convert2string();
                return $sformatf("wclk=%0.2fns rclk=%0.2fns (ratio wr/rd freq = %0.2f) depth=%0d sb=%0b cov=%0b",
                                 wclk_period_ns, rclk_period_ns, rclk_period_ns / wclk_period_ns,
                                 `FIFO_DEPTH, has_scoreboard, has_coverage);
        endfunction

endclass: fifo_env_cfg
