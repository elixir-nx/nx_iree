#include "runtime.h"

#include <iree/hal/api.h>
#include <iree/hal/drivers/init.h>
#include <iree/tooling/device_util.h>

#include <iostream>
#include <sstream>
#include <vector>

#ifdef CUDA_ENABLED
#include <iree/hal/drivers/cuda/cuda_device.h>
#define RUN_IF_CUDA_ENABLED(CODE) CODE
#else
#define RUN_IF_CUDA_ENABLED(CODE) ;
#endif

#define RETURN_PAIR_IF_ERROR(status) \
  if (!iree_status_is_ok(status)) {  \
    return {status, std::nullopt};   \
  }

iree::runtime::Device::~Device() {
  if (ref) {
    iree_hal_device_release(ref);
  }
}

iree::runtime::IREETensor::IREETensor(iree_hal_buffer_view_t *buffer_view, iree_hal_element_type_t type) : buffer_view(buffer_view), type(type) {
  size = iree_hal_buffer_view_byte_length(buffer_view);
}

iree::runtime::IREETensor::IREETensor(void *data, size_t size, std::vector<int64_t> in_dims, iree_hal_element_type_t type) : size(size), type(type) {
  dims.reserve(in_dims.size());

  for (auto dim : in_dims) {
    dims.push_back(static_cast<iree_hal_dim_t>(dim));
  }

  this->data = std::malloc(size);  // Allocate memory
  std::memcpy(this->data, data, size);

  this->buffer_view = nullptr;
}

iree_vm_instance_t *create_instance() {
  iree_vm_instance_t *instance = nullptr;
  iree_status_t status = iree_vm_instance_create(IREE_VM_TYPE_CAPACITY_DEFAULT, iree_allocator_system(), &instance);
  if (!iree_status_is_ok(status)) {
    return nullptr;
  }

  status = iree_hal_module_register_all_types(instance);
  if (!iree_status_is_ok(status)) {
    iree_vm_instance_release(instance);
    return nullptr;
  }

  return instance;
}

iree_status_t register_all_drivers(iree_hal_driver_registry_t *registry) {
  iree_status_t status = iree_hal_register_all_available_drivers(registry);
  return status;
}

std::pair<iree_status_t, std::vector<iree::runtime::Driver *>>
list_drivers(iree_hal_driver_registry_t *registry) {
  size_t driver_info_count;
  iree_hal_driver_info_t *driver_infos;

  iree_status_t status = iree_hal_driver_registry_enumerate(
      registry,
      iree_allocator_system(),
      &driver_info_count,
      &driver_infos);

  if (!iree_status_is_ok(status)) {
    return {status, {}};
  }

  std::vector<iree::runtime::Driver *> drivers;

  for (size_t i = 0; i < driver_info_count; i++) {
    auto info = driver_infos[i];

    auto driver = new iree::runtime::Driver(
        info.driver_name.data, info.driver_name.size,
        info.full_name.data, info.full_name.size);

    if (driver->name == "hip") {
      continue;
    }
    drivers.push_back(driver);
  }

  return {iree_ok_status(), drivers};
}

iree_status_t list_devices(iree_hal_driver_registry_t *registry, std::vector<iree::runtime::Device *> &devices) {
  auto [status, drivers] = list_drivers(registry);
  if (!iree_status_is_ok(status)) {
    return status;
  }

  for (auto driver : drivers) {
    std::vector<iree::runtime::Device *> driver_devices;

    status = list_devices(registry, driver->name, driver_devices);
    if (!iree_status_is_ok(status)) {
      return status;
    }

    devices.insert(devices.end(), driver_devices.begin(), driver_devices.end());
  }

  return iree_ok_status();
}

