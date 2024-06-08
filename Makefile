# Environment variables passed via elixir_make
# IREE_GIT_REV
# IREE_DIR
# IREE_BUILD_TARGET

# System vars
TEMP ?= $(HOME)/.cache
BUILD_CACHE ?= $(TEMP)/nx_iree

IREE_REPO ?= https://github.com/iree-org/iree

IREE_NS = iree-$(IREE_GIT_REV)
IREE_DIR ?= $(BUILD_CACHE)/$(IREE_NS)


# default rule
# compile: build_runtime install_runtime
compile: install_runtime

$(IREE_DIR):
	./scripts/clone_iree.sh $(BUILD_CACHE) $(IREE_GIT_REV) $(IREE_DIR)

IREE_CMAKE_BUILD_DIR ?= $(abspath iree-runtime/iree-build)
IREE_RUNTIME_INCLUDE_PATH := $(abspath $(IREE_DIR)/runtime/src/iree)
IREE_RUNTIME_BUILD_DIR ?= $(abspath iree-runtime/build)
IREE_INSTALL_DIR ?= $(abspath iree-runtime/install)

IREE_CMAKE_CONFIG ?= Release

IREE_BUILD_TARGET ?= host

BUILD_TARGET_FLAGS = ""

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

# $(IREE_RUNTIME_BUILD_DIR): build_runtime

# build_runtime: $(IREE_DIR)
# 	cmake -G Ninja -S $(IREE_DIR) -B $(IREE_RUNTIME_BUILD_DIR) \
# 		-DCMAKE_INSTALL_PREFIX=$(IREE_RUNTIME_BUILD_DIR)/install \
# 		-DIREE_BUILD_TESTS=OFF \
# 		-DIREE_BUILD_SAMPLES=OFF \
# 		-DIREE_ENABLE_ASSERTIONS=ON \
# 		-DIREE_BUILD_COMPILER=OFF \
# 		-DCMAKE_BUILD_TYPE=$(IREE_CMAKE_CONFIG) \
# 		-DCMAKE_CXX_FLAGS="-fvisibility=hidden"
# 	cmake --build $(IREE_RUNTIME_BUILD_DIR)
# 	cmake --build $(IREE_RUNTIME_BUILD_DIR) --target install

install_runtime: $(IREE_DIR)
	+cmake -G Ninja -S cmake -B $(IREE_CMAKE_BUILD_DIR) \
		-DCMAKE_BUILD_TYPE=$(IREE_CMAKE_CONFIG)\
		-DIREE_BUILD_COMPILER=OFF\
		-DIREE_RUNTIME_BUILD_DIR=$(IREE_RUNTIME_BUILD_DIR)\
		-DIREE_RUNTIME_INCLUDE_PATH=$(IREE_RUNTIME_INCLUDE_PATH)\
		-DIREE_BUILD_TARGET=$(IREE_BUILD_TARGET)\
		-DIREE_DIR=$(IREE_DIR) \
		$(BUILD_TARGET_FLAGS)
	+cmake --build $(IREE_CMAKE_BUILD_DIR) --config $(IREE_CMAKE_CONFIG)
	+cmake --install $(IREE_CMAKE_BUILD_DIR) --config $(IREE_CMAKE_CONFIG) --prefix $(IREE_INSTALL_DIR)

# Print IREE Dir
PTD:
	@ echo $(IREE_DIR)

clean:
	rm -rf $(OPENXLA_DIR)
	rm -rf $(TARGET_DIR)
