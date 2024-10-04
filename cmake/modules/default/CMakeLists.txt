set(IREE_HAL_DRIVER_DEFAULTS ON)
set(IREE_HAL_DRIVER_LOCAL_SYNC ON)
set(IREE_HAL_EXECUTABLE_LOADER_DEFAULTS OFF)
set(IREE_HAL_EXECUTABLE_LOADER_EMBEDDED_ELF ON)

list(REMOVE_ITEM iree_runtime_sources
  "${CMAKE_SOURCE_DIR}/src/emscripten_api.cc"
  "${CMAKE_SOURCE_DIR}/src/emscripten_api.h"
)

add_library(${_NAME} SHARED ${iree_runtime_sources})

set_target_properties(${_NAME} PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
  ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
  SUFFIX ".so"
)

install(
  TARGETS ${_NAME}
  DESTINATION "."
)

target_link_libraries(${_NAME} iree_runtime_runtime)
target_link_libraries(${_NAME} iree_tooling_context_util)

# Install the header files - this will make it easier to copy them over
# to the final bundle.
install(DIRECTORY "${IREE_RUNTIME_INCLUDE_PATH}"
        DESTINATION "include"
        FILES_MATCHING PATTERN "*.h")

file(GLOB HEADER_FILES "${CMAKE_SOURCE_DIR}/src/*.h")

install(FILES ${HEADER_FILES}
        DESTINATION "include/nx_iree")

if(APPLE)
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