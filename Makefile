ifndef CC
override CC = gcc
endif

ifndef CXX
override CXX = g++
endif

ifndef ENABLE_TEST_ALL
	DEFINED_FLAGS =
else
	DEFINED_FLAGS = -DENABLE_TEST_ALL
endif

CC = $(CROSS_COMPILE)gcc
CXX = $(CROSS_COMPILE)g++
CXXFLAGS += -static
LDFLAGS += -static

ifdef CROSS_COMPILE
	check_riscv := $(shell echo | $(CROSS_COMPILE)cpp -dM - | grep " __riscv_xlen " | cut -c22-)
	ifeq ($(check_riscv),64)
		processor = rv64
	else ifeq ($(check_riscv),32)
		processor = rv32
	else
		$(error Unsupported cross-compiler)
	endif

	ifeq ($(SIMULATOR_TYPE), qemu)
		SIMULATOR += qemu-riscv64
		SIMULATOR_FLAGS = -cpu $(processor),v=true,zba=true,vlen=128
	else
		SIMULATOR = spike
		SIMULATOR_FLAGS = --isa=$(processor)gcv_zba
		PROXY_KERNEL = pk
	endif
else
	uname_result = $(shell uname -m)
	ifeq ($(uname_result), riscv64)
		processor = rv64
	else ifeq ($(uname_result), riscv32)
		processor = rv32
	else ifeq ($(uname_result), i386)
		processor = i386
	else ifeq ($(uname_result), x86_64)
		processor = x86_64
	else
		$(error Unsupported processor)
	endif
endif

ifeq ($(processor),$(filter $(processor),rv32 rv64))
	ARCH_CFLAGS = -march=$(processor)gcv_zba
else ifeq ($(processor),$(filter $(processor),i386 x86_64))
	ARCH_CFLAGS = -maes -mpclmul -mssse3 -msse4.2
endif

CXXFLAGS += -Wall -Wcast-qual -I. $(ARCH_CFLAGS)
LDFLAGS	+= -lm
OBJS = \
	tests/binding.o \
	tests/common.o \
	tests/debug_tools.o \
	tests/impl.o \
	tests/main.o
deps := $(OBJS:%.o=%.o.d)

.SUFFIXES: .o .cpp
.cpp.o:
	$(CXX) -o $@ $(CXXFLAGS) $(DEFINED_FLAGS) -c -MMD -MF $@.d $<

EXEC = tests/main

$(EXEC): $(OBJS)
	$(CXX) $(LDFLAGS) -o $@ $^

test: build-test
	$(SIMULATOR) $(SIMULATOR_FLAGS) $(PROXY_KERNEL) $^

build-test: tests/main
ifeq ($(processor),$(filter $(processor),rv32 rv64))
ifeq ($(shell $(CROSS_COMPILE)gcc -v 2>&1 | awk 'END{print ($$3>="14.0.0")?"T":"F"}'),F)
	$(warning "gcc version is lower than gcc-14, please use gcc-14 or newer")
endif
	$(CC) $(ARCH_CFLAGS) -c sse2rvv.h
endif

format:
	@echo "Formatting files with clang-format.."
	@if ! hash clang-format; then echo "clang-format is required to indent"; fi
	clang-format -i sse2rvv.h tests/*.cpp tests/*.h

.PHONY: clean check format all test build-test

all: test

clean:
	$(RM) $(OBJS) $(EXEC) $(deps) sse2rvv.h.gch

clean-all: clean
	$(RM) *.log

-include $(deps)
