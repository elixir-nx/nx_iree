message("Compiling for WebAssembly/Emscripten")
set(EMSCRIPTEN ON)
set(IREE_BUILD_COMPILER OFF)
set(IREE_BUILD_TESTS OFF)

# Emscripten builds don't support embedded ELF libraries.
set(IREE_HAL_DRIVER_DEFAULTS OFF)
set(IREE_HAL_EXECUTABLE_LOADER_EMBEDDED_ELF OFF)
set(IREE_HAL_EXECUTABLE_PLUGIN_EMBEDDED_ELF OFF)
set(IREE_HAL_EXECUTABLE_PLUGIN_DEFAULTS OFF)
set(IREE_HAL_EXECUTABLE_LOADER_SYSTEM_LIBRARY ON)
set(IREE_HAL_DRIVER_LOCAL_SYNC ON)

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

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} \
-DEMSCRIPTEN -fvisibility=default \
-O3 -sMAIN_MODULE=2 -sENVIRONMENT=web \
-sNO_DISABLE_EXCEPTION_CATCHING -sNO_DISABLE_EXCEPTION_THROWING \
--no-entry -sWASM_BIGINT -sALLOW_MEMORY_GROWTH=1 \
-sEXPORTED_FUNCTIONS='${EXPORTED_FUNCTIONS}' \
-sEXPORTED_RUNTIME_METHODS='${EXPORTED_RUNTIME_METHODS}' \
-sDEFAULT_LIBRARY_FUNCS_TO_INCLUDE=free,malloc")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -lembind")

# Define the output files for both WebAssembly and JavaScript
set(WASM_OUTPUT "${CMAKE_BINARY_DIR}/${_NAME}.wasm")
set(JS_OUTPUT "${CMAKE_BINARY_DIR}/${_NAME}.mjs")

# Build the WebAssembly executable
add_executable(${_NAME} ${iree_runtime_sources})

set_target_properties(${_NAME} PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
  ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
  SUFFIX ".mjs"
)

install(
  FILES ${WASM_OUTPUT} ${JS_OUTPUT}
  DESTINATION "."
)

target_link_libraries(${_NAME}
  iree_runtime_runtime
  iree_hal_local_executable_plugin_manager
  iree_hal_local_loaders_system_library_loader
  iree_hal_local_loaders_vmvx_module_loader
  iree_hal_drivers_local_sync_sync_driver
)