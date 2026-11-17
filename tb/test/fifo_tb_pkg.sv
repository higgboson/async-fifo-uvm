`timescale 1ns/1ps

package fifo_tb_pkg;

        import uvm_pkg::*;
        `include "uvm_macros.svh"

        `include "fifo_defs.svh"

        // one analysis imp per monitor, shared by the scoreboard and coverage
        `uvm_analysis_imp_decl(_wr)
        `uvm_analysis_imp_decl(_rd)

        // write agent
        `include "fifo_wr_item.sv"
        `include "fifo_wr_agent_cfg.sv"
        `include "fifo_wr_driver.sv"
        `include "fifo_wr_monitor.sv"
        `include "fifo_wr_agent.sv"
        `include "fifo_wr_seqs.sv"

        // read agent
        `include "fifo_rd_item.sv"
        `include "fifo_rd_agent_cfg.sv"
        `include "fifo_rd_driver.sv"
        `include "fifo_rd_monitor.sv"
        `include "fifo_rd_agent.sv"
        `include "fifo_rd_seqs.sv"

        // env
        `include "fifo_env_cfg.sv"
        `include "fifo_scoreboard.sv"
        `include "fifo_coverage.sv"
        `include "fifo_vsequencer.sv"
        `include "fifo_env.sv"

        // virtual sequences + tests
        `include "fifo_vseqs.sv"
        `include "fifo_tests.sv"

endpackage: fifo_tb_pkg
