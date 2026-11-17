// Write-side transaction: one wclk cycle on the write port.
//
// The driver fills the "response" fields after the cycle, so a sequence
// can see whether its write was really accepted (needed for directed
// sequences that must not lose data when the FIFO is full).
// The monitor fills the "observed" fields.
class fifo_wr_item extends uvm_sequence_item;

        // ---- stimulus ----
        rand bit                    wr_en;
        rand bit [`FIFO_DATA_W-1:0] wdata;

        // knob for the default constraint (chance of wr_en=1, in %)
        int unsigned wr_pct = 50;
        // 'roll' is a helper so the rate knob works on every solver
        // (dist with variable weights is not portable)
        rand bit [6:0] roll;
        constraint c_rate { roll < 100; wr_en == (roll < wr_pct); }

        // ---- response / observed ----
        bit  rst;           // monitor: first wclk cycle of a reset
        bit  full;          // full as the DUT saw it on this edge
        bit  overflow;
        bit  accepted;      // wr_en && !full && out of reset

        `uvm_object_utils(fifo_wr_item)

        function new(string name = "fifo_wr_item");
                super.new(name);
        endfunction

        virtual function void do_copy(uvm_object rhs);
                fifo_wr_item t;
                super.do_copy(rhs);
                if (!$cast(t, rhs)) `uvm_fatal("CAST", "do_copy: wrong type")
                wr_en    = t.wr_en;
                wdata    = t.wdata;
                wr_pct   = t.wr_pct;
                rst      = t.rst;
                full     = t.full;
                overflow = t.overflow;
                accepted = t.accepted;
        endfunction

        virtual function string convert2string();
                if (rst) return "WR  [reset]";
                return $sformatf("WR  wr_en=%0b wdata=%2h full=%0b ovf=%0b acc=%0b",
                                 wr_en, wdata, full, overflow, accepted);
        endfunction

endclass: fifo_wr_item
