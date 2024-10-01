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
# set(IREE_HAL_EXECUTABLE_LOADER_EMBEDDED_ELF ON)

if(CMAKE_BUILD_TYPE MATCHES MinSizeRel)
  set(IREE_SIZE_OPTIMIZED ON)
endif()

file(GLOB iree_runtime_sources CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp" "${CMAKE_CURRENT_SOURCE_DIR}/src/*.h")

if("$ENV{IREE_BUILD_TARGET}" STREQUAL "webassembly")
  message("Compiling for WebAssembly/Emscripten")
  set(EMSCRIPTEN ON)
  set(IREE_BUILD_COMPILER OFF)
  set(IREE_BUILD_TESTS OFF)

  # Emscripten builds don't support embedded ELF libraries.
  set(IREE_HAL_DRIVER_DEFAULTS_OFF OFF)
  set(IREE_HAL_EXECUTABLE_LOADER_DEFAULTS ON)
  set(IREE_HAL_EXECUTABLE_LOADER_EMBEDDED_ELF OFF)
  set(IREE_HAL_EXECUTABLE_PLUGIN_EMBEDDED_ELF OFF)
  set(IREE_HAL_EXECUTABLE_PLUGIN_DEFAULTS OFF)
  set(IREE_HAL_EXECUTABLE_LOADER_SYSTEM_LIBRARY ON)

  set(HAVE_POSIX_REGEX 0)

  # Either WASM=1 SIDE_MODULE=1 or WASM=<0|2> MAIN_MODULE=1
  set(EXPORTED_RUNTIME_METHODS_LIST "ccall" "cwrap" "getValue" "setValue")
  set(EXPORTED_RUNTIME_METHODS "")
  foreach(METHOD IN LISTS EXPORTED_RUNTIME_METHODS_LIST)
    set(EXPORTED_RUNTIME_METHODS "${EXPORTED_RUNTIME_METHODS}\"${METHOD}\", ")
  endforeach()
  string(REGEX REPLACE ", $" "" EXPORTED_RUNTIME_METHODS "${EXPORTED_RUNTIME_METHODS}")
  set(EXPORTED_RUNTIME_METHODS "[${EXPORTED_RUNTIME_METHODS}]")

  set(EXPORTED_FUNCTIONS_LIST "_malloc" "_free" "_ensure_malloc_free")
  set(EXPORTED_FUNCTIONS "")
  foreach(METHOD IN LISTS EXPORTED_FUNCTIONS_LIST)
    set(EXPORTED_FUNCTIONS "${EXPORTED_FUNCTIONS}\"${METHOD}\", ")
  endforeach()
  string(REGEX REPLACE ", $" "" EXPORTED_FUNCTIONS "${EXPORTED_FUNCTIONS}")
  set(EXPORTED_FUNCTIONS "[${EXPORTED_FUNCTIONS}]")

  message("EXPORTED_RUNTIME_METHODS: ${EXPORTED_RUNTIME_METHODS}")
  message("EXPORTED_FUNCTIONS: ${EXPORTED_FUNCTIONS}")

  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O0 --no-entry -sWASM_BIGINT -sALLOW_MEMORY_GROWTH=1 -sEXPORTED_FUNCTIONS='${EXPORTED_FUNCTIONS}' -sEXPORTED_RUNTIME_METHODS='${EXPORTED_RUNTIME_METHODS}' -sDEFAULT_LIBRARY_FUNCS_TO_INCLUDE=free,malloc")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -lembind")

  # Define the output files for both WebAssembly and JavaScript
  set(WASM_OUTPUT "${CMAKE_BINARY_DIR}/${_NAME}.wasm")
  set(JS_OUTPUT "${CMAKE_BINARY_DIR}/${_NAME}.mjs")

  # Build the WebAssembly executable
  add_executable(${_NAME} ${iree_runtime_sources})
  set_target_properties(${_NAME} PROPERTIES SUFFIX ".mjs")

  install(
    FILES ${WASM_OUTPUT} ${JS_OUTPUT}
    DESTINATION "."
  )
else()
  list(REMOVE_ITEM iree_runtime_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/emscripten_api.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/emscripten_api.h"
  )

  add_library(${_NAME} SHARED ${iree_runtime_sources})
  set_target_properties(${_NAME} PROPERTIES SUFFIX ".so")
  set(EMSCRIPTEN OFF)


  install(
    TARGETS ${_NAME}
    DESTINATION "."
)
endif()

set_target_properties(${_NAME} PROPERTIES
    INSTALL_RPATH_USE_LINK_PATH TRUE
    BUILD_WITH_INSTALL_RPATH TRUE
)

set(__BUILD_DIR "${IREE_RUNTIME_BUILD_DIR}")

add_subdirectory("${NX_IREE_SOURCE_DIR}" ${__BUILD_DIR} EXCLUDE_FROM_ALL)



if($ENV{DEBUG})
  set(CMAKE_BUILD_TYPE Debug)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g")
endif()

if(EMSCRIPTEN)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DEMSCRIPTEN -fvisibility=default")
elseif(APPLE)
  # Although the compiler complains about not using these,
  # things only work with them set
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -undefined dynamic_lookup -fvisibility=default")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-export_dynamic")
  check_c_compiler_flag("-arch arm64" ARM64_SUPPORTED)
  if(ARM64_SUPPORTED)
      set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DMAC_ARM64")
  endif()
else()
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -shared -fvisibility=default")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--export-dynamic")
endif()

# Ensure visibility of all symbols
set(CMAKE_CXX_VISIBILITY_PRESET default)
set(CMAKE_VISIBILITY_INLINES_HIDDEN OFF)

target_compile_options(${_NAME} PUBLIC ${IREE_DEFAULT_COPTS})

add_definitions(-DLLVM_DISABLE_ABI_BREAKING_CHECKS_ENFORCING=1)

target_link_libraries(${_NAME} iree_runtime_runtime)
target_link_libraries(${_NAME} iree_tooling_context_util)
target_link_libraries(${_NAME}
  iree_hal_local_executable_plugin_manager
  iree_hal_local_loaders_system_library_loader
  iree_hal_local_loaders_vmvx_module_loader
  iree_hal_drivers_local_sync_sync_driver
)

# Install the header files - this will make it easier to copy them over
# to the final bundle.

if(NOT EMSCRIPTEN)
  install(DIRECTORY "${IREE_RUNTIME_INCLUDE_PATH}"
          DESTINATION "include"
          FILES_MATCHING PATTERN "*.h")

  file(GLOB HEADER_FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/*.h")

  install(FILES ${HEADER_FILES}
          DESTINATION "include/nx_iree")
endif()