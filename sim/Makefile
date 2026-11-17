# ===================================================================
# Async FIFO - UVM regression Makefile
#
#   SIMULATOR = xcelium | questa | vcs | verilator
#
#   make run   TEST=fifo_wr_fast_test           one test, batch mode
#   make run   TEST=fifo_reset_test SEED=1234   replay a seed
#   make run   TEST=fifo_base_test  ARGS="+WCLK_NS=5 +RCLK_NS=9"
#   make regress                                every test, merged coverage
#   make report                                 merge + html coverage
#   make clean
# ===================================================================

SIMULATOR ?= xcelium

TEST      ?= fifo_base_test
SEED      ?= random
VERB      ?= UVM_MEDIUM
ARGS      ?=

TESTS = fifo_base_test fifo_wr_fast_test fifo_rd_fast_test fifo_fill_drain_test \
        fifo_simul_rw_test fifo_data_test fifo_burst_test fifo_reset_test \
        fifo_clk_sweep_test

RTL   = ../rtl/fifo_sync_2ff.v ../rtl/fifo_wptr_full.v ../rtl/fifo_rptr_empty.v \
        ../rtl/fifo_mem.v ../rtl/async_fifo.v

INC   = +incdir+../tb +incdir+../tb/intf +incdir+../tb/agents/wr_agent \
        +incdir+../tb/agents/rd_agent +incdir+../tb/env +incdir+../tb/seq +incdir+../tb/test

# compile order: interfaces, bind module, package, top
TB    = ../tb/intf/fifo_clk_rst_if.sv ../tb/intf/fifo_wr_if.sv ../tb/intf/fifo_rd_if.sv \
        ../tb/sva/async_fifo_sva.sv ../tb/test/fifo_tb_pkg.sv ../tb/test/tb_top.sv

PLUS  = +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=$(VERB) $(ARGS)

.PHONY: help run regress report clean \
        run_xcelium run_questa run_vcs run_verilator regress_xcelium regress_questa regress_vcs \
        regress_verilator report_xcelium report_questa report_vcs report_verilator

help:
	@echo "make run TEST=<test> [SEED=n] [VERB=UVM_HIGH] [ARGS=\"+WCLK_NS=5 +RCLK_NS=9\"]"
	@echo "make regress      run all tests: $(TESTS)"
	@echo "make report       merge coverage of the regression"
	@echo "SIMULATOR=$(SIMULATOR)  (xcelium | questa | vcs | verilator)"

run:     run_$(SIMULATOR)
regress: regress_$(SIMULATOR)
report:  report_$(SIMULATOR)

# ---------------------------------------------------------------- xcelium
XSEED = $(if $(filter random,$(SEED)),random,$(SEED))

run_xcelium:
	xrun -64bit -sv -uvm -uvmhome CDNS-1.2 -access +rwc -timescale 1ns/1ps \
	     -coverage all -covoverwrite -covtest $(TEST)_$(XSEED) -covdut async_fifo \
	     -svseed $(XSEED) $(INC) $(RTL) $(TB) $(PLUS) \
	     -l $(TEST).log

regress_xcelium:
	@for t in $(TESTS); do $(MAKE) --no-print-directory run_xcelium TEST=$$t SEED=$(SEED) || exit 1; done
	@echo "========== summary =========="
	@grep -h "PASSED\|FAILED" *.log

report_xcelium:
	imc -execcmd "merge cov_work/scope/fifo_* -out merged -overwrite; load -run merged; report -html -out cov_html -detail -metrics all; exit"
	@echo "open cov_html/index.html (or: imc -load merged)"

# ---------------------------------------------------------------- questa
QSEED = $(if $(filter random,$(SEED)),random,$(SEED))

run_questa:
	vlib work
	vlog -sv -timescale 1ns/1ps +cover=bcesft -L $(QUESTA_HOME)/uvm-1.2 \
	     +incdir+$(QUESTA_HOME)/verilog_src/uvm-1.2/src $(INC) $(RTL) $(TB)
	vsim -c -voptargs=+acc -coverage -sva -sv_seed $(QSEED) tb_top $(PLUS) \
	     -do "coverage save -onexit $(TEST).ucdb; run -all; exit" -l $(TEST).log

regress_questa:
	@for t in $(TESTS); do $(MAKE) --no-print-directory run_questa TEST=$$t SEED=$(SEED) || exit 1; done
	@echo "========== summary =========="
	@grep -h "PASSED\|FAILED" *.log

report_questa:
	vcover merge merged.ucdb *.ucdb
	vcover report -html -htmldir cov_html -details merged.ucdb

# ---------------------------------------------------------------- vcs
VSEED = $(if $(filter random,$(SEED)),0,$(SEED))

run_vcs:
	vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps -debug_access+all \
	    -cm line+cond+fsm+tgl+branch+assert -cm_hier "+tree tb_top.DUT" \
	    $(INC) $(RTL) $(TB) -o simv -l comp.log
	./simv +ntb_random_seed=$(VSEED) $(PLUS) -cm line+cond+fsm+tgl+branch+assert \
	    -cm_name $(TEST) -l $(TEST).log

regress_vcs:
	@for t in $(TESTS); do $(MAKE) --no-print-directory run_vcs TEST=$$t SEED=$(SEED) || exit 1; done
	@echo "========== summary =========="
	@grep -h "PASSED\|FAILED" *.log

report_vcs:
	urg -dir simv.vdb -format both -report cov_html

# ---------------------------------------------------------------- verilator
# free flow for a laptop: needs Verilator >= 5.036 and the UVM fork from
#   git clone https://github.com/chipsalliance/uvm-verilator
# then  make run SIMULATOR=verilator UVM_HOME=<path>/uvm-verilator/src
# also needs the z3 SMT solver on PATH for randomize() (pip install z3-solver)
# (no functional coverage: Verilator ignores covergroups, SVA + scoreboard still run)
UVM_HOME ?= ../../uvm-verilator/src
VSEED_V   = $(if $(filter random,$(SEED)),0,$(SEED))

obj_dir/simv:
	verilator --binary --timing --assert -j 1 -Wno-fatal -Wno-lint -Wno-style \
	    -Wno-COVERIGN -Wno-SYMRSVDWORD -Wno-CONSTRAINTIGN --timescale 1ns/1ps \
	    -CFLAGS "-std=c++20 -fcoroutines -O1" +define+UVM_NO_DPI \
	    +incdir+$(UVM_HOME) $(INC) $(UVM_HOME)/uvm_pkg.sv $(RTL) $(TB) \
	    --top-module tb_top -o simv

run_verilator: obj_dir/simv
	./obj_dir/simv +verilator+seed+$(VSEED_V) $(PLUS) | tee $(TEST).log

regress_verilator: obj_dir/simv
	@for t in $(TESTS); do $(MAKE) --no-print-directory run_verilator TEST=$$t SEED=$(SEED) || exit 1; done
	@echo "========== summary =========="
	@grep -h "PASSED\|FAILED" *.log

report_verilator:
	@echo "Verilator does not collect covergroups, use xcelium / questa / vcs for coverage"

# ---------------------------------------------------------------- clean
clean:
	rm -rf work transcript *.log *.ucdb *.wlf vsim.* cov_work cov_html merged* \
	       xcelium.d xrun.* waves*.shm *.history INCA_libs \
	       simv* csrc *.vdb ucli.key vc_hdrc.log *.key urgReport obj_dir
