#include "emscripten_api.h"

#include <iostream>

#include "iree/hal/drivers/local_sync/sync_device.h"
#include "iree/hal/local/executable_plugin_manager.h"
#include "iree/hal/local/loaders/system_library_loader.h"
#include "iree/hal/local/loaders/vmvx_module_loader.h"

#define RETURN_PAIR_IF_ERROR(status) \
  if (!iree_status_is_ok(status)) {  \
    return {status, std::nullopt};   \
  }

iree::runtime::IREETensor::IREETensor(emscripten::val input_data, emscripten::val in_dims, std::string type_string) {
  // Convert the data to a byte array
  this->size = input_data["byteLength"].as<size_t>();
  this->data = std::malloc(size);

  if (this->data == nullptr) {
    throw std::runtime_error("Failed to allocate memory for tensor data");
  }

  // Convert the type string to an element type
  this->type = nx_type_to_iree_type(type_string);

  if (this->type == iree_hal_element_types_t::IREE_HAL_ELEMENT_TYPE_NONE) {
    throw std::runtime_error("Invalid type string: '" + type_string + "'");
  }

  if (this->type == IREE_HAL_ELEMENT_TYPE_INT_8) {
    auto vec = convertJSArrayToNumberVector<int8_t>(input_data);
    memcpy(this->data, vec.data(), this->size);
  } else if (this->type == IREE_HAL_ELEMENT_TYPE_UINT_8) {
    auto vec = convertJSArrayToNumberVector<uint8_t>(input_data);
    memcpy(this->data, vec.data(), this->size);
  } else if (this->type == IREE_HAL_ELEMENT_TYPE_INT_16) {
    auto vec = convertJSArrayToNumberVector<int16_t>(input_data);
    memcpy(this->data, vec.data(), this->size);
  } else if (this->type == IREE_HAL_ELEMENT_TYPE_UINT_16) {
    auto vec = convertJSArrayToNumberVector<uint16_t>(input_data);
    memcpy(this->data, vec.data(), this->size);
  } else if (this->type == IREE_HAL_ELEMENT_TYPE_INT_32) {
    auto vec = convertJSArrayToNumberVector<int32_t>(input_data);
    memcpy(this->data, vec.data(), this->size);
  } else if (this->type == IREE_HAL_ELEMENT_TYPE_UINT_32) {
    auto vec = convertJSArrayToNumberVector<uint32_t>(input_data);
    memcpy(this->data, vec.data(), this->size);
  } else if (this->type == IREE_HAL_ELEMENT_TYPE_INT_64) {
    auto vec = convertJSArrayToNumberVector<int64_t>(input_data);
    memcpy(this->data, vec.data(), this->size);
  } else if (this->type == IREE_HAL_ELEMENT_TYPE_UINT_64) {
    auto vec = convertJSArrayToNumberVector<uint64_t>(input_data);
    memcpy(this->data, vec.data(), this->size);
  } else if (this->type == IREE_HAL_ELEMENT_TYPE_FLOAT_32) {
    auto vec = convertJSArrayToNumberVector<float>(input_data);
    memcpy(this->data, vec.data(), this->size);
  } else if (this->type == IREE_HAL_ELEMENT_TYPE_FLOAT_64) {
    auto vec = convertJSArrayToNumberVector<double>(input_data);
    memcpy(this->data, vec.data(), this->size);
  } else {
    throw std::runtime_error("Unsupported element type: " + std::to_string(this->type));
  }

  // Convert the dimensions to a vector

  // Get the length of the JS array
  size_t length = in_dims["length"].as<size_t>();

  this->dims.reserve(length);
  for (size_t i = 0; i < length; i++) {
    this->dims.push_back(static_cast<iree_hal_dim_t>(in_dims[i].as<int64_t>()));
  }

  this->device = nullptr;
  this->buffer_view = nullptr;
}

std::string serialize_iree_tensor(iree::runtime::IREETensor& tensor) {
  auto serialized = tensor.serialize();
  auto result = std::string(serialized->begin(), serialized->end());

  delete serialized;
  return result;
}

struct nx_iree_vm_instance_t {
  iree_vm_instance_t* ptr;

  ~nx_iree_vm_instance_t() {
    iree_vm_instance_release(ptr);
  }
};

struct nx_iree_driver_registry_t {
  iree_hal_driver_registry_t* ptr;

