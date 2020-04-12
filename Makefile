###########################################################################
## Xilinx ISE Makefile
##
## To the extent possible under law, the author(s) have dedicated all copyright
## and related and neighboring rights to this software to the public domain
## worldwide. This software is distributed without any warranty.
###########################################################################

###########################################################################
# Default values
###########################################################################

TOPLEVEL        = $(PROJECT)
CONSTRAINTS     = $(PROJECT).ucf
BITFILE         = build/$(PROJECT).bit

COMMON_OPTS     = -intstyle xflow
XST_OPTS        =
NGDBUILD_OPTS   =
MAP_OPTS        =
PAR_OPTS        =
BITGEN_OPTS     =
TRACE_OPTS      = -e
FUSE_OPTS       = -incremental -lib unisims_ver
VERILATOR_OPTS  = -I$(XILINX)/verilog/xeclib/unisims

PROGRAMMER      = none

IMPACT_EXE      = $(XILINX)/bin/$(PLATFORM)/impact$(EXE)
IMPACT_OPTS     = -batch impact.cmd

DJTG_EXE        = djtgcfg
DJTG_DEVICE     = DJTG_DEVICE-NOT-SET
DJTG_INDEX      = 0

XC3SPROG_EXE    = xc3sprog
XC3SPROG_CABLE  = none
XC3SPROG_OPTS   =

COLOR           = 1


include project.cfg
include environment.cfg


ifndef XILINX
    $(error XILINX must be defined in environment.cfg)
endif

ifndef PLATFORM
    $(error PLATFORM must be defined in project.cfg)
endif

ifndef PROJECT
    $(error PROJECT must be defined in project.cfg)
endif

ifndef TARGET_PART
    $(error TARGET_PART must be defined in project.cfg)
endif


###########################################################################
# Internal variables, platform-specific definitions, and macros
###########################################################################

ifeq ($(OS),Windows_NT)
    # Cygwin
    XILINX := $(shell cygpath -m $(XILINX))
    PATH := $(PATH):$(shell cygpath $(XILINX))/bin/$(PLATFORM)
else
    # Native Linux or WSL
    PATH := $(PATH):$(XILINX)/bin/$(PLATFORM)
endif

ifeq ($(PLATFORM:64=),nt) # nt or nt64
    EXE ?= .exe
endif

TEST_NAMES := $(foreach file,$(VTEST) $(VHDTEST),$(basename $(file)))
TEST_EXES  := $(foreach test,$(TEST_NAMES),build/isim_$(test)$(EXE))

RUN = @echo "\n\n$(COLOR:1=\e[1;33m)======== $(1) ========$(COLOR:1=\e[m)\n\n"; \
      cd build && $(XILINX)/bin/$(PLATFORM)/$(1)$(EXE)

# isim executables require this to be set in the global environment
export XILINX


###########################################################################
# Default build
###########################################################################

default: $(BITFILE)

clean:
	rm -rf build

build/$(PROJECT).prj: project.cfg
	@echo "Updating $@"
	@mkdir -p build
	@rm -f $@
	@$(foreach file,$(VSOURCE),echo "verilog work \"../$(file)\"" >> $@;)
	@$(foreach file,$(VHDSOURCE),echo "vhdl work \"../$(file)\"" >> $@;)

build/$(PROJECT)_sim.prj: build/$(PROJECT).prj
	@echo "Updating $@"
	@cp build/$(PROJECT).prj $@
	@$(foreach file,$(VTEST),echo "verilog work \"../$(file)\"" >> $@;)
	@$(foreach file,$(VHDTEST),echo "vhdl work \"../$(file)\"" >> $@;)
	@echo "verilog xilinx $(XILINX)/verilog/src/glbl.v" >> $@

build/$(PROJECT).scr: project.cfg
	@echo "Updating $@"
	@mkdir -p build
	@rm -f $@
	@echo "run" \
	    "-ifn $(PROJECT).prj" \
	    "-ofn $(PROJECT).ngc" \
	    "-ifmt mixed" \
	    "$(XST_OPTS)" \
	    "-top $(TOPLEVEL)" \
	    "-ofmt NGC" \
	    "-p $(TARGET_PART)" \
	    > build/$(PROJECT).scr

