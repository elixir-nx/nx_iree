#ifndef EMSCRIPTEN_API_H
#define EMSCRIPTEN_API_H

#include <emscripten.h>  // Include the Emscripten header for EMSCRIPTEN_KEEPALIVE
#include <emscripten/bind.h>
#include <emscripten/val.h>

#include <cstdbool>
#include <cstddef>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

#include "runtime.h"

typedef struct nx_iree_vm_instance_t nx_iree_vm_instance_t;
typedef struct nx_iree_driver_registry_t nx_iree_driver_registry_t;
typedef struct nx_iree_status_t nx_iree_status_t;

class nx_iree_data_buffer_t {
 public:
  uint8_t* data;
  size_t size;

  nx_iree_data_buffer_t(size_t size) : size(size) {
    data = static_cast<uint8_t*>(malloc(size));
    if (data == nullptr) {
      throw std::runtime_error("Failed to allocate memory.");
    }
  }

  static std::shared_ptr<nx_iree_data_buffer_t> allocate(size_t size) {
    auto ptr = new nx_iree_data_buffer_t(size);
    return std::shared_ptr<nx_iree_data_buffer_t>(ptr);
  }

  // Call using something like:
  // decoded = atob(base64_string);
  // array = Uint8Array.from(decoded, c => c.charCodeAt(0));
  // dataBuffer = Module.DataBuffer(array)
  // or Module.DataBuffer(array, false) if you don't want to copy the data
  // (but you must keep the reference to the array for as long as this buffer is used);
  nx_iree_data_buffer_t(emscripten::val array) {
    size = array["byteLength"].as<size_t>();
    data = static_cast<uint8_t*>(malloc(size));
    if (data == nullptr) {
      throw std::runtime_error("Failed to allocate memory.");
    }

    // Access the WebAssembly memory (HEAPU8) as a Uint8Array from JavaScript
    emscripten::val heapU8 = emscripten::val::module_property("HEAPU8");

    // Copy data from the JavaScript Uint8Array (array) to the WebAssembly memory (data pointer)
    heapU8.call<void>("set", array, reinterpret_cast<uintptr_t>(data));
  }

  static std::shared_ptr<nx_iree_data_buffer_t> create(emscripten::val array) {
    auto ptr = new nx_iree_data_buffer_t(array);
    return std::shared_ptr<nx_iree_data_buffer_t>(ptr);
  }

  ~nx_iree_data_buffer_t() {
    free(data);
  }

  emscripten::val get_data() {
    return emscripten::val(emscripten::typed_memory_view(size, data));
  }
};

using namespace emscripten;
using iree::runtime::Device;
using iree::runtime::IREETensor;
using std::pair, std::shared_ptr;

std::string serialize_iree_tensor(IREETensor& tensor);

EMSCRIPTEN_KEEPALIVE
shared_ptr<nx_iree_vm_instance_t>
nx_iree_create_vm_instance();

// EMSCRIPTEN_KEEPALIVE
// shared_ptr<nx_iree_driver_registry_t> nx_iree_create_driver_registry();

EMSCRIPTEN_KEEPALIVE
shared_ptr<Device> nx_iree_create_local_sync_device();

EMSCRIPTEN_KEEPALIVE
pair<shared_ptr<nx_iree_status_t>, std::vector<shared_ptr<IREETensor>>> nx_iree_call(
    shared_ptr<nx_iree_vm_instance_t> instance,
    shared_ptr<Device> device,
    shared_ptr<nx_iree_data_buffer_t> bytecode,
    std::vector<shared_ptr<IREETensor>> inputs);

EMSCRIPTEN_KEEPALIVE
pair<shared_ptr<nx_iree_status_t>, shared_ptr<nx_iree_data_buffer_t>> nx_iree_read_buffer(shared_ptr<Device> device, shared_ptr<IREETensor> buffer_view, size_t num_bytes);

EMSCRIPTEN_KEEPALIVE
std::string nx_iree_get_status_message(shared_ptr<nx_iree_status_t> status);

EMSCRIPTEN_KEEPALIVE
shared_ptr<nx_iree_status_t> nx_iree_register_all_drivers(shared_ptr<nx_iree_driver_registry_t>);

EMSCRIPTEN_KEEPALIVE
bool nx_iree_status_is_ok(shared_ptr<nx_iree_status_t> status);

EMSCRIPTEN_KEEPALIVE

// Reference malloc and free so that they
// are not pruned by emscripten
EMSCRIPTEN_KEEPALIVE

extern "C" void ensure_malloc_free();

template <typename T>
void register_pair(const char* name) {
  value_array<T>(name)
      .element(&T::first)
      .element(&T::second);
}

template <typename T>
void register_opaque_type(const char* name) {
  std::stringstream ss;
  ss << name << "*";

  class_<T>(name).template smart_ptr<shared_ptr<T>>(ss.str().c_str());
}

