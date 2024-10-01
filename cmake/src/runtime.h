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

#ifdef __EMSCRIPTEN__
#include <emscripten/val.h>
#endif

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
  uint64_t id;

  Device(iree_hal_device_t* ref) : ref(ref) {}
  Device(std::string driver_name) : driver_name(driver_name) {}
  ~Device();
};

class IREETensor {
 public:
  void* data;
  size_t size;
  std::vector<iree_hal_dim_t> dims;
  iree_hal_element_type_t type;
  iree_hal_buffer_view_t* buffer_view;
  iree_hal_device_t* device;

  IREETensor(char* serialized_data);
  IREETensor(iree_hal_buffer_view_t* buffer_view, iree_hal_element_type_t type, iree_hal_device_t* device, bool copy_buffer = false);
  IREETensor(void* data, size_t size, std::vector<int64_t> in_dims, iree_hal_element_type_t type);

#ifdef __EMSCRIPTEN__
  IREETensor(emscripten::val data, emscripten::val in_dims, std::string type_string);

  // Static method to wrap a raw pointer into a shared_ptr
  static std::shared_ptr<IREETensor> build(emscripten::val data, emscripten::val in_dims, std::string type_string) {
    auto ptr = new IREETensor(data, in_dims, type_string);
    return std::shared_ptr<IREETensor>(ptr);
  }
#endif

  // Destructor
  ~IREETensor();

  void deallocate();

  // Disable copy and move semantics for simplicity
  IREETensor(const IREETensor&) = delete;
  IREETensor& operator=(const IREETensor&) = delete;
  IREETensor(IREETensor&&) = delete;
  IREETensor& operator=(IREETensor&&) = delete;

  iree_const_byte_span_t data_byte_span() const {
    return iree_make_const_byte_span(static_cast<uint8_t*>(data), size);
  }

  // Serializes the tensor to a buffer that can be transmitted over the wire.
  // Fields in order: type, rank, dims, data
  std::vector<char>* serialize();
};

}  // namespace runtime
}  // namespace iree

iree_hal_element_type_t nx_type_to_iree_type(std::string type_string);

iree_vm_instance_t* create_instance();
iree_hal_driver_registry_t* get_driver_registry();
iree_hal_device_t* create_device(iree_hal_driver_registry_t* registry, const std::string& device_uri);

std::pair<iree_status_t, std::optional<std::vector<iree::runtime::IREETensor*>>>
call(iree_vm_instance_t* i, iree_hal_device_t*, std::string, unsigned char*, size_t, std::vector<iree::runtime::IREETensor*>);

iree_status_t read_buffer(iree_hal_device_t* device, iree_hal_buffer_view_t* buffer_view, void* output_buffer, size_t num_bytes);
std::string get_status_message(iree_status_t status);

iree_status_t register_all_drivers(iree_hal_driver_registry_t*);

std::pair<iree_status_t, std::vector<iree::runtime::Driver*>> list_drivers(iree_hal_driver_registry_t*);
iree_status_t list_devices(iree_hal_driver_registry_t*, std::vector<iree::runtime::Device*>&);
iree_status_t list_devices(iree_hal_driver_registry_t*, std::string driver_name, std::vector<iree::runtime::Device*>&);

bool is_ok(iree_status_t status);