iree_status_t list_devices(iree_hal_driver_registry_t *registry, std::string driver_name, std::vector<iree::runtime::Device *> &devices) {
  size_t device_info_count;
  iree_hal_device_info_t *device_infos;
  iree_hal_driver_t *driver;

  iree_status_t status = iree_hal_driver_registry_try_create(
      registry,
      iree_make_cstring_view(driver_name.c_str()),
      iree_allocator_system(),
      &driver);

  if (!iree_status_is_ok(status)) {
    iree_hal_driver_release(driver);
    return status;
  }

  auto out_device = new iree::runtime::Device(driver_name);
  status = iree_hal_driver_create_default_device(driver, iree_allocator_system(),
                                                 &out_device->ref);
  if (!iree_status_is_ok(status)) {
    return status;
  }

  out_device->uri = driver_name + "://default";
  devices.push_back(out_device);

  status = iree_hal_driver_query_available_devices(
      driver, iree_allocator_system(), &device_info_count, &device_infos);

  if (!iree_status_is_ok(status)) {
    iree_hal_driver_release(driver);
    return status;
  }

  for (size_t i = 0; i < device_info_count; i++) {
    auto device = new iree::runtime::Device(driver_name);
    auto info = device_infos[i];
    device->uri = driver_name + "://" + std::string(info.path.data, info.path.size);

    status = iree_hal_create_device(
        registry,
        iree_make_cstring_view(device->uri.c_str()),
        iree_allocator_system(),
        &device->ref);

    if (!iree_status_is_ok(status)) {
      iree_hal_driver_release(driver);
      return status;
    }

    RUN_IF_CUDA_ENABLED(
        if (driver_name == "cuda") {
          const iree_hal_cuda_dynamic_symbols_t *cuda_symbols = iree_hal_cuda_device_dynamic_symbols(device->ref);
          auto ctx = iree_hal_cuda_device_context(device->ref);
          cuda_symbols->cuCtxSetCurrent(ctx);
        });

    devices.push_back(device);
  }

  iree_hal_driver_release(driver);
  return iree_ok_status();
}

iree_hal_device_t *create_device(iree_hal_driver_registry_t *registry, const std::string &device_uri) {
  iree_hal_device_t *device = nullptr;

  iree_status_t status = iree_hal_create_device(
      registry,
      iree_make_cstring_view(device_uri.c_str()),
      iree_allocator_system(), &device);

  RUN_IF_CUDA_ENABLED(
      if (device_uri.find("cuda://") != std::string::npos) {
        const iree_hal_cuda_dynamic_symbols_t *cuda_symbols = iree_hal_cuda_device_dynamic_symbols(device);
        auto ctx = iree_hal_cuda_device_context(device);
        cuda_symbols->cuCtxSetCurrent(ctx);
      });

  if (!iree_status_is_ok(status)) {
    return nullptr;
  }

  return device;
}

