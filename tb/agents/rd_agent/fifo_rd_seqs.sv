// ------------------------------------------------------------------
// Read-side sequences (run on the read agent's sequencer)
// ------------------------------------------------------------------

class fifo_rd_base_seq extends uvm_sequence #(fifo_rd_item);
        `uvm_object_utils(fifo_rd_base_seq)

        int unsigned num_items = 100;

        function new(string name = "fifo_rd_base_seq");
                super.new(name);
        endfunction

        task send_read(bit en);
                req = fifo_rd_item::type_id::create("req");
                start_item(req);
                req.rd_en = en;
                finish_item(req);
        endtask
endclass: fifo_rd_base_seq


// constrained random rd_en with a weighted rate
class fifo_rd_rand_seq extends fifo_rd_base_seq;
        `uvm_object_utils(fifo_rd_rand_seq)

        int unsigned rd_pct = 50;

        function new(string name = "fifo_rd_rand_seq");
                super.new(name);
        endfunction

        task body();
                repeat (num_items) begin
                        req = fifo_rd_item::type_id::create("req");
                        start_item(req);
                        req.rd_pct = rd_pct;
                        if (!req.randomize())
                                `uvm_fatal("RAND", "fifo_rd_item randomization failed")
                        finish_item(req);
                end
        endtask
endclass: fifo_rd_rand_seq


// blind back-to-back reads (rd_en held high)
class fifo_rd_burst_seq extends fifo_rd_base_seq;
        `uvm_object_utils(fifo_rd_burst_seq)

        function new(string name = "fifo_rd_burst_seq");
                super.new(name);
        endfunction

        task body();
                repeat (num_items) send_read(1'b1);
        endtask
endclass: fifo_rd_burst_seq


// random bursts of reads with random gaps
class fifo_rd_burst_mix_seq extends fifo_rd_base_seq;
        `uvm_object_utils(fifo_rd_burst_mix_seq)

        int unsigned num_bursts = 50;
        int unsigned max_len    = 2 * `FIFO_DEPTH;
        int unsigned max_gap    = 2 * `FIFO_DEPTH;

        function new(string name = "fifo_rd_burst_mix_seq");
                super.new(name);
        endfunction

        task body();
                int unsigned len, gap;
                repeat (num_bursts) begin
                        len = $urandom_range(max_len, 1);
                        gap = $urandom_range(max_gap, 0);
                        repeat (len) send_read(1'b1);
                        repeat (gap) send_read(1'b0);
                end
        endtask
endclass: fifo_rd_burst_mix_seq


// keep reading until the FIFO has looked empty for 'empty_streak' cycles in
// a row. Reading while empty is legal (gives underflow pulses), so this also
// exercises underflow at the end of every test.
class fifo_rd_drain_seq extends fifo_rd_base_seq;
        `uvm_object_utils(fifo_rd_drain_seq)

        int unsigned empty_streak = 8;
        int unsigned max_cycles   = 100000;

        function new(string name = "fifo_rd_drain_seq");
                super.new(name);
        endfunction

        task body();
                int unsigned streak = 0;
                int unsigned cycles = 0;
                while (streak < empty_streak && cycles < max_cycles) begin
                        send_read(1'b1);
                        streak = req.empty ? streak + 1 : 0;
                        cycles++;
                end
                if (streak < empty_streak)
                        `uvm_error("RD_SEQ", "drain: FIFO never went empty")
        endtask
endclass: fifo_rd_drain_seq


// n idle cycles
class fifo_rd_idle_seq extends fifo_rd_base_seq;
        `uvm_object_utils(fifo_rd_idle_seq)

        function new(string name = "fifo_rd_idle_seq");
                super.new(name);
        endfunction

        task body();
                repeat (num_items) send_read(1'b0);
        endtask
endclass: fifo_rd_idle_seq
