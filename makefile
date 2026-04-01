VERILOG_COMPILER = iverilog
SIMULATOR = gtkwave

OUTPUT = cpu_sim
DUMP_FILE = dump.vcd

SOURCES = rtl/common/cpu_defs.sv \
          $(shell find rtl tb -type f \( -name "*.v" -o -name "*.sv" \) ! -path "rtl/common/cpu_defs.sv")
run:
	$(VERILOG_COMPILER) -g2012 -I rtl/common $(SOURCES) -o $(OUTPUT)
	./$(OUTPUT)
	$(SIMULATOR) $(DUMP_FILE)

build:
	$(VERILOG_COMPILER) -g2012 -I rtl/common $(SOURCES) -o $(OUTPUT)

sim:
	./$(OUTPUT)

wave:
	$(SIMULATOR) $(DUMP_FILE)

clean:
	rm -f $(OUTPUT) $(DUMP_FILE)

