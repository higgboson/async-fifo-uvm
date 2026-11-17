`timescale 1ns/1ps
//------------------------------------------------------------------
// Asynchronous (dual-clock) FIFO, plain Verilog-2001
//
//   depth  = 2**ADDR_WIDTH   (16 entries by default)
//   width  = DATA_WIDTH      (8 bits by default)
//   resets = asynchronous assert, active low, one per clock domain
//            (wrst_n in the wclk domain, rrst_n in the rclk domain;
//             assert both together, release each synchronously)
//
//   Classic Gray-code pointer architecture (Cummings, SNUG 2002):
//
//      wclk domain                         rclk domain
//   +----------------+   wptr (gray)   +----------------+
//   | fifo_wptr_full |----> 2FF sync ->| fifo_rptr_empty|
//   |  binary + gray |                 |  binary + gray |
//   |  full, ovf     |<- 2FF sync <----|  empty, udf    |
//   +----------------+   rptr (gray)   +----------------+
//            |  waddr                         | raddr
//            +----------> fifo_mem <----------+
//                 (write port wclk, registered read port rclk)
//
//   * Pointers are ADDR_WIDTH+1 bits; the extra MSB is the lap bit.
//   * Only Gray-coded pointers cross the clock boundary, so at most one
//     bit changes per clock and a metastable sample resolves to either
//     the old or the new value, never a corrupted one.
//   * full  is computed in wclk from the synchronized read pointer and
//     empty in rclk from the synchronized write pointer. Both are
//     PESSIMISTIC: they assert immediately but release 2-3 cycles late.
//     The FIFO can never overflow or underflow internally.
//   * A write while full / a read while empty is ignored and a one-cycle
//     overflow / underflow pulse is raised in that domain (1 cycle late).
//   * rdata is registered: valid ONE rclk cycle after an accepted read.
//------------------------------------------------------------------
module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4            // must be >= 2
)(
    // write domain
    input                       wclk,
    input                       wrst_n,
    input                       wr_en,
    input      [DATA_WIDTH-1:0] wdata,
    output                      full,
    output                      overflow,   // wr_en was high while full  (1 wclk late)

    // read domain
    input                       rclk,
    input                       rrst_n,
    input                       rd_en,
    output     [DATA_WIDTH-1:0] rdata,
    output                      empty,
    output                      underflow   // rd_en was high while empty (1 rclk late)
);

    wire [ADDR_WIDTH-1:0] waddr, raddr;
    wire [ADDR_WIDTH:0]   wptr, rptr;           // gray, launched from their own domain
    wire [ADDR_WIDTH:0]   wq2_rptr, rq2_wptr;   // gray, after the 2FF synchronizers
    wire                  do_write, do_read;

    // read pointer -> write domain
    fifo_sync_2ff #(.WIDTH(ADDR_WIDTH+1)) u_sync_r2w (
        .clk   (wclk),
        .rst_n (wrst_n),
        .d     (rptr),
        .q     (wq2_rptr)
    );

    // write pointer -> read domain
    fifo_sync_2ff #(.WIDTH(ADDR_WIDTH+1)) u_sync_w2r (
        .clk   (rclk),
        .rst_n (rrst_n),
        .d     (wptr),
        .q     (rq2_wptr)
    );

    fifo_wptr_full #(.ADDR_WIDTH(ADDR_WIDTH)) u_wptr_full (
        .wclk     (wclk),
        .wrst_n   (wrst_n),
        .wr_en    (wr_en),
        .wq2_rptr (wq2_rptr),
        .do_write (do_write),
        .waddr    (waddr),
        .wptr     (wptr),
        .full     (full),
        .overflow (overflow)
    );

    fifo_rptr_empty #(.ADDR_WIDTH(ADDR_WIDTH)) u_rptr_empty (
        .rclk      (rclk),
        .rrst_n    (rrst_n),
        .rd_en     (rd_en),
        .rq2_wptr  (rq2_wptr),
        .do_read   (do_read),
        .raddr     (raddr),
        .rptr      (rptr),
        .empty     (empty),
        .underflow (underflow)
    );

    fifo_mem #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) u_mem (
        .wclk   (wclk),
        .wr_en  (do_write),
        .waddr  (waddr),
        .wdata  (wdata),
        .rclk   (rclk),
        .rrst_n (rrst_n),
        .rd_en  (do_read),
        .raddr  (raddr),
        .rdata  (rdata)
    );

endmodule
