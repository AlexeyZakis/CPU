VERILOG_COMPILER = iverilog
SIMULATOR = gtkwave

ROOT_DIR = .
RTL_DIR = rtl
TB_DIR = tb
BUILD_DIR = build

OUTPUT_FILE_NAME = cpu_sim
DUMP_FILE_NAME = dump.vcd

OUTPUT = $(BUILD_DIR)/$(OUTPUT_FILE_NAME)
DUMP_FILE_PATH = $(BUILD_DIR)/$(DUMP_FILE_NAME)

INCLUDE_DIRS = $(sort $(dir $(shell find $(RTL_DIR) $(TB_DIR) -type f \( -name "*.vh" -o -name "*.svh" \))))
INCLUDES = $(foreach dir,$(INCLUDE_DIRS),-I $(dir))

SOURCES = $(sort $(shell find $(RTL_DIR) $(TB_DIR) -type f \( -name "*.v" -o -name "*.sv" \)))
EXTRA_SOURCES =

ALL_SOURCES = $(SOURCES) $(EXTRA_SOURCES)

.DEFAULT_GOAL := run

run: build sim wave

prepare-build-dir:
	mkdir -p $(BUILD_DIR)

build: prepare-build-dir
	$(VERILOG_COMPILER) -g2012 $(INCLUDES) $(ALL_SOURCES) -o $(OUTPUT)

rebuild: clean build

sim:
	cd $(BUILD_DIR) && ./$(notdir $(OUTPUT))

wave:
	$(SIMULATOR) $(DUMP_FILE_PATH)

clean:
	rm -rf $(BUILD_DIR)

print-includes:
	@printf '%s\n' $(INCLUDE_DIRS)

print-sources:
	@printf '%s\n' $(ALL_SOURCES)

.PHONY: run build rebuild sim wave clean print-includes print-sources prepare-build-dir

