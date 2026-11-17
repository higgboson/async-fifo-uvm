// Read-side transaction: one rclk cycle on the read port.
//
// rdata is registered in the DUT (valid one rclk after an accepted read),
// so the monitor reports the data of the PREVIOUS accepted read with
// data_valid=1, in the same item as this cycle's rd_en / empty.
class fifo_rd_item extends uvm_sequence_item;

        // ---- stimulus ----
        rand bit rd_en;

        int unsigned rd_pct = 50;
        // 'roll' is a helper so the rate knob works on every solver
        // (dist with variable weights is not portable)
        rand bit [6:0] roll;
        constraint c_rate { roll < 100; rd_en == (roll < rd_pct); }

        // ---- response / observed ----
        bit                    rst;         // monitor: first rclk cycle of a reset
        bit                    empty;       // empty as the DUT saw it on this edge
        bit                    underflow;
        bit                    accepted;    // rd_en && !empty && out of reset
        bit                    data_valid;  // rdata below belongs to the previous accepted read
        logic [`FIFO_DATA_W-1:0] rdata;     // 4-state on purpose: an X must not turn into 0

        `uvm_object_utils(fifo_rd_item)

        function new(string name = "fifo_rd_item");
                super.new(name);
        endfunction

        virtual function void do_copy(uvm_object rhs);
                fifo_rd_item t;
                super.do_copy(rhs);
                if (!$cast(t, rhs)) `uvm_fatal("CAST", "do_copy: wrong type")
                rd_en      = t.rd_en;
                rd_pct     = t.rd_pct;
                rst        = t.rst;
                empty      = t.empty;
                underflow  = t.underflow;
                accepted   = t.accepted;
                data_valid = t.data_valid;
                rdata      = t.rdata;
        endfunction

        virtual function string convert2string();
                if (rst) return "RD  [reset]";
                return $sformatf("RD  rd_en=%0b empty=%0b udf=%0b acc=%0b | dv=%0b rdata=%2h",
                                 rd_en, empty, underflow, accepted, data_valid, rdata);
        endfunction

endclass: fifo_rd_item
