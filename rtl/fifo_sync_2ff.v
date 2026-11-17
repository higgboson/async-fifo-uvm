`timescale 1ns/1ps
//------------------------------------------------------------------
// fifo_sync_2ff : two flip-flop synchronizer for a Gray-coded bus
//
//   Only safe because the input changes at most one bit per source
//   clock (Gray code). Never use this for a binary bus.
//------------------------------------------------------------------
module fifo_sync_2ff #(
    parameter WIDTH = 5
)(
    input                  clk,
    input                  rst_n,      // async, active low (destination domain)
    input      [WIDTH-1:0] d,          // from the other clock domain
    output reg [WIDTH-1:0] q
);

    reg [WIDTH-1:0] meta;              // first stage, may go metastable

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            meta <= {WIDTH{1'b0}};
            q    <= {WIDTH{1'b0}};
        end else begin
            meta <= d;
            q    <= meta;
        end
    end

endmodule