  ~nx_iree_driver_registry_t() {
    iree_hal_driver_registry_free(ptr);
  }
};

struct nx_iree_driver_t {
  iree::runtime::Driver* ptr;

  ~nx_iree_driver_t() {
    delete ptr;
  }
};

struct nx_iree_status_t {
  iree_status_t ptr;

  ~nx_iree_status_t() {
    iree_status_free(ptr);
  }
};

template <typename T>
std::shared_ptr<T> make_shared(T* ptr) {
  return std::shared_ptr<T>(ptr);
}

std::shared_ptr<nx_iree_vm_instance_t> nx_iree_create_vm_instance() {
  auto instance = new nx_iree_vm_instance_t;
  instance->ptr = create_instance();
  return make_shared(instance);
}

// std::shared_ptr<nx_iree_driver_registry_t> nx_iree_create_driver_registry() {
//   auto driver_registry = new nx_iree_driver_registry_t;
//   driver_registry->ptr = get_driver_registry();
//   return make_shared(driver_registry);
// }

iree_status_t create_device_with_loaders(iree_allocator_t host_allocator,
                                         iree_hal_device_t** out_device) {
  iree_hal_sync_device_params_t params;
  iree_hal_sync_device_params_initialize(&params);

  iree_status_t status = iree_ok_status();

  iree_hal_executable_plugin_manager_t* plugin_manager = NULL;
  if (iree_status_is_ok(status)) {
    status = iree_hal_executable_plugin_manager_create(
        /*capacity=*/0, host_allocator, &plugin_manager);
  }

  iree_hal_executable_loader_t* loaders[2] = {NULL, NULL};
  iree_host_size_t loader_count = 0;
  if (iree_status_is_ok(status)) {
    status = iree_hal_system_library_loader_create(
        plugin_manager, host_allocator, &loaders[loader_count++]);
  }
  if (iree_status_is_ok(status)) {
    status = iree_hal_vmvx_module_loader_create_isolated(
        /*user_module_count=*/0, /*user_modules=*/NULL, host_allocator,
        &loaders[loader_count++]);
  }

  iree_string_view_t identifier = iree_make_cstring_view("local-sync");
  iree_hal_allocator_t* device_allocator = NULL;
  if (iree_status_is_ok(status)) {
    status = iree_hal_allocator_create_heap(identifier, host_allocator,
                                            host_allocator, &device_allocator);
  }

  if (iree_status_is_ok(status)) {
    status = iree_hal_sync_device_create(identifier, &params, loader_count,
                                         loaders, device_allocator,
                                         host_allocator, out_device);
  }

  iree_hal_allocator_release(device_allocator);
  for (iree_host_size_t i = 0; i < loader_count; ++i) {
    iree_hal_executable_loader_release(loaders[i]);
  }
  return status;
}

std::shared_ptr<iree::runtime::Device> nx_iree_create_local_sync_device() {
  iree_hal_device_t* raw_device;
  iree_status_t status = create_device_with_loaders(iree_allocator_system(), &raw_device);

  if (!iree_status_is_ok(status)) {
    std::string msg = get_status_message(status);
    std::cout << msg << std::endl;
    return nullptr;
  }

  if (raw_device == nullptr) {
    return nullptr;
  }

  auto device = new iree::runtime::Device(raw_device);

  auto device_id_view = iree_hal_device_id(raw_device);
  std::string device_id(device_id_view.data, device_id_view.size);
  std::stringstream device_uri;
  device_uri << "local-sync://";
  device_uri << device_id;
  device->uri = device_uri.str();
  device->driver_name = "local-sync";
  return make_shared(device);
}

typedef struct iree_program_state_t {
  iree_runtime_session_t* session;
  iree_vm_module_t* module;
} iree_program_state_t;

void unload_program(iree_program_state_t* program_state) {
  iree_vm_module_release(program_state->module);
  iree_runtime_session_release(program_state->session);
  free(program_state);
}

