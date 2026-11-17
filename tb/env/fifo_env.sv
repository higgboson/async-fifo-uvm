class fifo_env extends uvm_env;

        `uvm_component_utils(fifo_env)

        fifo_env_cfg     cfg;
        fifo_wr_agent    wr_agt;
        fifo_rd_agent    rd_agt;
        fifo_scoreboard  sb;
        fifo_coverage    cov;
        fifo_vsequencer  vseqr;

        function new(string name, uvm_component parent);
                super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                if (!uvm_config_db #(fifo_env_cfg)::get(this, "", "env_cfg", cfg))
                        `uvm_fatal("NOCFG", "fifo_env_cfg not set for the env")

                uvm_config_db #(fifo_wr_agent_cfg)::set(this, "wr_agt*", "cfg", cfg.wr_cfg);
                uvm_config_db #(fifo_rd_agent_cfg)::set(this, "rd_agt*", "cfg", cfg.rd_cfg);
                uvm_config_db #(fifo_env_cfg)::set(this, "cov", "env_cfg", cfg);

                wr_agt = fifo_wr_agent::type_id::create("wr_agt", this);
                rd_agt = fifo_rd_agent::type_id::create("rd_agt", this);
                vseqr  = fifo_vsequencer::type_id::create("vseqr", this);
                if (cfg.has_scoreboard) sb  = fifo_scoreboard::type_id::create("sb", this);
                if (cfg.has_coverage)   cov = fifo_coverage::type_id::create("cov", this);
        endfunction

        function void connect_phase(uvm_phase phase);
                vseqr.wr_seqr = wr_agt.seqr;
                vseqr.rd_seqr = rd_agt.seqr;
                vseqr.cfg     = cfg;
                if (cfg.has_scoreboard) begin
                        wr_agt.mon.ap.connect(sb.wr_imp);
                        rd_agt.mon.ap.connect(sb.rd_imp);
                end
                if (cfg.has_coverage) begin
                        wr_agt.mon.ap.connect(cov.wr_imp);
                        rd_agt.mon.ap.connect(cov.rd_imp);
                end
        endfunction

endclass: fifo_env
