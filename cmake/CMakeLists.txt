cmake_minimum_required(VERSION 3.12 FATAL_ERROR)

set(_NAME nx_iree_runtime)

project(${_NAME} VERSION 1.0 LANGUAGES CXX C)
set_property(GLOBAL PROPERTY USE_FOLDERS ON)
include(CheckCCompilerFlag)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(IREE_INPUT_STABLEHLO ON)
set(IREE_BUILD_TESTS OFF)
set(IREE_BUILD_SAMPLES OFF)

if(CMAKE_BUILD_TYPE MATCHES MinSizeRel)
  set(IREE_SIZE_OPTIMIZED ON)
endif()

file(GLOB iree_runtime_sources CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cc" "${CMAKE_CURRENT_SOURCE_DIR}/src/*.h")

if("$ENV{IREE_BUILD_TARGET}" STREQUAL "webassembly")
  add_subdirectory(modules/emscripten)
else()
  add_subdirectory(modules/default)
endif()

set_target_properties(${_NAME} PROPERTIES
    INSTALL_RPATH_USE_LINK_PATH TRUE
    BUILD_WITH_INSTALL_RPATH TRUE
)

set(__BUILD_DIR "${IREE_RUNTIME_BUILD_DIR}")

add_subdirectory("${NX_IREE_SOURCE_DIR}" ${__BUILD_DIR} EXCLUDE_FROM_ALL)

# Ensure visibility of all symbols
set(CMAKE_CXX_VISIBILITY_PRESET default)
set(CMAKE_VISIBILITY_INLINES_HIDDEN OFF)

target_compile_options(${_NAME} PUBLIC ${IREE_DEFAULT_COPTS})

add_definitions(-DLLVM_DISABLE_ABI_BREAKING_CHECKS_ENFORCING=1)