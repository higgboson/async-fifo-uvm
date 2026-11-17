// ------------------------------------------------------------------
// Scoreboard
//
// An async FIFO is not cycle-predictable from the outside: full / empty
// release 2-3 cycles late depending on the clock phase. So instead of a
// cycle-accurate model the scoreboard checks what MUST hold no matter
// how the clocks line up:
//
//   1. data integrity + ordering : every word read out is the oldest word
//                                  written and not yet read (queue model)
//   2. no internal overflow      : a write is never accepted while the FIFO
//                                  really holds DEPTH words
//   3. no internal underflow     : a read is never accepted while the FIFO
//                                  is really empty
//   4. no phantom data           : rdata only "arrives" for an accepted read
//   5. reset                     : a reset in either domain flushes everything
//
// "Really holds" = accepted writes - accepted reads, counted at the moment
// each monitor sees them. Because the DUT flags are pessimistic, checks 2
// and 3 can never false-fire on a correct design, but they catch broken
// Gray coding, a missing synchronizer stage, a wrong full compare, etc.
//
// Flag *timing* (overflow/underflow pulses, rdata hold) is checked by the
// SVA in the interfaces, the pointer CDC rules by the bound SVA module.
// ------------------------------------------------------------------
class fifo_scoreboard extends uvm_scoreboard;

        `uvm_component_utils(fifo_scoreboard)

        uvm_analysis_imp_wr #(fifo_wr_item, fifo_scoreboard) wr_imp;
        uvm_analysis_imp_rd #(fifo_rd_item, fifo_scoreboard) rd_imp;

        localparam int DEPTH = `FIFO_DEPTH;

        // words written and not yet seen at rdata (includes reads in flight)
        bit [`FIFO_DATA_W-1:0] exp_q[$];
        int                    pending_reads;   // accepted reads whose data is not out yet

        // statistics
        int unsigned n_wr_acc, n_wr_blocked, n_rd_acc, n_rd_blocked;
        int unsigned n_match, n_mismatch, n_resets, n_flushed;
        int unsigned max_level;

        function new(string name, uvm_component parent);
                super.new(name, parent);
                wr_imp = new("wr_imp", this);
                rd_imp = new("rd_imp", this);
        endfunction

        function int level();
                return exp_q.size() - pending_reads;
        endfunction

        function void flush_q(string who);
                if (exp_q.size() > 0)
                        `uvm_info("SB", $sformatf("reset seen in %s domain, flushing %0d words",
                                                  who, exp_q.size()), UVM_MEDIUM)
                n_flushed    += exp_q.size();
                exp_q.delete();
                pending_reads = 0;
        endfunction

        // ---------------- write side ----------------
        function void write_wr(fifo_wr_item t);
                if (t.rst) begin
                        n_resets++;
                        flush_q("write");
                        return;
                end
                if (t.wr_en && t.full) n_wr_blocked++;
                if (!t.accepted) return;

                if (level() >= DEPTH)
                        `uvm_error("SB_OVF", $sformatf("write of %2h accepted while the FIFO already holds %0d words",
                                                       t.wdata, level()))
                exp_q.push_back(t.wdata);
                n_wr_acc++;
                if (level() > max_level) max_level = level();
        endfunction

        // ---------------- read side ----------------
        function void write_rd(fifo_rd_item t);
                bit [`FIFO_DATA_W-1:0] exp;

                if (t.rst) begin
                        flush_q("read");
                        return;
                end

                // data of the read accepted on the previous rclk edge
                if (t.data_valid) begin
                        if (exp_q.size() == 0 || pending_reads == 0) begin
                                `uvm_error("SB_PHANTOM", $sformatf("rdata %2h came out but no read was outstanding", t.rdata))
                        end else begin
                                exp = exp_q.pop_front();
                                pending_reads--;
                                if (t.rdata !== exp) begin
                                        n_mismatch++;
                                        `uvm_error("SB_DATA", $sformatf("read #%0d: expected %2h, got %2h",
                                                                        n_match + n_mismatch, exp, t.rdata))
                                end else begin
                                        n_match++;
                                        `uvm_info("SB", $sformatf("read #%0d: %2h OK", n_match, t.rdata), UVM_HIGH)
                                end
                        end
                end

                if (t.rd_en && t.empty) n_rd_blocked++;
                if (t.accepted) begin
                        if (level() <= 0)
                                `uvm_error("SB_UDF", "read accepted while the FIFO is really empty")
                        else
                                pending_reads++;
                        n_rd_acc++;
                end
        endfunction

        // ---------------- end of test ----------------
        function void check_phase(uvm_phase phase);
                super.check_phase(phase);
                if (n_match == 0)
                        `uvm_error("SB_NOCHK", "no data word was checked, the test is not testing anything")
                if (level() != 0)
                        `uvm_info("SB", $sformatf("%0d words still inside the FIFO at the end (test did not drain)",
                                                  level()), UVM_LOW)
        endfunction

        function void report_phase(uvm_phase phase);
                `uvm_info("SB", $sformatf({"\n---------------- scoreboard ----------------",
                                           "\n writes accepted   : %0d",
                                           "\n writes while full : %0d (overflow attempts)",
                                           "\n reads accepted    : %0d",
                                           "\n reads while empty : %0d (underflow attempts)",
                                           "\n words compared    : %0d   mismatches: %0d",
                                           "\n resets            : %0d   words flushed: %0d",
                                           "\n max occupancy     : %0d / %0d",
                                           "\n--------------------------------------------"},
                                          n_wr_acc, n_wr_blocked, n_rd_acc, n_rd_blocked,
                                          n_match, n_mismatch, n_resets, n_flushed,
                                          max_level, DEPTH), UVM_NONE)
        endfunction

endclass: fifo_scoreboard
