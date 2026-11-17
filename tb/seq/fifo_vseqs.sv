// ------------------------------------------------------------------
// Virtual sequences: coordinate the write and read sequencers (two
// independent clock domains) plus the clock / reset interface.
//
// Every virtual sequence ends with drain(): stop writing, read until the
// FIFO is empty. That way the scoreboard has seen every word come out,
// and reading while empty gives underflow coverage for free.
// ------------------------------------------------------------------

class fifo_base_vseq extends uvm_sequence;
        `uvm_object_utils(fifo_base_vseq)
        `uvm_declare_p_sequencer(fifo_vsequencer)

        localparam int D = `FIFO_DEPTH;

        // cycles of random traffic per domain (override with +NUM_CYCLES=n)
        int unsigned num_cycles = 4000;
        int unsigned wr_pct     = 50;
        int unsigned rd_pct     = 50;

        function new(string name = "fifo_base_vseq");
                super.new(name);
        endfunction

        task pre_body();
                void'($value$plusargs("NUM_CYCLES=%d", num_cycles));
        endtask

        // ---- small helpers so derived vseqs read like a test plan ----
        task wr_rand(int unsigned n, int unsigned pct);
                fifo_wr_rand_seq s = fifo_wr_rand_seq::type_id::create("wr_rand");
                s.num_items = n;
                s.wr_pct    = pct;
                s.start(p_sequencer.wr_seqr, this);
        endtask

        task rd_rand(int unsigned n, int unsigned pct);
                fifo_rd_rand_seq s = fifo_rd_rand_seq::type_id::create("rd_rand");
                s.num_items = n;
                s.rd_pct    = pct;
                s.start(p_sequencer.rd_seqr, this);
        endtask

        task wr_burst(int unsigned n);
                fifo_wr_burst_seq s = fifo_wr_burst_seq::type_id::create("wr_burst");
                s.num_items = n;
                s.start(p_sequencer.wr_seqr, this);
        endtask

        task rd_burst(int unsigned n);
                fifo_rd_burst_seq s = fifo_rd_burst_seq::type_id::create("rd_burst");
                s.num_items = n;
                s.start(p_sequencer.rd_seqr, this);
        endtask

        task wr_idle(int unsigned n);
                fifo_wr_idle_seq s = fifo_wr_idle_seq::type_id::create("wr_idle");
                s.num_items = n;
                s.start(p_sequencer.wr_seqr, this);
        endtask

        task rd_idle(int unsigned n);
                fifo_rd_idle_seq s = fifo_rd_idle_seq::type_id::create("rd_idle");
                s.num_items = n;
                s.start(p_sequencer.rd_seqr, this);
        endtask

        // write exactly n words into the FIFO (retries on full, no data lost)
        task wr_words(int unsigned n);
                fifo_wr_pattern_seq s = fifo_wr_pattern_seq::type_id::create("wr_words");
                repeat (n) s.data.push_back($urandom);
                s.start(p_sequencer.wr_seqr, this);
        endtask

        task drain();
                fifo_rd_drain_seq s = fifo_rd_drain_seq::type_id::create("drain");
                s.start(p_sequencer.rd_seqr, this);
        endtask

        task set_clocks(real wclk_ns, real rclk_ns);
                `uvm_info("VSEQ", $sformatf("clock ratio change: wclk=%0.2fns rclk=%0.2fns", wclk_ns, rclk_ns), UVM_LOW)
                p_sequencer.cfg.clk_vif.set_periods(wclk_ns, rclk_ns);
        endtask

        // default body: balanced random traffic on both sides, then drain
        task body();
                fork
                        wr_rand(num_cycles, wr_pct);
                        rd_rand(num_cycles, rd_pct);
                join
                drain();
        endtask
endclass: fifo_base_vseq


// write side much busier than the read side -> full, overflow
class fifo_wr_heavy_vseq extends fifo_base_vseq;
        `uvm_object_utils(fifo_wr_heavy_vseq)
        function new(string name = "fifo_wr_heavy_vseq");
                super.new(name);
                wr_pct = 90;
                rd_pct = 35;
        endfunction
endclass: fifo_wr_heavy_vseq


// read side much busier than the write side -> empty, underflow
class fifo_rd_heavy_vseq extends fifo_base_vseq;
        `uvm_object_utils(fifo_rd_heavy_vseq)
        function new(string name = "fifo_rd_heavy_vseq");
                super.new(name);
                wr_pct = 35;
                rd_pct = 90;
        endfunction
endclass: fifo_rd_heavy_vseq