emscripten::val iree_tensor_to_flat_js_array(shared_ptr<IREETensor> tensor) {
  if (!tensor->data) {
    if (tensor->device == nullptr) {
      throw std::runtime_error("Tensor does not have a device.");
    }
    if (!tensor->buffer_view) {
      throw std::runtime_error("Tensor does not have a buffer_view.");
    }

    auto status = read_buffer(tensor->device, tensor->buffer_view, tensor->data, tensor->size);

    if (!iree_status_is_ok(status)) {
      throw std::runtime_error("Failed to read buffer: " + get_status_message(status));
    }
  }

  switch (tensor->type) {
    case IREE_HAL_ELEMENT_TYPE_INT_8:
      return emscripten::val::array(reinterpret_cast<int8_t*>(tensor->data), reinterpret_cast<int8_t*>(tensor->data) + tensor->size);
    case IREE_HAL_ELEMENT_TYPE_UINT_8:
      return emscripten::val::array(reinterpret_cast<uint8_t*>(tensor->data), reinterpret_cast<uint8_t*>(tensor->data) + tensor->size);
    case IREE_HAL_ELEMENT_TYPE_INT_16:
      return emscripten::val::array(reinterpret_cast<int16_t*>(tensor->data), reinterpret_cast<int16_t*>(tensor->data) + tensor->size / 2);
    case IREE_HAL_ELEMENT_TYPE_UINT_16:
      return emscripten::val::array(reinterpret_cast<uint16_t*>(tensor->data), reinterpret_cast<uint16_t*>(tensor->data) + tensor->size / 2);
    case IREE_HAL_ELEMENT_TYPE_INT_32:
      return emscripten::val::array(reinterpret_cast<int32_t*>(tensor->data), reinterpret_cast<int32_t*>(tensor->data) + tensor->size / 4);
    case IREE_HAL_ELEMENT_TYPE_UINT_32:
      return emscripten::val::array(reinterpret_cast<uint32_t*>(tensor->data), reinterpret_cast<uint32_t*>(tensor->data) + tensor->size / 4);
    case IREE_HAL_ELEMENT_TYPE_INT_64:
      return emscripten::val::array(reinterpret_cast<int64_t*>(tensor->data), reinterpret_cast<int64_t*>(tensor->data) + tensor->size / 8);
    case IREE_HAL_ELEMENT_TYPE_UINT_64:
      return emscripten::val::array(reinterpret_cast<uint64_t*>(tensor->data), reinterpret_cast<uint64_t*>(tensor->data) + tensor->size / 8);
    case IREE_HAL_ELEMENT_TYPE_FLOAT_32:
      return emscripten::val::global("Float32Array").new_(emscripten::typed_memory_view(tensor->size / 4, reinterpret_cast<float*>(tensor->data)));
      return emscripten::val::array(reinterpret_cast<float*>(tensor->data), reinterpret_cast<float*>(tensor->data) + tensor->size / 4);
    case IREE_HAL_ELEMENT_TYPE_FLOAT_64:
      return emscripten::val::array(reinterpret_cast<double*>(tensor->data), reinterpret_cast<double*>(tensor->data) + tensor->size / 8);
    default:
      throw std::runtime_error("Unsupported element type: " + std::to_string(tensor->type));
  }
}

EMSCRIPTEN_BINDINGS(my_module) {
  register_opaque_type<nx_iree_vm_instance_t>("VMInstance");
  register_opaque_type<nx_iree_driver_registry_t>("DriverRegistry");
  register_opaque_type<nx_iree_status_t>("Status");

  class_<Device>("Device")
      .smart_ptr<shared_ptr<Device>>("Device")
      .property("uri", &Device::uri)
      .property("driver_name", &Device::driver_name)
      .property("id", &Device::id);

  class_<IREETensor>("Tensor")
      .smart_ptr<shared_ptr<IREETensor>>("Tensor*")
      .class_function("create", &IREETensor::build)
      .function("toFlatArray", &iree_tensor_to_flat_js_array)
      .function("deallocate", &IREETensor::deallocate)
      .function("serialize", &serialize_iree_tensor);

  class_<nx_iree_data_buffer_t>("DataBuffer")
      .smart_ptr<shared_ptr<nx_iree_data_buffer_t>>("DataBuffer")
      .class_function("allocate", &nx_iree_data_buffer_t::allocate)
      .class_function("create", &nx_iree_data_buffer_t::create)
      .property("size", &nx_iree_data_buffer_t::size)
      .function("data", &nx_iree_data_buffer_t::get_data);

  register_pair<pair<shared_ptr<nx_iree_status_t>, std::vector<shared_ptr<IREETensor>>>>("[Status, std::vector<Tensor>]");
  register_pair<pair<shared_ptr<nx_iree_status_t>, shared_ptr<nx_iree_data_buffer_t>>>("[Status, DataBuffer*]");

  register_vector<shared_ptr<IREETensor>>("vector_Tensor");

  // raw null-pointer getters for functions that need to receive pointers as references
  // function("get")

  function("ensureMallocFree", &ensure_malloc_free);
  function("createVMInstance", &nx_iree_create_vm_instance);
  // function("createDriverRegistry", &nx_iree_create_driver_registry);
  function("createDevice", &nx_iree_create_local_sync_device);
  function("call", &nx_iree_call);
  function("readBuffer", &nx_iree_read_buffer);
  function("getStatusMessage", &nx_iree_get_status_message);
  function("registerAllDrivers", &nx_iree_register_all_drivers);
  function("statusIsOK", &nx_iree_status_is_ok);
}

#endif  // EMSCRIPTEN_API_H