std::pair<iree_status_t, std::optional<std::vector<iree::runtime::IREETensor *>>>
call(iree_vm_instance_t *instance, iree_hal_device_t *device, std::string driver_name, unsigned char *bytecode, size_t bytecode_size, std::vector<iree::runtime::IREETensor *> exla_inputs) {
  iree_vm_module_t *hal_module = nullptr;
  iree_vm_module_t *bytecode_module = nullptr;
  iree_vm_context_t *context = nullptr;
  const char kMainFunctionName[] = "module.main";
  iree_vm_function_t main_function;
  iree_vm_list_t *inputs = nullptr;
  iree_vm_list_t *outputs = nullptr;

  RUN_IF_CUDA_ENABLED(
      if (driver_name == "cuda") {
        const iree_hal_cuda_dynamic_symbols_t *cuda_symbols = iree_hal_cuda_device_dynamic_symbols(device);
        auto ctx = iree_hal_cuda_device_context(device);
        cuda_symbols->cuCtxSetCurrent(ctx);
      });

  RETURN_PAIR_IF_ERROR(iree_hal_module_create(
      instance, /*device_count=*/1, &device, IREE_HAL_MODULE_FLAG_SYNCHRONOUS,
      iree_allocator_system(), &hal_module));

  // (kFloat4, sizeof(kFloat4))
  const iree_const_byte_span_t module_data = iree_make_const_byte_span(bytecode, bytecode_size);

  RETURN_PAIR_IF_ERROR(iree_vm_bytecode_module_create(
      instance, module_data, iree_allocator_null(), iree_allocator_system(),
      &bytecode_module));

  iree_vm_module_t *modules[] = {hal_module, bytecode_module};
  RETURN_PAIR_IF_ERROR(iree_vm_context_create_with_modules(
      instance, IREE_VM_CONTEXT_FLAG_NONE, IREE_ARRAYSIZE(modules), &modules[0],
      iree_allocator_system(), &context));
  iree_vm_module_release(hal_module);
  iree_vm_module_release(bytecode_module);

  RETURN_PAIR_IF_ERROR(iree_vm_context_resolve_function(
      context, iree_make_cstring_view(kMainFunctionName), &main_function));

  RETURN_PAIR_IF_ERROR(iree_vm_list_create(iree_vm_make_undefined_type_def(), exla_inputs.size(), iree_allocator_system(), &inputs));

  for (auto input : exla_inputs) {
    iree_vm_ref_t arg_buffer_view_ref;

    if (input->buffer_view) {
      arg_buffer_view_ref = iree_hal_buffer_view_move_ref(input->buffer_view);
    } else {
      iree_hal_buffer_view_t *arg_buffer_view = nullptr;
      RETURN_PAIR_IF_ERROR(iree_hal_buffer_view_allocate_buffer_copy(
          device, iree_hal_device_allocator(device), input->dims.size(), input->dims.data(),
          input->type, IREE_HAL_ENCODING_TYPE_DENSE_ROW_MAJOR,
          (iree_hal_buffer_params_t){
              .usage = IREE_HAL_BUFFER_USAGE_DEFAULT,
              .type = IREE_HAL_MEMORY_TYPE_DEVICE_LOCAL,
          },
          input->data_byte_span(), &arg_buffer_view));

      arg_buffer_view_ref = iree_hal_buffer_view_move_ref(arg_buffer_view);
    }
    RETURN_PAIR_IF_ERROR(iree_vm_list_push_ref_move(inputs, &arg_buffer_view_ref));
  }

  iree_vm_function_signature_t signature =
      iree_vm_function_signature(&main_function);
  iree_string_view_t input_signature;
  iree_string_view_t output_signature;

  RETURN_PAIR_IF_ERROR(iree_vm_function_call_get_cconv_fragments(
      &signature, &input_signature, &output_signature));

  RETURN_PAIR_IF_ERROR(iree_vm_list_create(iree_vm_make_undefined_type_def(), output_signature.size, iree_allocator_system(), &outputs));

  // Synchronously invoke the function.
  RETURN_PAIR_IF_ERROR(iree_vm_invoke(
      context, main_function, IREE_VM_INVOCATION_FLAG_NONE,
      /*policy=*/NULL, inputs, outputs, iree_allocator_system()));

  std::vector<iree::runtime::IREETensor *> results;
  results.resize(output_signature.size);
  for (int i = 0; i < output_signature.size; i++) {
    iree_hal_buffer_view_t *output_buffer_view = iree_vm_list_get_buffer_view_retain(outputs, i);
    if (!output_buffer_view) {
      return {iree_make_status(IREE_STATUS_NOT_FOUND, "can't get output buffer view [index=%d]", i), std::nullopt};
    }

    iree_host_size_t out_shape_rank = iree_hal_buffer_view_shape_rank(output_buffer_view);
    const iree_hal_dim_t *out_shape = iree_hal_buffer_view_shape_dims(output_buffer_view);
    iree_hal_element_type_t out_type = iree_hal_buffer_view_element_type(output_buffer_view);

    auto tensor = new iree::runtime::IREETensor(output_buffer_view, out_type);
    tensor->dims = std::vector<iree_hal_dim_t>();
    for (int j = 0; j < out_shape_rank; j++) {
      tensor->dims.push_back(out_shape[j]);
    }

    results[i] = tensor;
  }

  iree_vm_list_release(inputs);
  iree_vm_list_release(outputs);
  iree_vm_context_release(context);
  return {iree_ok_status(), results};
}

iree_status_t read_buffer(iree_hal_device_t *device, iree_hal_buffer_view_t *buffer_view, void *output_buffer, size_t num_bytes) {
  iree_hal_buffer_t *buffer = iree_hal_buffer_view_buffer(buffer_view);

  iree_device_size_t num_bytes_actual = num_bytes == -1 ? iree_hal_buffer_byte_length(buffer) : (iree_device_size_t)num_bytes;

  iree_string_view_t device_id = iree_hal_device_id(device);

  std::string device_id_str = std::string(device_id.data, device_id.size);

  RUN_IF_CUDA_ENABLED(
      if (device_id_str.find("cuda") != std::string::npos) {
        const iree_hal_cuda_dynamic_symbols_t *cuda_symbols = iree_hal_cuda_device_dynamic_symbols(device);
        auto ctx = iree_hal_cuda_device_context(device);
        cuda_symbols->cuCtxSetCurrent(ctx);
      });

  iree_status_t status = iree_hal_device_transfer_d2h(
      device, buffer, 0, output_buffer,
      num_bytes_actual, IREE_HAL_TRANSFER_BUFFER_FLAG_DEFAULT,
      iree_infinite_timeout());

  return status;
}

std::string get_status_message(iree_status_t status) {
  char *status_string = NULL;
  size_t status_length = 0;

  auto system_allocator = iree_allocator_system();

  iree_status_to_string(status, &system_allocator, &status_string, &status_length);

  std::stringstream ss;
  ss << "Failed to execute IREE runtime due to error: ";
  ss << status_string;
  iree_status_free(status);
  return ss.str();
}

bool is_ok(iree_status_t status) {
  return iree_status_is_ok(status);
}

iree_hal_driver_registry_t *get_driver_registry() {
  return iree_hal_available_driver_registry();
}