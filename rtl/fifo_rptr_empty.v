`timescale 1ns/1ps
//------------------------------------------------------------------
// fifo_rptr_empty : read pointer + empty flag, rclk domain
//
//   rbin : binary pointer (addresses the memory)
//   rptr : Gray copy of the pointer (the only thing that crosses to wclk)
//
//   EMPTY: the next read pointer equals the synchronized write pointer.
//   empty is registered and comes out of reset HIGH.
//------------------------------------------------------------------
module fifo_rptr_empty #(
    parameter ADDR_WIDTH = 4
)(
    input                       rclk,
    input                       rrst_n,     // async, active low
    input                       rd_en,
    input      [ADDR_WIDTH:0]   rq2_wptr,   // write pointer (gray) synced into rclk
    output                      do_read,    // read really accepted this cycle
    output     [ADDR_WIDTH-1:0] raddr,
    output reg [ADDR_WIDTH:0]   rptr,       // gray
    output reg                  empty,
    output reg                  underflow   // rd_en was high while empty (1 cycle late)
);

    reg  [ADDR_WIDTH:0] rbin;
    wire [ADDR_WIDTH:0] rbin_next;
    wire [ADDR_WIDTH:0] rgray_next;
    wire                empty_next;

    assign do_read    = rd_en & ~empty;
    assign rbin_next  = rbin + {{ADDR_WIDTH{1'b0}}, do_read};
    assign rgray_next = (rbin_next >> 1) ^ rbin_next;

    assign empty_next = (rgray_next == rq2_wptr);

    assign raddr      = rbin[ADDR_WIDTH-1:0];

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin      <= {(ADDR_WIDTH+1){1'b0}};
            rptr      <= {(ADDR_WIDTH+1){1'b0}};
            empty     <= 1'b1;
            underflow <= 1'b0;
        end else begin
            rbin      <= rbin_next;
            rptr      <= rgray_next;
            empty     <= empty_next;
            underflow <= rd_en & empty;
        end
    end

endmodule
