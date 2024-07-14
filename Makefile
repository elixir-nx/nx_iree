# Environment variables passed via elixir_make
# IREE_GIT_REV
# IREE_DIR
# IREE_BUILD_TARGET
# MIX_APP_PATH

# System vars
TEMP ?= $(HOME)/.cache
BUILD_CACHE ?= $(TEMP)/nx_iree

IREE_REPO ?= https://github.com/iree-org/iree

IREE_NS = iree-$(IREE_GIT_REV)
IREE_DIR ?= $(BUILD_CACHE)/$(IREE_NS)

# default rule for elixir_make
all: install_runtime nx_iree

compile: install_runtime

.PHONY: clone_iree
clone_iree: $(IREE_DIR)

$(IREE_DIR):
	./scripts/clone_iree.sh $(BUILD_CACHE) $(IREE_GIT_REV) $(IREE_DIR)

IREE_CMAKE_BUILD_DIR ?= $(abspath iree-runtime/iree-build)
IREE_RUNTIME_INCLUDE_PATH := $(abspath $(IREE_DIR)/runtime/src/iree)
IREE_RUNTIME_BUILD_DIR ?= $(abspath iree-runtime/build)
IREE_INSTALL_DIR ?= $(abspath iree-runtime/host/install)

IREE_CMAKE_CONFIG ?= Release

IREE_BUILD_TARGET ?= host

BUILD_TARGET_FLAGS = -S cmake

# flags for xcode 15.4
ifeq ($(IREE_BUILD_TARGET), host)
else ifeq ($(IREE_BUILD_TARGET), ios)
	BUILD_TARGET_FLAGS = \
		-DCMAKE_SYSTEM_NAME=iOS\
		-DCMAKE_OSX_DEPLOYMENT_TARGET=17.5\
		-DCMAKE_OSX_ARCHITECTURES=arm64\
		-DCMAKE_SYSTEM_PROCESSOR=arm64\
		-DCMAKE_IOS_INSTALL_COMBINED=YES\
		-DCMAKE_OSX_SYSROOT=$(shell xcodebuild -version -sdk iphoneos Path)
else ifeq ($(IREE_BUILD_TARGET), ios_simulator)
	BUILD_TARGET_FLAGS = \
		-DCMAKE_SYSTEM_NAME=iOS\
		-DCMAKE_OSX_DEPLOYMENT_TARGET=17.5\
		-DCMAKE_OSX_ARCHITECTURES=arm64\
		-DCMAKE_SYSTEM_PROCESSOR=arm64\
		-DCMAKE_IOS_INSTALL_COMBINED=YES\
		-DCMAKE_OSX_SYSROOT=$(shell xcodebuild -version -sdk iphonesimulator Path)
else ifeq ($(IREE_BUILD_TARGET), visionos)
	BUILD_TARGET_FLAGS = \
		-DCMAKE_SYSTEM_NAME=visionOS\
		-DCMAKE_OSX_DEPLOYMENT_TARGET=1.2\
		-DCMAKE_OSX_ARCHITECTURES=arm64\
		-DCMAKE_SYSTEM_PROCESSOR=arm64\
		-DCMAKE_OSX_SYSROOT=$(shell xcodebuild -version -sdk xros Path)
else ifeq ($(IREE_BUILD_TARGET), visionos_simulator)
	BUILD_TARGET_FLAGS = \
		-DCMAKE_SYSTEM_NAME=visionOS\
		-DCMAKE_OSX_DEPLOYMENT_TARGET=1.2\
		-DCMAKE_OSX_ARCHITECTURES=arm64\
		-DCMAKE_SYSTEM_PROCESSOR=arm64\
		-DCMAKE_OSX_SYSROOT=$(shell xcodebuild -version -sdk xrsimulator Path)
else ifeq ($(IREE_BUILD_TARGET), tvos)
	BUILD_TARGET_FLAGS = \
		-DCMAKE_SYSTEM_NAME=tvOS\
		-DCMAKE_OSX_DEPLOYMENT_TARGET=17.5\
		-DCMAKE_OSX_ARCHITECTURES=arm64\
		-DCMAKE_SYSTEM_PROCESSOR=arm64\
		-DCMAKE_OSX_SYSROOT=$(shell xcodebuild -version -sdk appletvos Path)
else ifeq ($(IREE_BUILD_TARGET), tvos_simulator)
	BUILD_TARGET_FLAGS = \
		-DCMAKE_SYSTEM_NAME=tvOS\
		-DCMAKE_OSX_DEPLOYMENT_TARGET=17.5\
		-DCMAKE_OSX_ARCHITECTURES=arm64\
		-DCMAKE_SYSTEM_PROCESSOR=arm64\
		-DCMAKE_OSX_SYSROOT=$(shell xcodebuild -version -sdk appletvsimulator Path)
else
	$(error "Unknown IREE_BUILD_TARGET: $(IREE_BUILD_TARGET), must be one of host, ios, ios_simulator, visionos, visionos_simulator, tvos, tvos_simulator")
endif

.PHONY: install_runtime
install_runtime: $(IREE_INSTALL_DIR)

CMAKE_SOURCES = cmake/src/runtime.cc cmake/src/runtime.h

