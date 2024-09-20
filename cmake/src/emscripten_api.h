#ifndef EMSCRIPTEN_API_H
#define EMSCRIPTEN_API_H

#include <emscripten.h>  // Include the Emscripten header for EMSCRIPTEN_KEEPALIVE
#include <emscripten/bind.h>
#include <emscripten/val.h>

#include <cstdbool>
#include <cstddef>
#include <sstream>
#include <string>
#include <vector>

typedef struct nx_iree_vm_instance_t nx_iree_vm_instance_t;
typedef struct nx_iree_driver_registry_t nx_iree_driver_registry_t;
typedef struct nx_iree_device_t nx_iree_device_t;
typedef struct nx_iree_driver_t nx_iree_driver_t;
typedef struct nx_iree_status_t nx_iree_status_t;
typedef struct nx_iree_tensor_t nx_iree_tensor_t;

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

  // Call using something like:
  // decoded = atob(base64_string);
  // array = Uint8Array.from(decoded, c => c.charCodeAt(0));
  // dataBuffer = Module.DataBuffer(array)
  // or Module.DataBuffer(array, false) if you don't want to copy the data
  // (but you must keep the reference to the array for as long as this buffer is used);
  nx_iree_data_buffer_t(emscripten::val array, bool should_copy = true) {
    size = array["length"].as<size_t>();
    if (should_copy) {
      this->data = static_cast<uint8_t*>(malloc(size));
      if (data == nullptr) {
        throw std::runtime_error("Failed to allocate memory.");
      }
      emscripten::val memoryView = emscripten::val::global("Uint8Array").new_(size, data);
      memoryView.call<void>("set", array);
    } else {
      uint8_t* buffer = reinterpret_cast<uint8_t*>(array["buffer"].as<uintptr_t>());
      size_t byteOffset = array["byteOffset"].as<size_t>();
      data = buffer + byteOffset;
    }
  }

  ~nx_iree_data_buffer_t() {
    free(data);
  }

  emscripten::val get_data() {
    return emscripten::val(emscripten::typed_memory_view(size, data));
  }
};

using namespace emscripten;
using std::pair, std::shared_ptr;

EMSCRIPTEN_KEEPALIVE
shared_ptr<nx_iree_vm_instance_t> nx_iree_create_vm_instance();

EMSCRIPTEN_KEEPALIVE
shared_ptr<nx_iree_driver_registry_t> nx_iree_create_driver_registry();

EMSCRIPTEN_KEEPALIVE
shared_ptr<nx_iree_device_t> nx_iree_create_device(shared_ptr<nx_iree_driver_registry_t> registry, std::string(device_uri));

EMSCRIPTEN_KEEPALIVE
pair<shared_ptr<nx_iree_status_t>, std::vector<shared_ptr<nx_iree_tensor_t>>> nx_iree_call(
    shared_ptr<nx_iree_vm_instance_t> instance,
    shared_ptr<nx_iree_device_t> device,
    std::string driver_name,
    shared_ptr<nx_iree_data_buffer_t> bytecode,
    std::vector<shared_ptr<nx_iree_tensor_t>> inputs);

EMSCRIPTEN_KEEPALIVE
pair<shared_ptr<nx_iree_status_t>, shared_ptr<nx_iree_data_buffer_t>> nx_iree_read_buffer(shared_ptr<nx_iree_device_t> device, shared_ptr<nx_iree_tensor_t> buffer_view, size_t num_bytes);

EMSCRIPTEN_KEEPALIVE
std::string nx_iree_get_status_message(shared_ptr<nx_iree_status_t> status);

EMSCRIPTEN_KEEPALIVE
shared_ptr<nx_iree_status_t> nx_iree_register_all_drivers(shared_ptr<nx_iree_driver_registry_t>);

EMSCRIPTEN_KEEPALIVE
pair<shared_ptr<nx_iree_status_t>, std::vector<pair<std::string, shared_ptr<nx_iree_driver_t>>>> nx_iree_list_drivers(shared_ptr<nx_iree_driver_registry_t>);

EMSCRIPTEN_KEEPALIVE
pair<shared_ptr<nx_iree_status_t>, std::vector<pair<std::string, shared_ptr<nx_iree_device_t>>>> nx_iree_list_devices(shared_ptr<nx_iree_driver_registry_t>);

EMSCRIPTEN_KEEPALIVE
pair<shared_ptr<nx_iree_status_t>, std::vector<pair<std::string, shared_ptr<nx_iree_device_t>>>> nx_iree_list_devices_for_driver(shared_ptr<nx_iree_driver_registry_t>, std::string driver_name);

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

EMSCRIPTEN_BINDINGS(my_module) {
  register_opaque_type<nx_iree_vm_instance_t>("VMInstance");
  register_opaque_type<nx_iree_driver_registry_t>("DriverRegistry");
  register_opaque_type<nx_iree_device_t>("Device");
  register_opaque_type<nx_iree_driver_t>("Driver");
  register_opaque_type<nx_iree_status_t>("Status");
  register_opaque_type<nx_iree_tensor_t>("Tensor");
  register_opaque_type<nx_iree_data_buffer_t>("DataBuffer");

  class_<nx_iree_data_buffer_t>("DataBuffer")
      .smart_ptr<shared_ptr<nx_iree_data_buffer_t>>("DataBuffer*")
      .constructor<size_t>()
      .constructor<emscripten::val, bool>()
      .property("size", &nx_iree_data_buffer_t::size)
      .function("data", &nx_iree_data_buffer_t::get_data);

  register_pair<pair<shared_ptr<nx_iree_status_t>, std::vector<shared_ptr<nx_iree_tensor_t>>>>("StatusVectorOfTensorPair");
  register_pair<pair<shared_ptr<nx_iree_status_t>, shared_ptr<nx_iree_data_buffer_t>>>("StatusDataBufferPtrPair");
  register_pair<pair<std::string, shared_ptr<nx_iree_device_t>>>("StringDevicePair");
  register_pair<pair<std::string, shared_ptr<nx_iree_driver_t>>>("StringDriverPair");
  register_pair<pair<shared_ptr<nx_iree_status_t>, std::vector<pair<std::string, shared_ptr<nx_iree_driver_t>>>>>("StatusStringDriverPair");
  register_pair<pair<shared_ptr<nx_iree_status_t>, std::vector<pair<std::string, shared_ptr<nx_iree_device_t>>>>>("StatusStringDevicePair");

  register_vector<pair<std::string, shared_ptr<nx_iree_driver_t>>>("VectorOfStringDriverPair");
  register_vector<pair<std::string, shared_ptr<nx_iree_device_t>>>("VectorOfStringDevicePair");
  register_vector<shared_ptr<nx_iree_tensor_t>>("VectorOfTensor");

  // raw null-pointer getters for functions that need to receive pointers as references
  // function("get")

  function("ensureMallocFree", &ensure_malloc_free);
  function("createVMInstance", &nx_iree_create_vm_instance);
  function("createDriverRegistry", &nx_iree_create_driver_registry);
  function("createDevice", &nx_iree_create_device);
  function("call", &nx_iree_call, allow_raw_pointers());
  function("readBuffer", &nx_iree_read_buffer);
  function("getStatusMessage", &nx_iree_get_status_message);
  function("registerAllDrivers", &nx_iree_register_all_drivers);
  function("listDrivers", &nx_iree_list_drivers);
  function("listDevices", &nx_iree_list_devices);
  function("listDevicesForDriver", &nx_iree_list_devices_for_driver);
  function("statusIsOK", &nx_iree_status_is_ok);
}

#endif  // EMSCRIPTEN_API_H