std::pair<iree_status_t, iree_program_state_t*> load_program(iree_hal_device_t* device, iree_runtime_instance_t* instance,
                                                             uint8_t* vmfb_data, size_t length) {
  iree_program_state_t* program_state = NULL;
  iree_status_t status = iree_allocator_malloc(iree_allocator_system(),
                                               sizeof(iree_program_state_t),
                                               (void**)&program_state);

  if (!iree_status_is_ok(status)) {
    unload_program(program_state);
    return {status, nullptr};
  }

  iree_runtime_session_options_t session_options;
  iree_runtime_session_options_initialize(&session_options);

  status = iree_runtime_session_create_with_device(
      instance, &session_options, device,
      iree_runtime_instance_host_allocator(instance),
      &program_state->session);

  if (!iree_status_is_ok(status)) {
    unload_program(program_state);
    return {status, nullptr};
  }

  status = iree_vm_bytecode_module_create(
      iree_runtime_instance_vm_instance(instance),
      iree_make_const_byte_span(vmfb_data, length),
      /*flatbuffer_allocator=*/iree_allocator_system(),
      iree_allocator_system(), &program_state->module);

  if (!iree_status_is_ok(status)) {
    unload_program(program_state);
    return {status, nullptr};
  }

  status = iree_runtime_session_append_module(program_state->session,
                                              program_state->module);

  if (!iree_status_is_ok(status)) {
    unload_program(program_state);
    return {status, nullptr};
  }
  return {status, program_state};
}

