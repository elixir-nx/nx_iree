# Environment variables passed via elixir_make
# IREE_GIT_REV
# IREE_SOURCE_DIR

# System vars
TEMP ?= $(HOME)/.cache
BUILD_CACHE ?= $(TEMP)/nx_iree

IREE_REPO ?= https://github.com/iree-org/iree

IREE_NS = iree-$(IREE_GIT_REV)
IREE_DIR = $(BUILD_CACHE)/$(IREE_NS)

IREE_INSTALL_DIR ?= $(IREE_SOURCE_DIR)/install

compile: $(IREE_INSTALL_DIR)

$(IREE_DIR):
	mkdir -p $(BUILD_CACHE) && \
	git clone $(IREE_REPO) $(IREE_DIR) && \
	cd $(IREE_DIR) && \
	git checkout $(IREE_GIT_REV) && \
	git submodule update --init --recursive --depth 1

IREE_CMAKE_BUILD_DIR ?= $(abspath iree-runtime/iree-build)
IREE_RUNTIME_INCLUDE_PATH := $(abspath $(IREE_DIR)/runtime/src/iree)
IREE_RUNTIME_BUILD_DIR ?= $(abspath iree-runtime/build)
IREE_RUNTIME_INSTALL_DIR ?= $(abspath iree-runtime/install)

IREE_CMAKE_CONFIG ?= Release

$(IREE_RUNTIME_BUILD_DIR): $(IREE_DIR)
	cmake -G Ninja -S $(IREE_DIR) -B $(IREE_RUNTIME_BUILD_DIR) \
		-DCMAKE_INSTALL_PREFIX=$(IREE_RUNTIME_BUILD_DIR)/install \
		-DIREE_BUILD_TESTS=OFF \
		-DIREE_BUILD_SAMPLES=OFF \
		-DIREE_ENABLE_ASSERTIONS=ON \
		-DIREE_BUILD_COMPILER=OFF \
		-DCMAKE_BUILD_TYPE=$(IREE_CMAKE_CONFIG) \
		-DCMAKE_CXX_FLAGS="-fvisibility=hidden"
	cmake --build $(IREE_RUNTIME_BUILD_DIR)
	cmake --build $(IREE_RUNTIME_BUILD_DIR) --target install

$(IREE_INSTALL_DIR): $(IREE_DIR) $(IREE_RUNTIME_BUILD_DIR)
	cmake -S cmake -B $(IREE_CMAKE_BUILD_DIR) \
		-DIREE_RUNTIME_INCLUDE_PATH=$(IREE_RUNTIME_INCLUDE_PATH) \
		-DCMAKE_BUILD_TYPE=$(IREE_CMAKE_CONFIG)\
		-DIREE_BUILD_COMPILER=OFF\
		-DIREE_RUNTIME_BUILD_DIR=$(IREE_RUNTIME_BUILD_DIR)\
		-DIREE_RUNTIME_INCLUDE_PATH=$(IREE_RUNTIME_INCLUDE_PATH)\
		-DIREE_DIR=$(IREE_DIR)
	cmake --build $(IREE_CMAKE_BUILD_DIR) --config $(IREE_CMAKE_CONFIG)
	cmake --install $(IREE_CMAKE_BUILD_DIR) --config $(IREE_CMAKE_CONFIG) --prefix $(IREE_RUNTIME_INSTALL_DIR)

# Print IREE Dir
PTD:
	@ echo $(IREE_DIR)

clean:
	rm -rf $(OPENXLA_DIR)
	rm -rf $(TARGET_DIR)
