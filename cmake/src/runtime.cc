#include "runtime.h"

#include <iree/hal/api.h>
#include <iree/hal/drivers/init.h>

#include <iostream>
#include <sstream>

#define RETURN_PAIR_IF_ERROR(status) \
  if (!iree_status_is_ok(status)) {  \
    return {status, std::nullopt};   \
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

iree_hal_device_t *create_device(const std::string &device_uri) {
  iree_hal_device_t *device = nullptr;
  iree_status_t status = iree_hal_register_all_available_drivers(iree_hal_driver_registry_default());

  if (!iree_status_is_ok(status)) {
    return nullptr;
  }

  status = iree_hal_create_device(
      iree_hal_driver_registry_default(),
      iree_make_cstring_view(device_uri.c_str()),
      iree_allocator_system(), &device);

  if (!iree_status_is_ok(status)) {
    return nullptr;
  }

  return device;
}

std::pair<iree_status_t, std::optional<std::vector<iree_hal_buffer_view_t *>>>
call(iree_vm_instance_t *instance, iree_hal_device_t *device, unsigned char *bytecode, size_t bytecode_size, std::vector<iree::runtime::IREEInput *> exla_inputs) {
  iree_vm_module_t *hal_module = nullptr;
  iree_vm_module_t *bytecode_module = nullptr;
  iree_vm_context_t *context = nullptr;
  const char kMainFunctionName[] = "module.main";
  iree_vm_function_t main_function;
  iree_vm_list_t *inputs = nullptr;
  iree_vm_list_t *outputs = nullptr;

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

  std::vector<iree_hal_buffer_view_t *> results;
  results.resize(output_signature.size);
  for (int i = 0; i < output_signature.size; i++) {
    iree_hal_buffer_view_t *output_buffer_view = iree_vm_list_get_buffer_view_retain(outputs, i);
    if (!output_buffer_view) {
      return {iree_make_status(IREE_STATUS_NOT_FOUND, "can't get output buffer view [index=%d]", i), std::nullopt};
    }

    results[i] = output_buffer_view;
  }

  iree_vm_list_release(inputs);
  iree_vm_list_release(outputs);
  iree_vm_context_release(context);
  return {iree_ok_status(), results};
}

iree_status_t read_buffer(iree_hal_device_t *device, iree_hal_buffer_view_t *buffer_view, void *output_buffer, size_t num_bytes) {
  iree_hal_buffer_t *buffer = iree_hal_buffer_view_buffer(buffer_view);

  iree_device_size_t num_bytes_actual = num_bytes == -1 ? iree_hal_buffer_byte_length(buffer) : (iree_device_size_t)num_bytes;

  return iree_hal_device_transfer_d2h(
      device, buffer, 0, output_buffer,
      num_bytes_actual, IREE_HAL_TRANSFER_BUFFER_FLAG_DEFAULT,
      iree_infinite_timeout());
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