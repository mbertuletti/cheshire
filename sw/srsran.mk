# Copyright 2026 Celeste Technologies.
#
# Marco Bertuletti <mbertuletti@iis.ee.ethz.ch>

# Project variables
# Set `RVV=0` to build for `rv64gc` (no vector instructions).
RVV 		  ?= 1
CVA6_DIR      := $(abspath $(CHS_SW_DIR)/deps/cva6-sdk)
BUILDROOT_DIR := $(CVA6_DIR)/buildroot
BUILD_DIR     := $(abspath $(CHS_SW_DIR)/deps/build)
INSTALL_DIR   := $(abspath $(CHS_SW_DIR)/deps/install)
SRSRAN_DIR	  := $(abspath $(CHS_SW_DIR)/deps/srsRAN_Project)
CCACHE_DIR    ?= $(BUILD_DIR)/ccache

# ISA string used across dependencies and srsRAN (CMake `-DMARCH=...`).
ifeq ($(RVV), 1)
GNB_MARCH     := rv64gcv
else
GNB_MARCH     := rv64gc
endif

# Cross-compiler
GNB_CC        := $(abspath $(BUILDROOT_DIR)/output/host/bin/riscv64-buildroot-linux-gnu-gcc)
GNB_CXX       := $(abspath $(BUILDROOT_DIR)/output/host/bin/riscv64-buildroot-linux-gnu-g++)
GNB_CFLAGS    := -march=$(GNB_MARCH) -I$(BUILDROOT_DIR)/output/host/include
GNB_LIBS      := $(BUILDROOT_DIR)/output/host/lib:$(BUILDROOT_DIR)/output/host/lib64

ifeq ($(RVV), 1)
buildroot_defconfig = $(CVA6_DIR)/configs/buildroot64_V_defconfig
else
buildroot_defconfig = $(CVA6_DIR)/configs/buildroot64_defconfig
endif

# Build toolchain
GNB_TOOLCHAIN := $(GNB_CC) $(GNB_CXX)
$(GNB_TOOLCHAIN):
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(INSTALL_DIR)
	make -C $(BUILDROOT_DIR) defconfig BR2_DEFCONFIG=$(buildroot_defconfig)
	make -C $(BUILDROOT_DIR) -j $(shell nproc)

# FFTW variables
FFTW_URL := http://www.fftw.org/fftw-3.3.10.tar.gz
FFTW_DIR := $(BUILD_DIR)/fftw-3.3.10

# MBEDTLS variables
MBEDTLS_URL := https://github.com/Mbed-TLS/mbedtls.git
MBEDTLS_DIR := $(BUILD_DIR)/mbedtls

# YAMLCPP variables
YAMLCPP_URL := https://github.com/jbeder/yaml-cpp.git
YAMLCPP_DIR := $(BUILD_DIR)/yaml-cpp

# LKSCTP variables
LKSCTP_URL := https://github.com/sctp/lksctp-tools.git
LKSCTP_DIR := $(BUILD_DIR)/lksctp-tools

# Googletest variables
GOOGLETEST_URL := https://github.com/google/googletest.git
GOOGLETEST_DIR := $(BUILD_DIR)/googletest

GNB_DEPS := $(INSTALL_DIR)/usr/lib/libfftw3f.so
GNB_DEPS += $(INSTALL_DIR)/usr/lib/libsctp.so
GNB_DEPS += $(INSTALL_DIR)/usr/lib/libmbedtls.so
GNB_DEPS += $(INSTALL_DIR)/usr/lib/libyaml-cpp.so
GNB_DEPS += $(INSTALL_DIR)/usr/lib/libgtest.a

# Install FFTW

