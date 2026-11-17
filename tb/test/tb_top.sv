`timescale 1ns/1ps

module tb_top;

        import uvm_pkg::*;
        import fifo_tb_pkg::*;

        // clocks + resets for both domains
        fifo_clk_rst_if clk_if();

        // one pin interface per clock domain
        fifo_wr_if wr_if(clk_if.wclk);
        fifo_rd_if rd_if(clk_if.rclk);

        assign wr_if.wrst_n = clk_if.wrst_n;
        assign rd_if.rrst_n = clk_if.rrst_n;

        async_fifo #(
                .DATA_WIDTH (`FIFO_DATA_W),
                .ADDR_WIDTH (`FIFO_ADDR_W)
        ) DUT (
                .wclk      (clk_if.wclk),
                .wrst_n    (clk_if.wrst_n),
                .wr_en     (wr_if.wr_en),
                .wdata     (wr_if.wdata),
                .full      (wr_if.full),
                .overflow  (wr_if.overflow),

                .rclk      (clk_if.rclk),
                .rrst_n    (clk_if.rrst_n),
                .rd_en     (rd_if.rd_en),
                .rdata     (rd_if.rdata),
                .empty     (rd_if.empty),
                .underflow (rd_if.underflow)
        );

        initial begin
                uvm_config_db #(virtual fifo_wr_if)::set(null, "uvm_test_top", "wr_vif", wr_if);
                uvm_config_db #(virtual fifo_rd_if)::set(null, "uvm_test_top", "rd_vif", rd_if);
                uvm_config_db #(virtual fifo_clk_rst_if)::set(null, "uvm_test_top", "clk_vif", clk_if);

                // safety net in case something deadlocks
                uvm_top.set_timeout(50ms, 0);

                // +UVM_TESTNAME=<test> picks the test, base test by default
                run_test("fifo_base_test");
        end

`ifdef DUMP_VCD
        initial begin
                $dumpfile("waves.vcd");
                $dumpvars(0, tb_top);
        end
`endif

endmodule: tb_top