$(IREE_INSTALL_DIR): $(IREE_DIR) $(CMAKE_SOURCES)
	cmake -G Ninja -B $(IREE_CMAKE_BUILD_DIR) \
		-DCMAKE_BUILD_TYPE=$(IREE_CMAKE_CONFIG)\
		-DIREE_BUILD_COMPILER=OFF\
		-DIREE_RUNTIME_BUILD_DIR=$(IREE_RUNTIME_BUILD_DIR)\
		-DIREE_RUNTIME_INCLUDE_PATH=$(IREE_RUNTIME_INCLUDE_PATH)\
		-DIREE_DIR=$(IREE_DIR) \
		$(BUILD_TARGET_FLAGS)
	cmake --build $(IREE_CMAKE_BUILD_DIR) --config $(IREE_CMAKE_CONFIG)
	cmake --install $(IREE_CMAKE_BUILD_DIR) --config $(IREE_CMAKE_CONFIG) --prefix $(IREE_INSTALL_DIR)


### NxIREE Runtime NIF library

NX_IREE_SO = $(MIX_APP_PATH)/priv/libnx_iree.so
NX_IREE_CACHE_SO = cache/libnx_iree.so
NX_IREE_SO_LINK_PATH = $(CWD_RELATIVE_TO_PRIV_PATH)/$(NX_IREE_CACHE_SO)

NX_IREE_RUNTIME_LIB = cache/iree-runtime/
NX_IREE__IREE_RUNTIME_INCLUDE_PATH = $(NX_IREE_RUNTIME_LIB)/include

CFLAGS = -fPIC -I$(ERTS_INCLUDE_DIR) -I$(NX_IREE__IREE_RUNTIME_INCLUDE_PATH) -Wall -Wno-sign-compare \
	 -Wno-unused-parameter -Wno-missing-field-initializers -Wno-comment \
	 -std=c++17 -w

ifdef DEBUG
	CFLAGS += -g
else
	CFLAGS += -O3
endif

LDFLAGS = -L$(NX_IREE_RUNTIME_LIB) -lnx_iree_runtime -shared

ifeq ($(shell uname -s), Darwin)
	LDFLAGS += -flat_namespace -undefined dynamic_lookup -rpath @loader_path/iree-runtime
else
	# Use a relative RPATH, so at runtime libexla.so looks for libxla_extension.so
	# in ./lib regardless of the absolute location. This way priv can be safely
	# packed into an Elixir release. Also, we use $$ to escape Makefile variable
	# and single quotes to escape shell variable
	LDFLAGS += -Wl,-rpath,'$$ORIGIN/iree-runtime'
endif

CUDA_PRESENT := $(shell command -v nvcc >/dev/null 2>&1 && echo true || echo false)

ifeq ($(CUDA_PRESENT), true)
	CFLAGS += -DCUDA_ENABLED
endif

NX_IREE_LIB_DIR = $(MIX_APP_PATH)/priv/iree-runtime
NX_IREE_LIB_LINK_PATH = $(CWD_RELATIVE_TO_PRIV_PATH)/$(NX_IREE_RUNTIME_LIB)
NX_IREE_CACHE_SO_LINK_PATH = $(CWD_RELATIVE_TO_PRIV_PATH)/$(NX_IREE_CACHE_SO)

SOURCES = $(wildcard c_src/*.cc)
HEADERS = $(wildcard c_src/*.h)
OBJECTS = $(patsubst c_src/%.cc,cache/objs/%.o,$(SOURCES))

nx_iree: $(NX_IREE__IREE_RUNTIME_INCLUDE_PATH) $(NX_IREE_SO)

$(NX_IREE_SO): $(NX_IREE_CACHE_SO)
	@ echo $(CWD_RELATIVE_TO_PRIV_PATH)
	@ mkdir -p $(CWD_RELATIVE_TO_PRIV_PATH)
	@ if [ "${MIX_BUILD_EMBEDDED}" = "true" ]; then \
		cp -a $(abspath $(NX_IREE_RUNTIME_LIB)) $(NX_IREE_LIB_DIR) ; \
		cp -a $(abspath $(NX_IREE_CACHE_SO)) $(NX_IREE_SO) ; \
	else \
		ln -sf $(NX_IREE_LIB_LINK_PATH) $(NX_IREE_LIB_DIR) ; \
		ln -sf $(NX_IREE_CACHE_SO_LINK_PATH) $(NX_IREE_SO) ; \
	fi

$(NX_IREE_CACHE_SO): $(OBJECTS)
	$(CXX) -shared -o $@ $^ $(LDFLAGS)

# This rule may be overriden by the mix.exs compiler rule
# in that it may download the .so instead of compiling it locally
# It assumes that the .so has at least already been compiled with cmake
$(NX_IREE__IREE_RUNTIME_INCLUDE_PATH):
	cp -r iree-runtime/host/install $(dir $@)

cache/objs/%.o: c_src/%.cc
	@ mkdir -p $(dir $@)
	$(CXX) $(CFLAGS) -o $@ -c $<

# Print IREE Dir
PTD:
	@ echo $(IREE_DIR)

clean:
	rm -rf cache/objs
	rm -rf $(TARGET_DIR)
