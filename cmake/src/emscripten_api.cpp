#include "emscripten_api.h"

#include "runtime.h"

struct nx_iree_vm_instance_t {
  iree_vm_instance_t* ptr;
};

struct nx_iree_driver_registry_t {
  iree_hal_driver_registry_t* ptr;
};

struct nx_iree_device_t {
  iree::runtime::Device* ptr;
};

struct nx_iree_driver_t {
  iree::runtime::Driver* ptr;
};

struct nx_iree_status_t {
  iree_status_t ptr;
};

struct nx_iree_tensor_t {
  iree::runtime::IREETensor* ptr;
};

void free_shared(nx_iree_vm_instance_t* handle) {
  iree_vm_instance_release(handle->ptr);
  delete handle;
}

void free_shared(nx_iree_driver_registry_t* handle) {
  iree_hal_driver_registry_free(handle->ptr);
  delete handle;
}

void free_shared(nx_iree_driver_t* handle) {
  delete handle->ptr;
  delete handle;
}

void free_shared(nx_iree_device_t* handle) {
  delete handle->ptr;
  delete handle;
}

void free_shared(nx_iree_tensor_t* handle) {
  delete handle->ptr;
  delete handle;
}

void free_shared(nx_iree_status_t* handle) {
  iree_status_free(handle->ptr);
  delete handle;
}

template <typename T>
std::shared_ptr<T> make_shared(T* ptr) {
  return std::shared_ptr<T>(ptr, [](T* ptr) { free_shared(ptr); });
}

std::shared_ptr<nx_iree_vm_instance_t>
nx_iree_create_vm_instance() {
  auto instance = new nx_iree_vm_instance_t;
  instance->ptr = create_instance();
  return make_shared(instance);
}

std::shared_ptr<nx_iree_driver_registry_t> nx_iree_create_driver_registry() {
  auto driver_registry = new nx_iree_driver_registry_t;
  driver_registry->ptr = get_driver_registry();
  return make_shared(driver_registry);
}

std::shared_ptr<nx_iree_device_t> nx_iree_create_device(std::shared_ptr<nx_iree_driver_registry_t> registry, std::string device_uri) {
  iree_hal_device_t* raw_device = create_device(registry->ptr, device_uri);

  if (raw_device == nullptr) {
    return nullptr;
  }

  auto device = new nx_iree_device_t;
  device->ptr = new iree::runtime::Device(raw_device);
  return make_shared(device);
}

std::pair<std::shared_ptr<nx_iree_status_t>, std::vector<std::shared_ptr<nx_iree_tensor_t>>> nx_iree_call(
    std::shared_ptr<nx_iree_vm_instance_t> instance,
    std::shared_ptr<nx_iree_device_t> device,
    std::string driver_name,
    unsigned char* bytecode,
    size_t bytecode_size,
    std::vector<std::shared_ptr<nx_iree_tensor_t>> wrapped_inputs) {
  std::vector<iree::runtime::IREETensor*> inputs;
  for (auto wrapped_input : wrapped_inputs) {
    inputs.push_back(wrapped_input->ptr);
  }

  auto [status, opt_outputs] = call(
      instance->ptr,
      device->ptr->ref,
      driver_name,
      bytecode,
      bytecode_size,
      inputs);

  auto wrapped_outputs = std::vector<std::shared_ptr<nx_iree_tensor_t>>();
  if (opt_outputs.has_value()) {
    auto outputs = opt_outputs.value();
    for (size_t i = 0; i < outputs.size(); i++) {
      auto out = new nx_iree_tensor_t;
      out->ptr = outputs[i];
      wrapped_outputs.push_back(make_shared(out));
    }
  }

  nx_iree_status_t* status_handle = new nx_iree_status_t;
  status_handle->ptr = status;
  return std::make_pair(make_shared(status_handle), wrapped_outputs);
}

std::pair<std::shared_ptr<nx_iree_status_t>, void*> nx_iree_read_buffer(std::shared_ptr<nx_iree_device_t> device, std::shared_ptr<nx_iree_tensor_t> tensor, size_t num_bytes) {
  void* output_buffer = malloc(num_bytes);
  auto status = read_buffer(device->ptr->ref, tensor->ptr->buffer_view, output_buffer, num_bytes);
  nx_iree_status_t* status_handle = new nx_iree_status_t;
  status_handle->ptr = status;

  auto shared_status = make_shared(status_handle);
  if (!nx_iree_status_is_ok(shared_status)) {
    free(output_buffer);
    return std::make_pair(shared_status, nullptr);
  }

  return std::make_pair(shared_status, output_buffer);
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

std::pair<std::shared_ptr<nx_iree_status_t>, std::vector<std::pair<std::string, std::shared_ptr<nx_iree_device_t>>>> nx_iree_list_devices(std::shared_ptr<nx_iree_driver_registry_t> registry) {
  std::vector<iree::runtime::Device*> raw_devices;
  auto status = list_devices(registry->ptr, raw_devices);
  auto devices = std::vector<std::pair<std::string, std::shared_ptr<nx_iree_device_t>>>();
  for (auto dev : raw_devices) {
    auto device = new nx_iree_device_t;
    device->ptr = dev;
    devices.push_back(std::make_pair(dev->uri, make_shared(device)));
  }
  nx_iree_status_t* status_handle = new nx_iree_status_t;
  status_handle->ptr = status;
  return std::make_pair(make_shared(status_handle), devices);
}

std::pair<std::shared_ptr<nx_iree_status_t>, std::vector<std::pair<std::string, std::shared_ptr<nx_iree_device_t>>>> nx_iree_list_devices_for_driver(std::shared_ptr<nx_iree_driver_registry_t> registry, std::string driver_name) {
  std::vector<iree::runtime::Device*> raw_devices;
  auto status = list_devices(registry->ptr, driver_name, raw_devices);
  auto devices = std::vector<std::pair<std::string, std::shared_ptr<nx_iree_device_t>>>();
  for (auto dev : raw_devices) {
    auto device = new nx_iree_device_t;
    device->ptr = dev;
    devices.push_back(std::make_pair(dev->uri, make_shared(device)));
  }
  nx_iree_status_t* status_handle = new nx_iree_status_t;
  status_handle->ptr = status;
  return std::make_pair(make_shared(status_handle), devices);
}

bool nx_iree_status_is_ok(std::shared_ptr<nx_iree_status_t> status) {
  return is_ok(status->ptr);
}

extern "C" void ensure_malloc_free() {
  void* ptr = malloc(1);
  free(ptr);
  return;
}