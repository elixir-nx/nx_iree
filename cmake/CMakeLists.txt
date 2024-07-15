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

set(IREE_HAL_DRIVER_DEFAULTS ON)
set(IREE_HAL_DRIVER_LOCAL_SYNC ON)
set(IREE_HAL_EXECUTABLE_LOADER_DEFAULTS OFF)
set(IREE_HAL_EXECUTABLE_LOADER_EMBEDDED_ELF ON)

if(CMAKE_BUILD_TYPE MATCHES MinSizeRel)
  set(IREE_SIZE_OPTIMIZED ON)
endif()

file(GLOB iree_runtime_sources CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cc" "${CMAKE_CURRENT_SOURCE_DIR}/src/*.h")
add_library(${_NAME} SHARED ${iree_runtime_sources})

set(__BUILD_DIR "${IREE_RUNTIME_BUILD_DIR}")

add_subdirectory("${NX_IREE_SOURCE_DIR}" ${__BUILD_DIR} EXCLUDE_FROM_ALL)

install(
    TARGETS ${_NAME}
    DESTINATION "."
)

set_target_properties(${_NAME} PROPERTIES SUFFIX ".so")

set_target_properties(${_NAME} PROPERTIES
    INSTALL_RPATH_USE_LINK_PATH TRUE
    BUILD_WITH_INSTALL_RPATH TRUE
)

if($ENV{DEBUG})
  set(CMAKE_BUILD_TYPE Debug)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g")
endif()

if(NOT APPLE)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -shared -fvisibility=default")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--export-dynamic")
else()
  # Although the compiler complains about not using these,
  # things only work with them set
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -undefined dynamic_lookup -fvisibility=default")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-export_dynamic")
  check_c_compiler_flag("-arch arm64" ARM64_SUPPORTED)
  if(ARM64_SUPPORTED)
      set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DMAC_ARM64")
  endif()
endif()

# Ensure visibility of all symbols
set(CMAKE_CXX_VISIBILITY_PRESET default)
set(CMAKE_VISIBILITY_INLINES_HIDDEN OFF)

target_compile_options(${_NAME} PUBLIC ${IREE_DEFAULT_COPTS})

add_definitions(-DLLVM_DISABLE_ABI_BREAKING_CHECKS_ENFORCING=1)

target_link_libraries(${_NAME} iree_runtime_runtime)
target_link_libraries(${_NAME} iree_tooling_context_util)

# Install the header files - this will make it easier to copy them over
# to the final bundle.

install(DIRECTORY "${IREE_RUNTIME_INCLUDE_PATH}"
        DESTINATION "include"
        FILES_MATCHING PATTERN "*.h")

file(GLOB HEADER_FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/*.h")

install(FILES ${HEADER_FILES}
        DESTINATION "include/nx_iree")
