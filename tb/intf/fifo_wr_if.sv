`timescale 1ns/1ps
`ifndef FIFO_WR_IF_SV
`define FIFO_WR_IF_SV

`include "fifo_defs.svh"

// Write-side (wclk domain) pin interface.
//   drv_cb : what the write driver drives (and the status it reads back)
//   mon_cb : what the write monitor samples
// Drivers change the pins 1ns after the clock edge, monitors sample just
// BEFORE the edge (#1step), so the testbench is race free.
// The SVA at the bottom run in every test and report through UVM, so a
// failing assertion also fails the test.
interface fifo_wr_if(input bit wclk);

        import uvm_pkg::*;
        `include "uvm_macros.svh"

        logic                    wrst_n;
        logic                    wr_en = 1'b0;
        logic [`FIFO_DATA_W-1:0] wdata = '0;
        logic                    full;
        logic                    overflow;

        clocking drv_cb @(posedge wclk);
                default input #1step output #1;
                output wr_en;
                output wdata;
                input  full;
                input  wrst_n;
        endclocking: drv_cb

        clocking mon_cb @(posedge wclk);
                default input #1step;
                input wrst_n;
                input wr_en;
                input wdata;
                input full;
                input overflow;
        endclocking: mon_cb

        modport DRV (clocking drv_cb);
        modport MON (clocking mon_cb);

        // ---------------- assertions (wclk domain) ----------------
        // disabled while in reset (or still X at time 0)

        // full must come out of reset low
        a_full_rst : assert property (@(posedge wclk) (wrst_n === 1'b0) |-> (full === 1'b0))
                else `uvm_error("SVA_WR", "full is not low while wrst_n is asserted")

        // no X on the write-side outputs once out of reset
        a_no_x : assert property (@(posedge wclk) disable iff (wrst_n !== 1'b1)
                !$isunknown({full, overflow}))
                else `uvm_error("SVA_WR", "X/Z on full/overflow")

        // the testbench must never drive X into the DUT
        a_in_known : assert property (@(posedge wclk) disable iff (wrst_n !== 1'b1)
                !$isunknown(wr_en) && (!wr_en || !$isunknown(wdata)))
                else `uvm_error("SVA_WR", "X/Z driven on wr_en/wdata")

        // overflow pulse: exactly one wclk after a write while full
        a_ovf_set : assert property (@(posedge wclk) disable iff (wrst_n !== 1'b1)
                (wr_en && full) |=> overflow)
                else `uvm_error("SVA_WR", "write while full did not raise overflow")

        a_ovf_clr : assert property (@(posedge wclk) disable iff (wrst_n !== 1'b1)
                !(wr_en && full) |=> !overflow)
                else `uvm_error("SVA_WR", "overflow raised without a write while full")

        // so the report shows the corner states were reached
        c_full     : cover property (@(posedge wclk) disable iff (wrst_n !== 1'b1) full);
        c_overflow : cover property (@(posedge wclk) disable iff (wrst_n !== 1'b1) overflow);
        c_full_rel : cover property (@(posedge wclk) disable iff (wrst_n !== 1'b1) full ##1 !full);

endinterface: fifo_wr_if

`endif
