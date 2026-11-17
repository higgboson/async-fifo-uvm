// ------------------------------------------------------------------
// Tests
//
// fifo_base_test builds everything and runs fifo_base_vseq. Every other
// test only changes the clock periods and/or swaps the virtual sequence
// with a factory type override, so the env is never touched.
//
//   fifo_base_test        balanced random,           wclk 10  / rclk 13
//   fifo_wr_fast_test     write heavy, wclk faster,  wclk 4   / rclk 11
//   fifo_rd_fast_test     read heavy, rclk faster,   wclk 11  / rclk 4
//   fifo_fill_drain_test  directed full/empty/wrap,  wclk 7   / rclk 10
//   fifo_simul_rw_test    100% r+w at 3 levels,      wclk 10  / rclk 10.3
//   fifo_data_test        data patterns,             wclk 8   / rclk 11
//   fifo_burst_test       random bursts,             wclk 9   / rclk 6
//   fifo_reset_test       resets at full/partial/empty/mid-traffic
//   fifo_clk_sweep_test   clock ratio changed 6 times during the run
//
// Plusargs: +WCLK_NS=<real> +RCLK_NS=<real> override the periods,
//           +NUM_CYCLES=<n> changes the length of the random phases.
// ------------------------------------------------------------------

class fifo_base_test extends uvm_test;

        `uvm_component_utils(fifo_base_test)

        fifo_env      env;
        fifo_env_cfg  cfg;

        function new(string name, uvm_component parent);
                super.new(name, parent);
        endfunction

        // derived tests override this to pick clocks / switches
        virtual function void configure(fifo_env_cfg cfg);
        endfunction

        function void build_phase(uvm_phase phase);
                string s;
                super.build_phase(phase);
                cfg = fifo_env_cfg::type_id::create("cfg");

                if (!uvm_config_db #(virtual fifo_wr_if)::get(this, "", "wr_vif", cfg.wr_cfg.vif))
                        `uvm_fatal("NOVIF", "wr_vif not set in tb_top")
                if (!uvm_config_db #(virtual fifo_rd_if)::get(this, "", "rd_vif", cfg.rd_cfg.vif))
                        `uvm_fatal("NOVIF", "rd_vif not set in tb_top")
                if (!uvm_config_db #(virtual fifo_clk_rst_if)::get(this, "", "clk_vif", cfg.clk_vif))
                        `uvm_fatal("NOVIF", "clk_vif not set in tb_top")

                configure(cfg);

                if ($value$plusargs("WCLK_NS=%s", s)) cfg.wclk_period_ns = s.atoreal();
                if ($value$plusargs("RCLK_NS=%s", s)) cfg.rclk_period_ns = s.atoreal();
                if (cfg.wclk_period_ns < 3.0 || cfg.rclk_period_ns < 3.0)
                        `uvm_fatal("CFG", "clock periods below 3ns are not supported (1ns drive skew)")

                uvm_config_db #(fifo_env_cfg)::set(this, "env", "env_cfg", cfg);
                env = fifo_env::type_id::create("env", this);
        endfunction

        function void end_of_elaboration_phase(uvm_phase phase);
                cfg.clk_vif.set_periods(cfg.wclk_period_ns, cfg.rclk_period_ns);
                `uvm_info("TEST", {"config: ", cfg.convert2string()}, UVM_NONE)
                uvm_top.print_topology();
        endfunction

        // both domains reset together, released synchronously to their clocks
        task reset_phase(uvm_phase phase);
                phase.raise_objection(this);
                cfg.clk_vif.apply_reset(4, 4);
                phase.drop_objection(this);
        endtask

        task main_phase(uvm_phase phase);
                fifo_base_vseq vseq;
                phase.raise_objection(this);
                vseq = fifo_base_vseq::type_id::create("vseq");   // factory: tests swap the type
                `uvm_info("TEST", $sformatf("running %s", vseq.get_type_name()), UVM_NONE)
                vseq.start(env.vseqr);
                phase.get_objection().set_drain_time(this, 200ns);
                phase.drop_objection(this);
        endtask

        function void report_phase(uvm_phase phase);
                uvm_report_server rs = uvm_report_server::get_server();
                int errs = rs.get_severity_count(UVM_ERROR) + rs.get_severity_count(UVM_FATAL);
                if (errs == 0)
                        `uvm_info("RESULT", $sformatf("\n\n    ******** %s PASSED ********\n", get_type_name()), UVM_NONE)
                else
                        `uvm_info("RESULT", $sformatf("\n\n    ******** %s FAILED (%0d errors) ********\n",
                                                      get_type_name(), errs), UVM_NONE)
        endfunction

endclass: fifo_base_test


class fifo_wr_fast_test extends fifo_base_test;
        `uvm_component_utils(fifo_wr_fast_test)
        function new(string name, uvm_component parent); super.new(name, parent); endfunction
        virtual function void configure(fifo_env_cfg cfg);
                cfg.wclk_period_ns = 4.0;
                cfg.rclk_period_ns = 11.0;
                fifo_base_vseq::type_id::set_type_override(fifo_wr_heavy_vseq::get_type());
        endfunction
endclass: fifo_wr_fast_test


class fifo_rd_fast_test extends fifo_base_test;
        `uvm_component_utils(fifo_rd_fast_test)
        function new(string name, uvm_component parent); super.new(name, parent); endfunction
        virtual function void configure(fifo_env_cfg cfg);
                cfg.wclk_period_ns = 11.0;
                cfg.rclk_period_ns = 4.0;
                fifo_base_vseq::type_id::set_type_override(fifo_rd_heavy_vseq::get_type());
        endfunction
endclass: fifo_rd_fast_test


class fifo_fill_drain_test extends fifo_base_test;
        `uvm_component_utils(fifo_fill_drain_test)
        function new(string name, uvm_component parent); super.new(name, parent); endfunction
        virtual function void configure(fifo_env_cfg cfg);
                cfg.wclk_period_ns = 7.0;
                cfg.rclk_period_ns = 10.0;
                fifo_base_vseq::type_id::set_type_override(fifo_fill_drain_vseq::get_type());
        endfunction
endclass: fifo_fill_drain_test


class fifo_simul_rw_test extends fifo_base_test;
        `uvm_component_utils(fifo_simul_rw_test)
        function new(string name, uvm_component parent); super.new(name, parent); endfunction
        virtual function void configure(fifo_env_cfg cfg);
                cfg.wclk_period_ns = 10.0;
                cfg.rclk_period_ns = 10.3;
                fifo_base_vseq::type_id::set_type_override(fifo_simul_rw_vseq::get_type());
        endfunction
endclass: fifo_simul_rw_test


class fifo_data_test extends fifo_base_test;
        `uvm_component_utils(fifo_data_test)
        function new(string name, uvm_component parent); super.new(name, parent); endfunction
        virtual function void configure(fifo_env_cfg cfg);
                cfg.wclk_period_ns = 8.0;
                cfg.rclk_period_ns = 11.0;
                fifo_base_vseq::type_id::set_type_override(fifo_data_vseq::get_type());
        endfunction
endclass: fifo_data_test


class fifo_burst_test extends fifo_base_test;
        `uvm_component_utils(fifo_burst_test)
        function new(string name, uvm_component parent); super.new(name, parent); endfunction
        virtual function void configure(fifo_env_cfg cfg);
                cfg.wclk_period_ns = 9.0;
                cfg.rclk_period_ns = 6.0;
                fifo_base_vseq::type_id::set_type_override(fifo_burst_mix_vseq::get_type());
        endfunction
endclass: fifo_burst_test


class fifo_reset_test extends fifo_base_test;
        `uvm_component_utils(fifo_reset_test)
        function new(string name, uvm_component parent); super.new(name, parent); endfunction
        virtual function void configure(fifo_env_cfg cfg);
                cfg.wclk_period_ns = 10.0;
                cfg.rclk_period_ns = 7.0;
                fifo_base_vseq::type_id::set_type_override(fifo_reset_vseq::get_type());
        endfunction
endclass: fifo_reset_test


class fifo_clk_sweep_test extends fifo_base_test;
        `uvm_component_utils(fifo_clk_sweep_test)
        function new(string name, uvm_component parent); super.new(name, parent); endfunction
        virtual function void configure(fifo_env_cfg cfg);
                fifo_base_vseq::type_id::set_type_override(fifo_clk_sweep_vseq::get_type());
        endfunction
endclass: fifo_clk_sweep_test
