#include "emscripten_api.h"

#include <iostream>

#ifdef DEBUG
#include "iree/base/tracing/tracy.h"
#endif

#include "iree/hal/drivers/local_sync/sync_device.h"
#include "iree/hal/local/executable_plugin_manager.h"
#include "iree/hal/local/loaders/system_library_loader.h"
#include "iree/hal/local/loaders/vmvx_module_loader.h"

#define RETURN_PAIR_IF_ERROR(status) \
  if (!iree_status_is_ok(status)) {  \
    return {status, std::nullopt};   \
  }

iree::runtime::IREETensor::IREETensor(emscripten::val input_data, emscripten::val in_dims, std::string type_string, std::shared_ptr<iree::runtime::Device> device) {
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

  this->device = device->ref;
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

std::pair<std::shared_ptr<nx_iree_status_t>, std::vector<std::shared_ptr<iree::runtime::IREETensor>>> nx_iree_call(
    std::shared_ptr<nx_iree_vm_instance_t> instance,
    std::shared_ptr<iree::runtime::Device> device,
    std::shared_ptr<nx_iree_data_buffer_t> bytecode,
    std::vector<std::shared_ptr<iree::runtime::IREETensor>> wrapped_inputs) {
  IREE_TRACE_ZONE_BEGIN(nx_iree_call);
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
      entry->size = iree_hal_buffer_byte_length(iree_hal_buffer_view_buffer(entry->buffer_view));
      entry->data = std::malloc(entry->size);
      read_buffer(device->ref, entry->buffer_view, entry->data, entry->size);
      wrapped_outputs.push_back(make_shared(entry));
    }
  }

  nx_iree_status_t* status_handle = new nx_iree_status_t;
  status_handle->ptr = status;
  IREE_TRACE_ZONE_END(nx_iree_call);
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