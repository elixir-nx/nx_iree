#pragma once
#include <iree/hal/api.h>
#include <iree/modules/hal/module.h>
#include <iree/modules/hal/types.h>
#include <iree/runtime/api.h>
#include <iree/vm/api.h>
#include <iree/vm/bytecode/module.h>

#include <memory>
#include <optional>
#include <vector>

namespace iree {
namespace runtime {

class Driver {
 public:
  std::string name;
  std::string full_name;

  Driver(const char* name, size_t name_size, const char* full_name, size_t full_name_size) {
    this->name = std::string(name, name_size);
    this->full_name = std::string(full_name, full_name_size);
  }
};

class Device {
 public:
  std::string uri;
  iree_hal_device_t* ref;
  std::string driver_name;

  Device(std::string driver_name) : driver_name(driver_name) {}
  ~Device();
};

class IREEInput {
 public:
  void* data;
  size_t size;
  std::vector<iree_hal_dim_t> dims;
  iree_hal_element_type_t type;
  iree_hal_buffer_view_t* buffer_view;

  IREEInput(iree_hal_buffer_view_t* buffer_view) : buffer_view(buffer_view) {}

  // Default constructor
  IREEInput(void* data, size_t size, std::vector<int64_t> in_dims, iree_hal_element_type_t type) : size(size), type(type) {
    dims.reserve(in_dims.size());

    for (auto dim : in_dims) {
      dims.push_back(static_cast<iree_hal_dim_t>(dim));
    }

    this->data = std::malloc(size);  // Allocate memory
    std::memcpy(this->data, data, size);
  }

  // Destructor
  ~IREEInput() {
    if (data) {
      std::free(data);
      data = nullptr;
    }
  }

  // Disable copy and move semantics for simplicity
  IREEInput(const IREEInput&) = delete;
  IREEInput& operator=(const IREEInput&) = delete;
  IREEInput(IREEInput&&) = delete;
  IREEInput& operator=(IREEInput&&) = delete;

  iree_const_byte_span_t data_byte_span() const {
    return iree_make_const_byte_span(static_cast<uint8_t*>(data), size);
  }
};

}  // namespace runtime
}  // namespace iree

iree_vm_instance_t* create_instance();
iree_hal_driver_registry_t* get_driver_registry();
iree_hal_device_t* create_device(const std::string& device_uri);

std::pair<iree_status_t, std::optional<std::vector<iree_hal_buffer_view_t*>>>
call(iree_vm_instance_t* i, iree_hal_device_t*, unsigned char*, size_t, std::vector<iree::runtime::IREEInput*>);

iree_status_t read_buffer(iree_hal_device_t* device, iree_hal_buffer_view_t* buffer_view, void* output_buffer, size_t num_bytes);
std::string get_status_message(iree_status_t status);

iree_status_t register_all_drivers(iree_hal_driver_registry_t*);

std::pair<iree_status_t, std::vector<iree::runtime::Driver*>> list_drivers(iree_hal_driver_registry_t*);
iree_status_t list_devices(iree_hal_driver_registry_t*, std::vector<iree::runtime::Device*>&);
iree_status_t list_devices(iree_hal_driver_registry_t*, std::string driver_name, std::vector<iree::runtime::Device*>&);

bool is_ok(iree_status_t status);