// directed: fill to full (+ overflow), drain to empty (+ underflow), 3 laps
// so both pointers wrap around more than once
class fifo_fill_drain_vseq extends fifo_base_vseq;
        `uvm_object_utils(fifo_fill_drain_vseq)
        function new(string name = "fifo_fill_drain_vseq");
                super.new(name);
        endfunction

        task body();
                repeat (3) begin
                        wr_burst(D + 4);        // last writes hit a full FIFO -> overflow
                        rd_idle(6);             // let wptr cross into rclk
                        rd_burst(D);            // back-to-back reads
                        drain();                // reads while empty -> underflow
                        wr_idle(6);             // let rptr cross into wclk (full releases)
                end
                // half fill / half drain, so the pointers stop at odd places
                repeat (4) begin
                        wr_words(D / 2 + $urandom_range(3));
                        drain();
                end
        endtask
endclass: fifo_fill_drain_vseq


// both sides at 100% from three starting levels (empty, half, almost full)
class fifo_simul_rw_vseq extends fifo_base_vseq;
        `uvm_object_utils(fifo_simul_rw_vseq)
        function new(string name = "fifo_simul_rw_vseq");
                super.new(name);
        endfunction

        task body();
                int unsigned start_level[3] = '{0, D/2, D-2};
                foreach (start_level[i]) begin
                        if (start_level[i] > 0) begin
                                wr_words(start_level[i]);
                                rd_idle(6);
                        end
                        fork
                                wr_burst(num_cycles / 4);
                                rd_burst(num_cycles / 4);
                        join
                        drain();
                end
        endtask
endclass: fifo_simul_rw_vseq


// data patterns (00, FF, 55, AA, walking 1/0, every value) while reading randomly
class fifo_data_vseq extends fifo_base_vseq;
        `uvm_object_utils(fifo_data_vseq)
        function new(string name = "fifo_data_vseq");
                super.new(name);
        endfunction

        task body();
                fifo_wr_pattern_seq pat = fifo_wr_pattern_seq::type_id::create("pat");
                fork
                        pat.start(p_sequencer.wr_seqr, this);
                        rd_rand(1500, 60);
                join
                drain();
        endtask
endclass: fifo_data_vseq


// random bursts on both sides
class fifo_burst_mix_vseq extends fifo_base_vseq;
        `uvm_object_utils(fifo_burst_mix_vseq)
        function new(string name = "fifo_burst_mix_vseq");
                super.new(name);
        endfunction

        task body();
                fifo_wr_burst_mix_seq w = fifo_wr_burst_mix_seq::type_id::create("w");
                fifo_rd_burst_mix_seq r = fifo_rd_burst_mix_seq::type_id::create("r");
                w.num_bursts = 80;
                r.num_bursts = 80;
                fork
                        w.start(p_sequencer.wr_seqr, this);
                        r.start(p_sequencer.rd_seqr, this);
                join
                drain();
        endtask
endclass: fifo_burst_mix_vseq


// resets: at empty, at full, at a partial level, and randomly in the middle
// of traffic (both domains reset together, asynchronously)
class fifo_reset_vseq extends fifo_base_vseq;
        `uvm_object_utils(fifo_reset_vseq)
        function new(string name = "fifo_reset_vseq");
                super.new(name);
        endfunction

        task do_reset();
                `uvm_info("VSEQ", "applying reset to both domains", UVM_LOW)
                p_sequencer.cfg.clk_vif.apply_reset($urandom_range(6, 2), $urandom_range(6, 2));
        endtask

        task body();
                // reset at full
                wr_burst(D + 2);
                rd_idle(6);
                do_reset();
                wr_words(5); drain();

                // reset at a partial level
                wr_words(D / 2);
                rd_idle(6);
                do_reset();
                wr_words(5); drain();

                // reset at empty
                do_reset();
                wr_words(5); drain();

                // resets landing in the middle of random traffic
                fork
                        wr_rand(num_cycles, 60);
                        rd_rand(num_cycles, 55);
                        begin
                                repeat (5) begin
                                        #($urandom_range(3000, 300) * 1ns);
                                        do_reset();
                                end
                        end
                join
                drain();
        endtask
endclass: fifo_reset_vseq


// sweep the clock ratio during the test: write much faster, read much
// faster, near-equal (slowly drifting phase, the nastiest case for CDC)
class fifo_clk_sweep_vseq extends fifo_base_vseq;
        `uvm_object_utils(fifo_clk_sweep_vseq)
        function new(string name = "fifo_clk_sweep_vseq");
                super.new(name);
        endfunction

        task body();
                real wp[6] = '{10.0,  4.0, 17.0, 10.0,  6.0, 12.0};
                real rp[6] = '{10.1, 17.0,  4.0,  7.3, 9.1,  6.5};
                foreach (wp[i]) begin
                        set_clocks(wp[i], rp[i]);
                        fork
                                wr_rand(num_cycles / 4, 65);
                                rd_rand(num_cycles / 4, 65);
                        join
                        drain();
                end
        endtask
endclass: fifo_clk_sweep_vseq
