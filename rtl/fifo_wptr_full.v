`timescale 1ns/1ps
//------------------------------------------------------------------
// fifo_wptr_full : write pointer + full flag, wclk domain
//
//   wbin : binary pointer (addresses the memory)
//   wptr : Gray copy of the pointer (the only thing that crosses to rclk)
//
//   FULL in Gray code: the next write pointer equals the synchronized
//   read pointer with its two MSBs inverted (lap bit differs, and the
//   Gray reflection flips the second MSB too).
//   full is registered, so it is glitch free.
//------------------------------------------------------------------
module fifo_wptr_full #(
    parameter ADDR_WIDTH = 4
)(
    input                       wclk,
    input                       wrst_n,     // async, active low
    input                       wr_en,
    input      [ADDR_WIDTH:0]   wq2_rptr,   // read pointer (gray) synced into wclk
    output                      do_write,   // write really accepted this cycle
    output     [ADDR_WIDTH-1:0] waddr,
    output reg [ADDR_WIDTH:0]   wptr,       // gray
    output reg                  full,
    output reg                  overflow    // wr_en was high while full (1 cycle late)
);

    reg  [ADDR_WIDTH:0] wbin;
    wire [ADDR_WIDTH:0] wbin_next;
    wire [ADDR_WIDTH:0] wgray_next;
    wire                full_next;

    assign do_write   = wr_en & ~full;
    assign wbin_next  = wbin + {{ADDR_WIDTH{1'b0}}, do_write};
    assign wgray_next = (wbin_next >> 1) ^ wbin_next;

    assign full_next  = (wgray_next == {~wq2_rptr[ADDR_WIDTH:ADDR_WIDTH-1],
                                         wq2_rptr[ADDR_WIDTH-2:0]});

    assign waddr      = wbin[ADDR_WIDTH-1:0];

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin     <= {(ADDR_WIDTH+1){1'b0}};
            wptr     <= {(ADDR_WIDTH+1){1'b0}};
            full     <= 1'b0;
            overflow <= 1'b0;
        end else begin
            wbin     <= wbin_next;
            wptr     <= wgray_next;
            full     <= full_next;
            overflow <= wr_en & full;
        end
    end

endmodule
