`timescale 1ns/1ps
//------------------------------------------------------------------
// fifo_mem : dual-clock storage array
//
//   * write port on wclk, registered read port on rclk
//   * No reset on the array on purpose: a location is only read after
//     the read side has seen (through the synchronizer) that it was
//     written, so a never-written word can never reach rdata.
//   * rdata is registered: valid ONE rclk cycle after an accepted read,
//     and holds its value when no read is accepted.
//------------------------------------------------------------------
module fifo_mem #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    input                       wclk,
    input                       wr_en,      // already qualified by ~full
    input      [ADDR_WIDTH-1:0] waddr,
    input      [DATA_WIDTH-1:0] wdata,

    input                       rclk,
    input                       rrst_n,     // async, active low (rdata only)
    input                       rd_en,      // already qualified by ~empty
    input      [ADDR_WIDTH-1:0] raddr,
    output reg [DATA_WIDTH-1:0] rdata
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // write port
    always @(posedge wclk) begin
        if (wr_en)
            mem[waddr] <= wdata;
    end

    // read port
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n)
            rdata <= {DATA_WIDTH{1'b0}};
        else if (rd_en)
            rdata <= mem[raddr];
    end

endmodule