$(INSTALL_DIR)/usr/lib/libfftw3f.so: $(GNB_TOOLCHAIN)
	@if [ ! -d $(FFTW_DIR) ]; then \
	  echo "Downloading FFTW..."; \
	  wget -P $(BUILD_DIR) $(FFTW_URL); \
	  tar -xzf "$(FFTW_DIR).tar.gz" -C $(BUILD_DIR); \
	  rm -rf "$(FFTW_DIR).tar.gz"; \
	fi
	cd $(FFTW_DIR) && \
	./configure --prefix=$(INSTALL_DIR)/usr \
				--host=riscv64-buildroot-linux-gnu \
                --disable-fortran \
                --enable-shared \
                --enable-float \
	            CC=$(GNB_CC) \
	            CFLAGS="$(GNB_CFLAGS)" \
	            LD_LIBRARY_PATH="$(GNB_LIBS)"
	$(MAKE) -C $(FFTW_DIR)
	$(MAKE) install -C $(FFTW_DIR)

# Install LKSCTP

$(INSTALL_DIR)/usr/lib/libsctp.so: $(GNB_TOOLCHAIN)
	@if [ ! -d "$(LKSCTP_DIR)" ]; then \
	    git clone $(LKSCTP_URL) $(LKSCTP_DIR); \
	else \
	    echo "$(LKSCTP_DIR) already exists, skipping clone."; \
	fi
	cd $(LKSCTP_DIR) && set -ex
	cd $(LKSCTP_DIR) && libtoolize --force --copy
	cd $(LKSCTP_DIR) && aclocal
	cd $(LKSCTP_DIR) && autoheader
	cd $(LKSCTP_DIR) && automake --foreign --add-missing --copy
	cd $(LKSCTP_DIR) && autoconf
	cd $(LKSCTP_DIR) && \
	./configure --prefix=$(INSTALL_DIR)/usr \
				--host=riscv64-buildroot-linux-gnu \
				--enable-shared \
				--enable-static \
		        CC=$(GNB_CC) \
	            CFLAGS="$(GNB_CFLAGS)" \
	            LD_LIBRARY_PATH="$(GNB_LIBS)"
	$(MAKE) -C $(LKSCTP_DIR)
	$(MAKE) install -C $(LKSCTP_DIR)

# Install MBEDTLS

$(INSTALL_DIR)/usr/lib/libmbedtls.so: $(GNB_TOOLCHAIN)
	@if [ ! -d "$(MBEDTLS_DIR)" ]; then \
	    git clone --branch v3.6.3 $(MBEDTLS_URL) $(MBEDTLS_DIR); \
	else \
	    echo "$(MBEDTLS_DIR) already exists, skipping clone."; \
	fi
	$(PYTHON) -m pip install -r $(MBEDTLS_DIR)/scripts/basic.requirements.txt
	cd $(MBEDTLS_DIR) && git submodule update --init --recursive
	mkdir -p $(MBEDTLS_DIR)/build;
	cd $(MBEDTLS_DIR)/build && \
	cmake $(MBEDTLS_DIR) \
		-DCMAKE_INSTALL_PREFIX=$(INSTALL_DIR)/usr \
		-DCMAKE_C_COMPILER=$(GNB_CC) \
		-DENABLE_TESTING=Off \
		-DUSE_SHARED_MBEDTLS_LIBRARY=On \
		-DCMAKE_FIND_ROOT_PATH=$(BUILDROOT_DIR)/output/host/bin && \
	cmake --build . && \
	cmake --install .

# Install YAML-CPP

$(INSTALL_DIR)/usr/lib/libyaml-cpp.so: $(GNB_TOOLCHAIN)
	@if [ ! -d "$(YAMLCPP_DIR)" ]; then \
	    git clone $(YAMLCPP_URL) $(YAMLCPP_DIR); \
	else \
	    echo "$(YAMLCPP_DIR) already exists, skipping clone."; \
	fi
	mkdir -p $(YAMLCPP_DIR)/build;
	cd $(YAMLCPP_DIR)/build && \
	cmake $(YAMLCPP_DIR) \
		-DCMAKE_INSTALL_PREFIX=$(INSTALL_DIR)/usr \
		-DCMAKE_C_COMPILER=$(GNB_CC) \
		-DCMAKE_CXX_COMPILER=$(GNB_CXX) \
		-DYAML_BUILD_SHARED_LIBS=on \
		-DCMAKE_FIND_ROOT_PATH=$(BUILDROOT_DIR)/output/host/bin && \
	cmake --build . && \
	cmake --install .

