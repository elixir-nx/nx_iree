// Copyright 2023 The IREE Authors
//
// Licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

#ifndef IREE_HAL_DRIVERS_HIP_DEVICE_H_
#define IREE_HAL_DRIVERS_HIP_DEVICE_H_

#include <stdint.h>

#include "iree/base/api.h"
#include "iree/hal/api.h"
#include "iree/hal/drivers/hip/api.h"
#include "iree/hal/drivers/hip/dynamic_symbols.h"
#include "iree/hal/drivers/hip/rccl_dynamic_symbols.h"

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

// Creates a device that owns and manages its own hipCtx_t.
iree_status_t iree_hal_hip_device_create(
    iree_hal_driver_t* driver, iree_string_view_t identifier,
    const iree_hal_hip_device_params_t* params,
    const iree_hal_hip_dynamic_symbols_t* symbols,
    const iree_hal_hip_nccl_dynamic_symbols_t* nccl_symbols, hipDevice_t device,
    iree_allocator_t host_allocator, iree_hal_device_t** out_device);

// Creates a HIP stream-backed command buffer using resources from the
// given |base_device|.
iree_status_t iree_hal_hip_device_create_stream_command_buffer(
    iree_hal_device_t* base_device, iree_hal_command_buffer_mode_t mode,
    iree_hal_command_category_t command_categories,
    iree_host_size_t binding_capacity,
    iree_hal_command_buffer_t** out_command_buffer);

// Returns the HIP context bound to the given |device| if it is a HIP device
// and otherwise returns NULL.
//
// WARNING: this API is unsafe and unstable. HAL devices may have any number of
// contexts and the context may be in use on other threads.
hipCtx_t iree_hal_hip_device_context(iree_hal_device_t* device);

// Returns the dynamic symbol table from the |device| if it is a HIP device
// and otherwise returns NULL.
//
// WARNING: the symbols are only valid for as long as the device is. Hosting
// libraries and applications should prefer to either link against HIP
// themselves or maintain their own dynamic linking support: the IREE runtime
// only provides the symbols required by the HAL driver and not the entirety of
// the API.
const iree_hal_hip_dynamic_symbols_t* iree_hal_hip_device_dynamic_symbols(
    iree_hal_device_t* device);

// Hide the cast in a function as HIP deliberately added a type name for it.
// HIP seem to not provide cast functions.
// It will probably never going to change, but lets not pretend everywhere it
// is void*.
static inline iree_device_size_t iree_hal_hip_device_ptr_to_device_size(
    hipDeviceptr_t p) {
  return (uintptr_t)p;
}
static inline hipDeviceptr_t iree_hal_hip_device_size_to_hip_device_prt(
    iree_device_size_t p) {
  return (hipDeviceptr_t)p;
}

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // IREE_HAL_DRIVERS_HIP_DEVICE_H_
