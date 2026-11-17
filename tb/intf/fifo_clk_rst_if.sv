`timescale 1ns/1ps
`ifndef FIFO_CLK_RST_IF_SV
`define FIFO_CLK_RST_IF_SV

// Clock + reset generator for the two clock domains.
//
// * The periods are plain variables, the generator re-reads them every half
//   cycle. So a test can set them in end_of_elaboration, and a virtual
//   sequence can even change the clock ratio in the middle of the run
//   (see fifo_clk_sweep_vseq).
// * rclk starts with a phase offset so the two clocks are not edge aligned.
// * apply_reset(): asserts BOTH resets together (asynchronously), then
//   releases each one synchronously to its own clock. Resetting only one
//   side of an async FIFO is not a legal use case, so we never do it.
interface fifo_clk_rst_if;

        bit   wclk = 1'b0;
        bit   rclk = 1'b0;
        logic wrst_n;          // held in reset until the test releases it
        logic rrst_n;

        real  wclk_period_ns = 10.0;
        real  rclk_period_ns = 13.0;
        real  rclk_phase_ns  = 2.7;

        // the resets are async (negedge triggered): give them a real 1->0 edge
        // at time 0 so every flop resets, whatever the simulator does with X
        initial begin
                wrst_n = 1'b1;
                rrst_n = 1'b1;
                #0.1;
                wrst_n = 1'b0;
                rrst_n = 1'b0;
        end

        initial begin
                forever begin
                        #(wclk_period_ns / 2.0);
                        wclk = ~wclk;
                end
        end

        initial begin
                #(rclk_phase_ns);
                forever begin
                        #(rclk_period_ns / 2.0);
                        rclk = ~rclk;
                end
        end

        function automatic void set_periods(real wclk_ns, real rclk_ns);
                wclk_period_ns = wclk_ns;
                rclk_period_ns = rclk_ns;
        endfunction

        // async assert, sync release per domain
        task automatic apply_reset(int unsigned wcycles = 4, int unsigned rcycles = 4);
                wrst_n = 1'b0;
                rrst_n = 1'b0;
                fork
                        begin
                                repeat (wcycles) @(posedge wclk);
                                #1 wrst_n = 1'b1;
                        end
                        begin
                                repeat (rcycles) @(posedge rclk);
                                #1 rrst_n = 1'b1;
                        end
                join
        endtask

endinterface: fifo_clk_rst_if

`endif
