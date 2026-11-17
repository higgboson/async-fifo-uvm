// fifo_defs.svh
// Width / depth live here so the interfaces, the testbench and the DUT
// instance in tb_top.sv all agree. Change FIFO_ADDR_W and everything that
// depends on the depth (coverage bins, scoreboard checks, sequences) follows.
//
// NOTE: the data-pattern coverage bins and the data-pattern sequence assume
// an 8-bit data bus.

`ifndef FIFO_DEFS_SVH
`define FIFO_DEFS_SVH

`define FIFO_DATA_W  8
`define FIFO_ADDR_W  4                     // >= 2 (Gray full compare needs 2 MSBs)
`define FIFO_DEPTH   (1 << `FIFO_ADDR_W)

`endif