$(BITFILE): project.cfg $(VSOURCE) $(CONSTRAINTS) build/$(PROJECT).prj build/$(PROJECT).scr
	@mkdir -p build
	$(call RUN,xst) $(COMMON_OPTS) \
	    -ifn $(PROJECT).scr
	$(call RUN,ngdbuild) $(COMMON_OPTS) $(NGDBUILD_OPTS) \
	    -p $(TARGET_PART) -uc ../$(CONSTRAINTS) \
	    $(PROJECT).ngc $(PROJECT).ngd
	$(call RUN,map) $(COMMON_OPTS) $(MAP_OPTS) \
	    -p $(TARGET_PART) \
	    -w $(PROJECT).ngd -o $(PROJECT).map.ncd $(PROJECT).pcf
	$(call RUN,par) $(COMMON_OPTS) $(PAR_OPTS) \
	    -w $(PROJECT).map.ncd $(PROJECT).ncd $(PROJECT).pcf
	$(call RUN,bitgen) $(COMMON_OPTS) $(BITGEN_OPTS) \
	    -w $(PROJECT).ncd $(PROJECT).bit
	@echo "$(COLOR:1=\e[1;32m)======== OK ========$(COLOR:1=\e[m)\n"


###########################################################################
# Testing (work in progress)
###########################################################################

trace: project.cfg $(BITFILE)
	$(call RUN,trce) $(COMMON_OPTS) $(TRACE_OPTS) \
	    $(PROJECT).ncd $(PROJECT).pcf

lint: $(VSOURCE)
	verilator $(VERILATOR_OPTS) --lint-only $(VSOURCE)

test: $(foreach file,$(VTEST) $(VHDTEST),build/$(basename $(file)).vcd)

build/isim_%$(EXE): build/$(PROJECT)_sim.prj $(VSOURCE) $(VHDSOURCE) %.v
	$(call RUN,fuse) $(COMMON_OPTS) $(FUSE_OPTS) \
	    -prj $(PROJECT)_sim.prj \
	    -o isim_$*$(EXE) \
	    work.$* xilinx.glbl

build/isim_%$(EXE): build/$(PROJECT)_sim.prj $(VSOURCE) $(VHDSOURCE) %.vhd
	$(call RUN,fuse) $(COMMON_OPTS) $(FUSE_OPTS) \
	    -prj $(PROJECT)_sim.prj \
	    -o isim_$*$(EXE) \
	    work.$* xilinx.glbl

build/%.vcd: build/isim_%$(EXE)
	@echo > build/isim_$*.cmd
	@echo "vcd dumpfile $*.vcd" >> build/isim_$*.cmd
	@echo "vcd dumpvars -m $* -l 0" >> build/isim_$*.cmd
	@echo "run all" >> build/isim_$*.cmd
	cd build ; ./$(<F) -tclbatch isim_$*.cmd | tee $*.out
	@grep --quiet '# SUCCESS' build/$*.out

.PRECIOUS: build/isim_%$(EXE)


###########################################################################
# Programming
###########################################################################

ifeq ($(PROGRAMMER), impact)
prog: $(BITFILE)
	$(IMPACT_EXE) $(IMPACT_OPTS)
endif

ifeq ($(PROGRAMMER), digilent)
prog: $(BITFILE)
	$(DJTG_EXE) prog -d $(DJTG_DEVICE) -i $(DJTG_INDEX) -f $(BITFILE)
endif

ifeq ($(PROGRAMMER), xc3sprog)
prog: $(BITFILE)
	$(XC3SPROG_EXE) -c $(XC3SPROG_CABLE) $(XC3SPROG_OPTS) $(BITFILE)
endif

ifeq ($(PROGRAMMER), none)
prog:
	$(error PROGRAMMER must be set to use 'make prog')
endif


###########################################################################

# vim: set filetype=make: #