std::pair<iree_status_t, std::optional<std::vector<iree::runtime::IREETensor*>>>
runtime_call(iree_vm_instance_t* instance, iree_hal_device_t* device, std::string driver_name, unsigned char* bytecode, size_t bytecode_size, std::vector<iree::runtime::IREETensor*> exla_inputs) {
  iree_vm_module_t* hal_module = nullptr;
  iree_vm_module_t* bytecode_module = nullptr;
  iree_vm_context_t* context = nullptr;
  const char kMainFunctionName[] = "module.main";

  iree_runtime_instance_t* runtime_instance = nullptr;

  iree_runtime_instance_options_t instance_options;
  iree_runtime_instance_options_initialize(&instance_options);

  RETURN_PAIR_IF_ERROR(iree_runtime_instance_create(
      &instance_options, iree_allocator_system(), &runtime_instance))

  auto result = load_program(device, runtime_instance, bytecode, bytecode_size);
  iree_status_t status = result.first;
  iree_program_state_t* program_state = result.second;

  if (!iree_status_is_ok(status)) {
    return {status, std::nullopt};
  }

  if (!program_state) {
    return {iree_make_status(IREE_STATUS_NOT_FOUND, "can't load program"), std::nullopt};
  }

  iree_runtime_call_t call;
  RETURN_PAIR_IF_ERROR(iree_runtime_call_initialize_by_name(
      program_state->session, iree_make_cstring_view(kMainFunctionName), &call));

  RETURN_PAIR_IF_ERROR(iree_vm_list_create(iree_vm_make_undefined_type_def(), exla_inputs.size(), iree_allocator_system(), &call.inputs));

  for (auto input : exla_inputs) {
    iree_vm_ref_t arg_buffer_view_ref;

    if (input->buffer_view) {
      arg_buffer_view_ref = iree_hal_buffer_view_move_ref(input->buffer_view);
    } else {
      iree_hal_buffer_view_t* arg_buffer_view = nullptr;
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
    RETURN_PAIR_IF_ERROR(iree_vm_list_push_ref_move(call.inputs, &arg_buffer_view_ref));
  }

  iree_vm_function_signature_t signature =
      iree_vm_function_signature(&call.function);
  iree_string_view_t input_signature;
  iree_string_view_t output_signature;

  RETURN_PAIR_IF_ERROR(iree_vm_function_call_get_cconv_fragments(
      &signature, &input_signature, &output_signature));

  RETURN_PAIR_IF_ERROR(iree_vm_list_create(iree_vm_make_undefined_type_def(), output_signature.size, iree_allocator_system(), &call.outputs));

  // Synchronously invoke the function.
  RETURN_PAIR_IF_ERROR(iree_runtime_call_invoke(&call, /*flags=*/0));

  std::vector<iree::runtime::IREETensor*> results;
  results.resize(output_signature.size);
  for (int i = 0; i < output_signature.size; i++) {
    iree_hal_buffer_view_t* output_buffer_view = iree_vm_list_get_buffer_view_retain(call.outputs, i);
    if (!output_buffer_view) {
      return {iree_make_status(IREE_STATUS_NOT_FOUND, "can't get output buffer view [index=%d]", i), std::nullopt};
    }

    iree_hal_element_type_t out_type = iree_hal_buffer_view_element_type(output_buffer_view);

    auto tensor = new iree::runtime::IREETensor(output_buffer_view, out_type, device);
    tensor->data = malloc(tensor->size);
    RETURN_PAIR_IF_ERROR(read_buffer(device, output_buffer_view, tensor->data, -1));

    printf("output tensor size: %zu\n", tensor->size);
    printf("output tensor data: ");
    for (auto i = 0; i < tensor->size; i++) {
      printf("tensor[%d]: %d\n", i, ((uint8_t*)tensor->data)[i]);
    }

    results[i] = tensor;
  }

  return {iree_ok_status(), results};
}

std::pair<std::shared_ptr<nx_iree_status_t>, std::vector<std::shared_ptr<iree::runtime::IREETensor>>> nx_iree_call(
    std::shared_ptr<nx_iree_vm_instance_t> instance,
    std::shared_ptr<iree::runtime::Device> device,
    std::shared_ptr<nx_iree_data_buffer_t> bytecode,
    std::vector<std::shared_ptr<iree::runtime::IREETensor>> wrapped_inputs) {
  std::vector<iree::runtime::IREETensor*> inputs;
  for (auto wrapped_input : wrapped_inputs) {
    inputs.push_back(wrapped_input.get());
  }

  auto [status, opt_outputs] = call(
      instance->ptr,
      device->ref,
      device->driver_name,
      bytecode->data,
      bytecode->size,
      inputs);

  auto wrapped_outputs = std::vector<std::shared_ptr<iree::runtime::IREETensor>>();
  if (opt_outputs.has_value()) {
    auto outputs = opt_outputs.value();
    for (auto entry : outputs) {
      wrapped_outputs.push_back(make_shared(entry));
    }
  }

  nx_iree_status_t* status_handle = new nx_iree_status_t;
  status_handle->ptr = status;
  return std::make_pair(make_shared(status_handle), wrapped_outputs);
}

std::pair<std::shared_ptr<nx_iree_status_t>, std::shared_ptr<nx_iree_data_buffer_t>> nx_iree_read_buffer(std::shared_ptr<iree::runtime::Device> device, std::shared_ptr<iree::runtime::IREETensor> tensor, size_t num_bytes) {
  auto data_buffer = make_shared(new nx_iree_data_buffer_t(num_bytes));
  void* output_buffer = static_cast<void*>(data_buffer->data);
  auto status = read_buffer(device->ref, tensor->buffer_view, output_buffer, num_bytes);
  nx_iree_status_t* status_handle = new nx_iree_status_t;
  status_handle->ptr = status;

  auto shared_status = make_shared(status_handle);
  if (!nx_iree_status_is_ok(shared_status)) {
    return std::make_pair(shared_status, nullptr);
  }

  return std::make_pair(shared_status, data_buffer);
}

std::string nx_iree_get_status_message(std::shared_ptr<nx_iree_status_t> status) {
  return get_status_message(status->ptr);
}

std::shared_ptr<nx_iree_status_t> nx_iree_register_all_drivers(std::shared_ptr<nx_iree_driver_registry_t> registry) {
  auto status = register_all_drivers(registry->ptr);
  nx_iree_status_t* status_handle = new nx_iree_status_t;
  status_handle->ptr = status;
  return make_shared(status_handle);
}

std::pair<std::shared_ptr<nx_iree_status_t>, std::vector<std::pair<std::string, std::shared_ptr<nx_iree_driver_t>>>> nx_iree_list_drivers(std::shared_ptr<nx_iree_driver_registry_t> registry) {
  auto [status, raw_drivers] = list_drivers(registry->ptr);
  auto drivers = std::vector<std::pair<std::string, std::shared_ptr<nx_iree_driver_t>>>();
  for (auto raw_driver : raw_drivers) {
    auto driver = new nx_iree_driver_t;
    driver->ptr = raw_driver;
    drivers.push_back(std::make_pair(raw_driver->name, make_shared(driver)));
  }
  nx_iree_status_t* status_handle = new nx_iree_status_t;
  status_handle->ptr = status;
  return std::make_pair(make_shared(status_handle), drivers);
}

bool nx_iree_status_is_ok(std::shared_ptr<nx_iree_status_t> status) {
  return is_ok(status->ptr);
}

extern "C" void ensure_malloc_free() {
  void* ptr = malloc(1);
  free(ptr);
  return;
}