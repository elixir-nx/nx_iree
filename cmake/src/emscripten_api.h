#ifndef EMSCRIPTEN_API_H
#define EMSCRIPTEN_API_H

#include <cstdbool>
#include <cstddef>
#include <string>
#include <vector>

#ifdef __EMSCRIPTEN__
#include <emscripten.h>  // Include the Emscripten header for EMSCRIPTEN_KEEPALIVE
#else
#define EMSCRIPTEN_KEEPALIVE
#endif

typedef struct nx_iree_vm_instance_t nx_iree_vm_instance_t;
typedef struct nx_iree_driver_registry_t nx_iree_driver_registry_t;
typedef struct nx_iree_device_t nx_iree_device_t;
typedef struct nx_iree_driver_t nx_iree_driver_t;
typedef struct nx_iree_status_t nx_iree_status_t;
typedef struct nx_iree_tensor_t nx_iree_tensor_t;

EMSCRIPTEN_KEEPALIVE
std::shared_ptr<nx_iree_vm_instance_t> nx_iree_create_vm_instance();

EMSCRIPTEN_KEEPALIVE
std::shared_ptr<nx_iree_driver_registry_t> nx_iree_create_driver_registry();

EMSCRIPTEN_KEEPALIVE
std::shared_ptr<nx_iree_device_t> nx_iree_create_device(std::shared_ptr<nx_iree_driver_registry_t> registry, std::string(device_uri));

EMSCRIPTEN_KEEPALIVE
std::pair<std::shared_ptr<nx_iree_status_t>, std::vector<std::shared_ptr<nx_iree_tensor_t>>> nx_iree_call(
    std::shared_ptr<nx_iree_vm_instance_t> instance,
    std::shared_ptr<nx_iree_device_t> device,
    std::string driver_name,
    unsigned char* bytecode,
    size_t bytecode_size,
    std::vector<std::shared_ptr<nx_iree_tensor_t>> inputs);

EMSCRIPTEN_KEEPALIVE
std::pair<std::shared_ptr<nx_iree_status_t>, void*> nx_iree_read_buffer(std::shared_ptr<nx_iree_device_t> device, std::shared_ptr<nx_iree_tensor_t> buffer_view, size_t num_bytes);

EMSCRIPTEN_KEEPALIVE
std::string nx_iree_get_status_message(std::shared_ptr<nx_iree_status_t> status);

EMSCRIPTEN_KEEPALIVE
std::shared_ptr<nx_iree_status_t> nx_iree_register_all_drivers(std::shared_ptr<nx_iree_driver_registry_t>);

EMSCRIPTEN_KEEPALIVE
std::pair<std::shared_ptr<nx_iree_status_t>, std::vector<std::pair<std::string, std::shared_ptr<nx_iree_driver_t>>>> nx_iree_list_drivers(std::shared_ptr<nx_iree_driver_registry_t>);

EMSCRIPTEN_KEEPALIVE
std::pair<std::shared_ptr<nx_iree_status_t>, std::vector<std::pair<std::string, std::shared_ptr<nx_iree_device_t>>>> nx_iree_list_devices(std::shared_ptr<nx_iree_driver_registry_t>);

EMSCRIPTEN_KEEPALIVE
std::pair<std::shared_ptr<nx_iree_status_t>, std::vector<std::pair<std::string, std::shared_ptr<nx_iree_device_t>>>> nx_iree_list_devices_for_driver(std::shared_ptr<nx_iree_driver_registry_t>, std::string driver_name);

EMSCRIPTEN_KEEPALIVE
bool nx_iree_status_is_ok(std::shared_ptr<nx_iree_status_t> status);

EMSCRIPTEN_KEEPALIVE
void nx_iree_free_vm_instance(nx_iree_vm_instance_t* ptr);

EMSCRIPTEN_KEEPALIVE
void nx_iree_free_driver_registry(std::shared_ptr<nx_iree_driver_registry_t> ptr);

EMSCRIPTEN_KEEPALIVE
void nx_iree_free_device(std::shared_ptr<nx_iree_device_t> ptr);

EMSCRIPTEN_KEEPALIVE
void nx_iree_free_driver(std::shared_ptr<nx_iree_driver_t> ptr);

EMSCRIPTEN_KEEPALIVE
void nx_iree_free_tensor(std::shared_ptr<nx_iree_tensor_t> ptr);

EMSCRIPTEN_KEEPALIVE
void nx_iree_free_status(std::shared_ptr<nx_iree_status_t> ptr);

#ifdef __EMSCRIPTEN__

#include <emscripten/bind.h>

// Reference malloc and free so that they
// are not pruned by emscripten
EMSCRIPTEN_KEEPALIVE

extern "C" void ensure_malloc_free();

EMSCRIPTEN_BINDINGS(my_module) {
  emscripten::class_<nx_iree_vm_instance_t>("NxIreeVmInstance").smart_ptr<std::shared_ptr<nx_iree_vm_instance_t>>("NxIreeVmInstancePtr");
  emscripten::class_<nx_iree_driver_registry_t>("NxIreeDriverRegistry").smart_ptr<std::shared_ptr<nx_iree_driver_registry_t>>("NxIreeDriverRegistryPtr");
  emscripten::class_<nx_iree_device_t>("NxIreeDevice").smart_ptr<std::shared_ptr<nx_iree_device_t>>("NxIreeDevicePtr");
  emscripten::class_<nx_iree_driver_t>("NxIreeDriver").smart_ptr<std::shared_ptr<nx_iree_driver_t>>("NxIreeDriverPtr");
  emscripten::class_<nx_iree_status_t>("NxIreeStatus").smart_ptr<std::shared_ptr<nx_iree_status_t>>("NxIreeStatusPtr");
  emscripten::class_<nx_iree_tensor_t>("NxIreeTensor").smart_ptr<std::shared_ptr<nx_iree_tensor_t>>("NxIreeTensorPtr");

  // raw null-pointer getters for functions that need to receive pointers as references
  // emscripten::function("get")

  emscripten::function("ensureMallocFree", &ensure_malloc_free);
  emscripten::function("createVMInstance", &nx_iree_create_vm_instance);
  emscripten::function("createDriverRegistry", &nx_iree_create_driver_registry);
  emscripten::function("createDevice", &nx_iree_create_device);
  emscripten::function("call", &nx_iree_call, emscripten::allow_raw_pointers());
  emscripten::function("readBuffer", &nx_iree_read_buffer);
  emscripten::function("getStatusMessage", &nx_iree_get_status_message);
  emscripten::function("registerAllDrivers", &nx_iree_register_all_drivers);
  emscripten::function("listDrivers", &nx_iree_list_drivers);
  emscripten::function("listDevices", &nx_iree_list_devices);
  emscripten::function("listDevicesForDriver", &nx_iree_list_devices_for_driver);
  emscripten::function("statusIsOK", &nx_iree_status_is_ok);
}

#endif
#endif  // EMSCRIPTEN_API_H