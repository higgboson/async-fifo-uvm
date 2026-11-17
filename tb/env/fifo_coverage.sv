// ------------------------------------------------------------------
// Functional coverage collector (subscribes to both monitors)
//
//   cg_wr    : write port, full flag, overflow, occupancy, clock ratio
//   cg_rd    : read port, empty flag, underflow, occupancy, clock ratio
//   cg_data  : data patterns that actually went into the FIFO
//   cg_ptr   : every pointer value on both laps (wrap-around)
//   cg_reset : occupancy and clock ratio when a reset hit
//
// The clock-ratio coverpoint is what makes this an ASYNC FIFO coverage
// model: we want full/overflow and empty/underflow under write-faster,
// read-faster and near-equal clocks, not just under one lucky ratio.
// ------------------------------------------------------------------
class fifo_coverage extends uvm_component;

        `uvm_component_utils(fifo_coverage)

        uvm_analysis_imp_wr #(fifo_wr_item, fifo_coverage) wr_imp;
        uvm_analysis_imp_rd #(fifo_rd_item, fifo_coverage) rd_imp;

        localparam int D = `FIFO_DEPTH;

        typedef enum int { RD_MUCH_FASTER, RD_FASTER, SIMILAR, WR_FASTER, WR_MUCH_FASTER } ratio_e;

        fifo_env_cfg  cfg;
        fifo_wr_item  wr_t;
        fifo_rd_item  rd_t;

        int           level;        // accepted writes - accepted reads
        int unsigned  wr_ptr;       // mirror of the DUT pointers, 0 .. 2*D-1
        int unsigned  rd_ptr;
        ratio_e       ratio;
        bit           in_reset;

        covergroup cg_wr;
                option.per_instance = 1;
                WR       : coverpoint wr_t.wr_en;
                FULL     : coverpoint wr_t.full;
                OVF      : coverpoint wr_t.overflow { bins seen   = {1};
                                                      bins burst3 = (1 [*3]); }
                WR_BURST : coverpoint wr_t.wr_en    { bins depth_burst = (1 [*D]); }
                FULL_TR  : coverpoint wr_t.full     { bins become_full = (0 => 1);
                                                      bins leave_full  = (1 => 0); }
                LEVEL    : coverpoint level {
                        bins empty = {0};
                        bins low   = {[1     : D/4-1]};
                        bins mid   = {[D/4   : 3*D/4-1]};
                        bins high  = {[3*D/4 : D-1]};
                        bins full  = {D};
                }
                RATIO    : coverpoint ratio;

                WRxFULL       : cross WR, FULL;               // write while full = overflow attempt
                LEVELxWR      : cross LEVEL, WR;
                RATIOxWRxFULL : cross RATIO, WR, FULL;        // overflow attempt under every clock ratio
        endgroup

        covergroup cg_rd;
                option.per_instance = 1;
                RD       : coverpoint rd_t.rd_en;
                EMPTY    : coverpoint rd_t.empty;
                UDF      : coverpoint rd_t.underflow { bins seen   = {1};
                                                       bins burst3 = (1 [*3]); }
                RD_BURST : coverpoint rd_t.rd_en     { bins depth_burst = (1 [*D]); }
                EMPTY_TR : coverpoint rd_t.empty     { bins become_empty = (0 => 1);
                                                       bins leave_empty  = (1 => 0); }
                LEVEL    : coverpoint level {
                        bins empty = {0};
                        bins low   = {[1     : D/4-1]};
                        bins mid   = {[D/4   : 3*D/4-1]};
                        bins high  = {[3*D/4 : D-1]};
                        bins full  = {D};
                }
                RATIO    : coverpoint ratio;

                RDxEMPTY       : cross RD, EMPTY;             // read while empty = underflow attempt
                LEVELxRD       : cross LEVEL, RD;
                RATIOxRDxEMPTY : cross RATIO, RD, EMPTY;
        endgroup

        // sampled only for accepted writes
        covergroup cg_data;
                option.per_instance = 1;
                WDATA : coverpoint wr_t.wdata {
                        bins zero    = {8'h00};
                        bins ones    = {8'hFF};
                        bins h55     = {8'h55};
                        bins hAA     = {8'hAA};
                        bins walk1[] = {8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80};
                        bins walk0[] = {8'hFE, 8'hFD, 8'hFB, 8'hF7, 8'hEF, 8'hDF, 8'hBF, 8'h7F};
                        bins range[8] = {[8'h00 : 8'hFF]};
                }
        endgroup

        covergroup cg_ptr with function sample(int unsigned ptr, bit is_wr);
                option.per_instance = 1;
                WPTR : coverpoint ptr iff (is_wr)  { bins p[] = {[0 : 2*D-1]}; }
                RPTR : coverpoint ptr iff (!is_wr) { bins p[] = {[0 : 2*D-1]}; }
        endgroup

        covergroup cg_reset;
                option.per_instance = 1;
                LEVEL_AT_RST : coverpoint level {
                        bins empty   = {0};
                        bins partial = {[1 : D-1]};
                        bins full    = {D};
                }
                RATIO : coverpoint ratio;
        endgroup

        function new(string name, uvm_component parent);
                super.new(name, parent);
                wr_imp   = new("wr_imp", this);
                rd_imp   = new("rd_imp", this);
                cg_wr    = new();
                cg_rd    = new();
                cg_data  = new();
                cg_ptr   = new();
                cg_reset = new();
        endfunction

        function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                if (!uvm_config_db #(fifo_env_cfg)::get(this, "", "env_cfg", cfg))
                        `uvm_fatal("NOCFG", "fifo_env_cfg not set for the coverage collector")
        endfunction

        // frequency ratio f_wclk / f_rclk = rclk_period / wclk_period
        function void update_ratio();
                real r = cfg.clk_vif.rclk_period_ns / cfg.clk_vif.wclk_period_ns;
                if      (r <  0.5)  ratio = RD_MUCH_FASTER;
                else if (r <  0.85) ratio = RD_FASTER;
                else if (r <= 1.18) ratio = SIMILAR;
                else if (r <= 2.0)  ratio = WR_FASTER;
                else                ratio = WR_MUCH_FASTER;
        endfunction

        function void on_reset();
                if (!in_reset) begin
                        update_ratio();
                        cg_reset.sample();
                end
                in_reset = 1'b1;
                level    = 0;
                wr_ptr   = 0;
                rd_ptr   = 0;
        endfunction

        function void write_wr(fifo_wr_item t);
                if (t.rst) begin on_reset(); return; end
                in_reset = 1'b0;
                wr_t = t;
                update_ratio();
                cg_wr.sample();
                if (t.accepted) begin
                        cg_data.sample();
                        cg_ptr.sample(wr_ptr, 1'b1);
                        wr_ptr = (wr_ptr + 1) % (2 * D);
                        level++;
                end
        endfunction

        function void write_rd(fifo_rd_item t);
                if (t.rst) begin on_reset(); return; end
                in_reset = 1'b0;
                rd_t = t;
                update_ratio();
                cg_rd.sample();
                if (t.accepted) begin
                        cg_ptr.sample(rd_ptr, 1'b0);
                        rd_ptr = (rd_ptr + 1) % (2 * D);
                        if (level > 0) level--;
                end
        endfunction

        function void report_phase(uvm_phase phase);
                `uvm_info("COV", $sformatf({"\n---------------- functional coverage ----------------",
                                            "\n cg_wr    : %6.2f %%",
                                            "\n cg_rd    : %6.2f %%",
                                            "\n cg_data  : %6.2f %%",
                                            "\n cg_ptr   : %6.2f %%",
                                            "\n cg_reset : %6.2f %%",
                                            "\n (per-test numbers, merge the regression in IMC / urg / vcover)",
                                            "\n-----------------------------------------------------"},
                                           cg_wr.get_inst_coverage(), cg_rd.get_inst_coverage(),
                                           cg_data.get_inst_coverage(), cg_ptr.get_inst_coverage(),
                                           cg_reset.get_inst_coverage()), UVM_NONE)
        endfunction

endclass: fifo_coverage
