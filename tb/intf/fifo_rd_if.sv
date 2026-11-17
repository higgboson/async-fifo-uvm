`timescale 1ns/1ps
`ifndef FIFO_RD_IF_SV
`define FIFO_RD_IF_SV

`include "fifo_defs.svh"

// Read-side (rclk domain) pin interface. Same idea as fifo_wr_if.
interface fifo_rd_if(input bit rclk);

        import uvm_pkg::*;
        `include "uvm_macros.svh"

        logic                    rrst_n;
        logic                    rd_en = 1'b0;
        logic [`FIFO_DATA_W-1:0] rdata;
        logic                    empty;
        logic                    underflow;

        clocking drv_cb @(posedge rclk);
                default input #1step output #1;
                output rd_en;
                input  empty;
                input  rrst_n;
        endclocking: drv_cb

        clocking mon_cb @(posedge rclk);
                default input #1step;
                input rrst_n;
                input rd_en;
                input rdata;
                input empty;
                input underflow;
        endclocking: mon_cb

        modport DRV (clocking drv_cb);
        modport MON (clocking mon_cb);

        // ---------------- assertions (rclk domain) ----------------

        // empty must be high while in reset
        a_empty_rst : assert property (@(posedge rclk) (rrst_n === 1'b0) |-> (empty === 1'b1))
                else `uvm_error("SVA_RD", "empty is not high while rrst_n is asserted")

        a_no_x : assert property (@(posedge rclk) disable iff (rrst_n !== 1'b1)
                !$isunknown({empty, underflow, rdata}))
                else `uvm_error("SVA_RD", "X/Z on empty/underflow/rdata")

        a_in_known : assert property (@(posedge rclk) disable iff (rrst_n !== 1'b1)
                !$isunknown(rd_en))
                else `uvm_error("SVA_RD", "X/Z driven on rd_en")

        // underflow pulse: exactly one rclk after a read while empty
        a_udf_set : assert property (@(posedge rclk) disable iff (rrst_n !== 1'b1)
                (rd_en && empty) |=> underflow)
                else `uvm_error("SVA_RD", "read while empty did not raise underflow")

        a_udf_clr : assert property (@(posedge rclk) disable iff (rrst_n !== 1'b1)
                !(rd_en && empty) |=> !underflow)
                else `uvm_error("SVA_RD", "underflow raised without a read while empty")

        // rdata is a registered port: it may only change after an accepted read
        a_rdata_hold : assert property (@(posedge rclk) disable iff (rrst_n !== 1'b1)
                !(rd_en && !empty) |=> $stable(rdata))
                else `uvm_error("SVA_RD", "rdata changed without an accepted read")

        c_empty     : cover property (@(posedge rclk) disable iff (rrst_n !== 1'b1) empty);
        c_underflow : cover property (@(posedge rclk) disable iff (rrst_n !== 1'b1) underflow);
        c_empty_rel : cover property (@(posedge rclk) disable iff (rrst_n !== 1'b1) empty ##1 !empty);

endinterface: fifo_rd_if

`endif
