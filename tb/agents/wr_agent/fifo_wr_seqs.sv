// ------------------------------------------------------------------
// Write-side sequences (run on the write agent's sequencer)
// ------------------------------------------------------------------

class fifo_wr_base_seq extends uvm_sequence #(fifo_wr_item);
        `uvm_object_utils(fifo_wr_base_seq)

        int unsigned num_items = 100;

        function new(string name = "fifo_wr_base_seq");
                super.new(name);
        endfunction

        // one idle wclk cycle
        task send_idle();
                req = fifo_wr_item::type_id::create("req");
                start_item(req);
                req.wr_en = 1'b0;
                req.wdata = '0;
                finish_item(req);
        endtask

        // write one word, retry while the FIFO is full so no data is lost
        task send_word(bit [`FIFO_DATA_W-1:0] d, int unsigned max_tries = 10000);
                int unsigned tries = 0;
                do begin
                        req = fifo_wr_item::type_id::create("req");
                        start_item(req);
                        req.wr_en = 1'b1;
                        req.wdata = d;
                        finish_item(req);
                        tries++;
                end while (!req.accepted && tries < max_tries);
                if (!req.accepted)
                        `uvm_error("WR_SEQ", $sformatf("word %2h never accepted (FIFO stuck full?)", d))
        endtask
endclass: fifo_wr_base_seq


// constrained random: wr_en with a weighted rate, random data
class fifo_wr_rand_seq extends fifo_wr_base_seq;
        `uvm_object_utils(fifo_wr_rand_seq)

        int unsigned wr_pct = 50;

        function new(string name = "fifo_wr_rand_seq");
                super.new(name);
        endfunction

        task body();
                repeat (num_items) begin
                        req = fifo_wr_item::type_id::create("req");
                        start_item(req);
                        req.wr_pct = wr_pct;
                        if (!req.randomize())
                                `uvm_fatal("RAND", "fifo_wr_item randomization failed")
                        finish_item(req);
                end
        endtask
endclass: fifo_wr_rand_seq


// blind back-to-back writes (wr_en held high), used to hit full + overflow
class fifo_wr_burst_seq extends fifo_wr_base_seq;
        `uvm_object_utils(fifo_wr_burst_seq)

        function new(string name = "fifo_wr_burst_seq");
                super.new(name);
        endfunction

        task body();
                repeat (num_items) begin
                        req = fifo_wr_item::type_id::create("req");
                        start_item(req);
                        if (!req.randomize() with { wr_en == 1'b1; })
                                `uvm_fatal("RAND", "fifo_wr_item randomization failed")
                        finish_item(req);
                end
        endtask
endclass: fifo_wr_burst_seq


// random bursts: burst of random length, then a random gap
class fifo_wr_burst_mix_seq extends fifo_wr_base_seq;
        `uvm_object_utils(fifo_wr_burst_mix_seq)

        int unsigned num_bursts = 50;
        int unsigned max_len    = 2 * `FIFO_DEPTH;
        int unsigned max_gap    = 2 * `FIFO_DEPTH;

        function new(string name = "fifo_wr_burst_mix_seq");
                super.new(name);
        endfunction

        task body();
                int unsigned len, gap;
                repeat (num_bursts) begin
                        len = $urandom_range(max_len, 1);
                        gap = $urandom_range(max_gap, 0);
                        repeat (len) begin
                                req = fifo_wr_item::type_id::create("req");
                                start_item(req);
                                if (!req.randomize() with { wr_en == 1'b1; })
                                        `uvm_fatal("RAND", "fifo_wr_item randomization failed")
                                finish_item(req);
                        end
                        repeat (gap) send_idle();
                end
        endtask
endclass: fifo_wr_burst_mix_seq


// directed data: every word in 'data' gets into the FIFO (retries on full)
class fifo_wr_pattern_seq extends fifo_wr_base_seq;
        `uvm_object_utils(fifo_wr_pattern_seq)

        bit [`FIFO_DATA_W-1:0] data[$];

        function new(string name = "fifo_wr_pattern_seq");
                super.new(name);
        endfunction

        // 00, FF, 55, AA, walking 1, walking 0, then every value once
        function void build_default_patterns();
                data.delete();
                data.push_back('0);
                data.push_back('1);
                data.push_back({(`FIFO_DATA_W/2){2'b01}});
                data.push_back({(`FIFO_DATA_W/2){2'b10}});
                for (int i = 0; i < `FIFO_DATA_W; i++) data.push_back(1 << i);
                for (int i = 0; i < `FIFO_DATA_W; i++) data.push_back(~(1 << i));
                for (int i = 0; i < (1 << `FIFO_DATA_W); i++) data.push_back(i);
        endfunction

        task body();
                if (data.size() == 0) build_default_patterns();
                foreach (data[i]) send_word(data[i]);
        endtask
endclass: fifo_wr_pattern_seq


// n idle cycles
class fifo_wr_idle_seq extends fifo_wr_base_seq;
        `uvm_object_utils(fifo_wr_idle_seq)

        function new(string name = "fifo_wr_idle_seq");
                super.new(name);
        endfunction

        task body();
                repeat (num_items) send_idle();
        endtask
endclass: fifo_wr_idle_seq
