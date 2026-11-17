`timescale 1ns/1ps
`ifndef ASYNC_FIFO_SVA_SV
`define ASYNC_FIFO_SVA_SV

// White-box CDC assertions, bound into the DUT (see the bind at the bottom).
// These look at the internal Gray pointers, which the black-box scoreboard
// cannot see:
//   * a Gray pointer launched across the boundary changes at most ONE bit
//     per clock in its own domain (this is what makes the 2FF sync safe)
//   * a pointer only moves when a transfer is accepted
//   * full / empty never assert spuriously out of reset
module async_fifo_sva #(
        parameter ADDR_WIDTH = 4
)(
        input                  wclk,
        input                  rclk,
        input                  wrst_n,
        input                  rrst_n,
        input                  wr_en,
        input                  rd_en,
        input                  full,
        input                  empty,
        input [ADDR_WIDTH:0]   wptr,
        input [ADDR_WIDTH:0]   rptr,
        input [ADDR_WIDTH:0]   wq2_rptr,    // rptr after the sync, in wclk
        input [ADDR_WIDTH:0]   rq2_wptr     // wptr after the sync, in rclk
);

        import uvm_pkg::*;
        `include "uvm_macros.svh"

        a_wptr_gray : assert property (@(posedge wclk) disable iff (wrst_n !== 1'b1)
                $countones(wptr ^ $past(wptr)) <= 1)
                else `uvm_error("SVA_CDC", $sformatf("wptr is not Gray: %b -> %b", $past(wptr), wptr))

        a_rptr_gray : assert property (@(posedge rclk) disable iff (rrst_n !== 1'b1)
                $countones(rptr ^ $past(rptr)) <= 1)
                else `uvm_error("SVA_CDC", $sformatf("rptr is not Gray: %b -> %b", $past(rptr), rptr))

        // the write pointer moves if and only if a write was accepted
        a_wptr_move : assert property (@(posedge wclk) disable iff (wrst_n !== 1'b1)
                (wr_en && !full) |=> (wptr != $past(wptr)))
                else `uvm_error("SVA_CDC", "accepted write did not advance wptr")

        a_wptr_hold : assert property (@(posedge wclk) disable iff (wrst_n !== 1'b1)
                !(wr_en && !full) |=> $stable(wptr))
                else `uvm_error("SVA_CDC", "wptr moved without an accepted write")

        a_rptr_move : assert property (@(posedge rclk) disable iff (rrst_n !== 1'b1)
                (rd_en && !empty) |=> (rptr != $past(rptr)))
                else `uvm_error("SVA_CDC", "accepted read did not advance rptr")

        a_rptr_hold : assert property (@(posedge rclk) disable iff (rrst_n !== 1'b1)
                !(rd_en && !empty) |=> $stable(rptr))
                else `uvm_error("SVA_CDC", "rptr moved without an accepted read")

        // a full FIFO stays full until the synchronized read pointer moves
        a_full_hold : assert property (@(posedge wclk) disable iff (wrst_n !== 1'b1)
                (full && $stable(wq2_rptr)) |=> full)
                else `uvm_error("SVA_CDC", "full released although the synced read pointer never moved")

        // an empty FIFO stays empty until the synchronized write pointer moves
        a_empty_hold : assert property (@(posedge rclk) disable iff (rrst_n !== 1'b1)
                (empty && $stable(rq2_wptr)) |=> empty)
                else `uvm_error("SVA_CDC", "empty released although the synced write pointer never moved")

        // both pointers wrapped at least once (both laps of the MSB)
        c_wptr_lap : cover property (@(posedge wclk) disable iff (wrst_n !== 1'b1)
                $rose(wptr[ADDR_WIDTH]));
        c_rptr_lap : cover property (@(posedge rclk) disable iff (rrst_n !== 1'b1)
                $rose(rptr[ADDR_WIDTH]));

endmodule: async_fifo_sva

// .* picks up the DUT ports and the internal wptr / rptr wires by name
bind async_fifo async_fifo_sva #(.ADDR_WIDTH(ADDR_WIDTH)) u_cdc_sva (.*);

`endif
