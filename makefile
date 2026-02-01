.PHONY: build run RUN clean
VERILOG = $(wildcard vsrc/*.sv)
VERILOG += $(wildcard vsrc/*.v)
CSOURCE=$(shell find csrc -name "*.cpp" -not -path "*/tools/capstone/repo/*")
CSOURCE+=$(shell find csrc -name "*.c" -not -path "*/tools/capstone/repo/*")
CSOURCE+=$(shell find csrc -name "*.cc" -not -path "*/tools/capstone/repo/*")

TOP_NAME ?= PLATFORM_TOP

build:
# 	clear
	verilator --trace -cc $(VERILOG) --exe $(CSOURCE) --top-module $(TOP_NAME) -Mdir obj_dir -Ivsrc
	$(MAKE) -C obj_dir -f V$(TOP_NAME).mk V$(TOP_NAME) 
	python3 csrc/txt2bin.py
run: build
	./obj_dir/V$(TOP_NAME)
test: build
	python3 autotest.py
RUN: run

see:
	gtkwave waveform.vcd

clean:
	rm -rf obj_dir waveform.vcd