# Install Google-Tests

$(INSTALL_DIR)/usr/lib/libgtest.a: $(GNB_TOOLCHAIN)
	@if [ ! -d "$(GOOGLETEST_DIR)" ]; then \
	    git clone $(GOOGLETEST_URL) $(GOOGLETEST_DIR); \
	else \
	    echo "$(GOOGLETEST_DIR) already exists, skipping clone."; \
	fi
	mkdir -p $(GOOGLETEST_DIR)/build;
	cd $(GOOGLETEST_DIR)/build && \
	cmake $(GOOGLETEST_DIR) \
		-DCMAKE_INSTALL_PREFIX=$(INSTALL_DIR)/usr \
		-DCMAKE_CXX_COMPILER=$(GNB_CXX) && \
	cmake --build . && \
	cmake --install .

# Install gnb

.PHONY: gnb gnb-clean

gnb: $(INSTALL_DIR)/usr/bin/gnb

$(INSTALL_DIR)/usr/bin/gnb: $(GNB_TOOLCHAIN) $(GNB_DEPS)
	rm -rf $(SRSRAN_DIR)/build
	mkdir -p $(SRSRAN_DIR)/build;
	cd $(SRSRAN_DIR)/build && \
	PKG_CONFIG_PATH="$(realpath $(INSTALL_DIR)/usr/lib/pkgconfig):$(realpath $(INSTALL_DIR)/usr/lib64/pkgconfig)" \
	cmake $(SRSRAN_DIR) \
		-DCMAKE_INSTALL_PREFIX=$(INSTALL_DIR)/usr/ \
		-DCMAKE_PREFIX_PATH=$(INSTALL_DIR)/usr/ \
		-DCMAKE_FIND_ROOT_PATH=$(INSTALL_DIR)/usr/ \
		-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
		-DCMAKE_C_COMPILER=$(GNB_CC) \
        -DCMAKE_CXX_COMPILER=$(GNB_CXX) \
		-DCMAKE_C_FLAGS="-Wno-error=sign-compare -Wno-error=enum-compare -Wno-error=shadow -Wno-error=subobject-linkage" \
		-DCMAKE_CXX_FLAGS="-Wno-error=sign-compare -Wno-error=enum-compare -Wno-error=shadow -Wno-error=subobject-linkage" \
        -DCMAKE_EXE_LINKER_FLAGS="-L$(INSTALL_DIR)/usr/lib -L$(INSTALL_DIR)/usr/lib64 -latomic -pthread" \
		-DCMAKE_TOOLCHAIN_FILE=$(abspath $(CHS_SW_DIR)/toolchain.cmake) \
		-DRISCV_CROSSCOMPILE=on \
		-DMARCH=$(GNB_MARCH) \
		-DENABLE_BACKWARD=off \
		-DENABLE_UHD=off \
		-DENABLE_ZEROMQ=off \
		-DENABLE_MKL=off \
		-DENABLE_ARMPL=off \
		-DENABLE_PLUGINS=off \
		-DBUILD_TESTING=on && \
	cmake --build . --parallel $(shell nproc) && \
	cmake --install .
	mkdir -p $(INSTALL_DIR)/usr/share/srsran/benchmarks/
	find $(SRSRAN_DIR)/build/tests/ -type f -perm -111 -name '*_benchmark' -exec cp {} $(INSTALL_DIR)/usr/share/srsran/benchmarks/ \;		
	rsync -a $(INSTALL_DIR)/usr/ $(CVA6_DIR)/rootfs/usr

gnb-clean:
	rm -rf $(SRSRAN_DIR)/build
	rm -rf $(SRSRAN_DIR)/install
	make -C $(BUILDROOT_DIR) distclean
	make -C $(CVA6_DIR) clean
