#include <iree/hal/driver.h>
#include <iree/hal/driver_registry.h>
#include <nx_iree/runtime.h>

#include <functional>
#include <iostream>
#include <map>
#include <string>

#include "erl_nif.h"

ERL_NIF_TERM error(ErlNifEnv* env, const char* error) {
  return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_string(env, error, ERL_NIF_LATIN1));
}

ERL_NIF_TERM ok(ErlNifEnv* env, ERL_NIF_TERM term) {
  return enif_make_tuple2(env, enif_make_atom(env, "ok"), term);
}

// Template struct for resources. The struct lets us use templates
// to store and retrieve open resources later on. This implementation
// is the same as the approach taken in the goertzenator/nifpp
// C++11 wrapper around the Erlang NIF API.
template <typename T>
struct resource_object {
  static ErlNifResourceType* type;
};
template <typename T>
ErlNifResourceType* resource_object<T>::type = 0;

// Default destructor passed when opening a resource. The default
// behavior is to invoke the underlying objects destructor and
// set the resource pointer to NULL.
template <typename T>
void default_dtor(ErlNifEnv* env, void* obj) {
  T* resource = reinterpret_cast<T*>(obj);
  resource->~T();
  resource = nullptr;
}

// Opens a resource for the given template type T. If no
// destructor is given, uses the default destructor defined
// above.
template <typename T>
int open_resource(ErlNifEnv* env,
                  const char* mod,
                  const char* name,
                  ErlNifResourceDtor* dtor = nullptr) {
  if (dtor == nullptr) {
    dtor = &default_dtor<T>;
  }
  ErlNifResourceType* type;
  ErlNifResourceFlags flags = ErlNifResourceFlags(ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER);
  type = enif_open_resource_type(env, mod, name, dtor, flags, NULL);
  if (type == NULL) {
    resource_object<T>::type = 0;
    return -1;
  } else {
    resource_object<T>::type = type;
  }
  return 1;
}

template <typename T>
ERL_NIF_TERM make(ErlNifEnv* env, T& var) {
  void* ptr = enif_alloc_resource(resource_object<T>::type, sizeof(T));
  new (ptr) T(std::move(var));
  ERL_NIF_TERM ret = enif_make_resource(env, ptr);
  enif_release_resource(ptr);
  return ret;
}

// Returns a resource of the given template type T.
template <typename T>
ERL_NIF_TERM get(ErlNifEnv* env, ERL_NIF_TERM term, T*& var) {
  return enif_get_resource(env, term,
                           resource_object<T>::type,
                           reinterpret_cast<void**>(&var));
}

static int open_resources(ErlNifEnv* env) {
  const char* mod = "NxIREE";

  if (!open_resource<iree_vm_instance_t*>(env, mod, "iree_vm_instance_t")) {
    return -1;
  }

  if (!open_resource<iree_hal_device_t*>(env, mod, "iree_hal_device_t")) {
    return -1;
  }
  if (!open_resource<iree_hal_driver_registry_t*>(env, mod, "iree_hal_driver_registry_t")) {
    return -1;
  }
  if (!open_resource<iree::runtime::IREETensor*>(env, mod, "iree::runtime::IREETensor")) {
    return -1;
  }

  return 1;
}

int get_list(ErlNifEnv* env, ERL_NIF_TERM list, std::vector<int64_t>& var) {
  unsigned int length;
  if (!enif_get_list_length(env, list, &length)) return 0;
  var.reserve(length);
  ERL_NIF_TERM head, tail;

  while (enif_get_list_cell(env, list, &head, &tail)) {
    int64_t elem;
    if (!enif_get_int64(env, head, &elem)) return 0;
    var.push_back(elem);
    list = tail;
  }
  return 1;
}

template <typename T>
int get_list(ErlNifEnv* env, ERL_NIF_TERM list, std::vector<T*>& var) {
  unsigned int length;
  if (!enif_get_list_length(env, list, &length)) return 0;
  var.reserve(length);
  ERL_NIF_TERM head, tail;

  while (enif_get_list_cell(env, list, &head, &tail)) {
    T** elem;
    if (!get<T*>(env, head, elem)) return 0;
    var.push_back(*elem);
    list = tail;
  }
  return 1;
}

int get_string(ErlNifEnv* env, ERL_NIF_TERM term, std::string& var) {
  unsigned len;
  int ret = enif_get_list_length(env, term, &len);

  if (!ret) {
    ErlNifBinary bin;
    ret = enif_inspect_binary(env, term, &bin);
    if (!ret) {
      return 0;
    }
    var = std::string((const char*)bin.data, bin.size);
    return ret;
  }

  var.resize(len + 1);
  ret = enif_get_string(env, term, &*(var.begin()), var.size(), ERL_NIF_LATIN1);

  if (ret > 0) {
    var.resize(ret - 1);
  } else if (ret == 0) {
    var.resize(0);
  } else {
  }

  return ret;
}

static int load(ErlNifEnv* env, void** priv, ERL_NIF_TERM load_info) {
  if (open_resources(env) == -1) return -1;
  return 0;
}

static int upgrade(ErlNifEnv* env, void** priv_data, void** old_priv_data, ERL_NIF_TERM load_info) {
  // Silence "unused var" warnings.
  (void)(env);
  (void)(priv_data);
  (void)(old_priv_data);
  (void)(load_info);

  return 0;
}

#define DECLARE_NIF(NAME) ERL_NIF_TERM NAME(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])

DECLARE_NIF(create_instance) {
  iree_vm_instance_t* vm_instance = create_instance();

  // create the global vm instance
  return ok(env, make<iree_vm_instance_t*>(env, vm_instance));
}

DECLARE_NIF(create_device) {
  // create the ref for a device URI

  iree_hal_driver_registry_t** registry;
  if (!get<iree_hal_driver_registry_t*>(env, argv[0], registry)) {
    return error(env, "invalid driver registry");
  }

  return enif_make_atom(env, "ok");
}

DECLARE_NIF(get_driver_registry) {
  auto registry = get_driver_registry();

  return ok(env, make<iree_hal_driver_registry_t*>(env, registry));
}

DECLARE_NIF(list_devices) {
  std::vector<iree::runtime::Device*> devices;
  iree_hal_driver_registry_t** registry;
  if (argc == 1) {
    if (!get(env, argv[0], registry)) {
      return error(env, "invalid driver registry");
    }

    iree_status_t status = list_devices(*registry, devices);

    if (!is_ok(status)) {
      return error(env, get_status_message(status).c_str());
    }
  } else {
    std::string driver_name;
    unsigned driver_name_length;
    if (!get(env, argv[0], registry)) {
      return error(env, "invalid driver registry");
    }

    if (!get_string(env, argv[1], driver_name)) {
      return error(env, "invalid driver name");
    }

    iree_status_t status = list_devices(*registry, driver_name, devices);
    if (!is_ok(status)) {
      return error(env, get_status_message(status).c_str());
    }
  }

  std::vector<ERL_NIF_TERM> device_terms;

  for (auto device : devices) {
    auto ref_term = make<iree_hal_device_t*>(env, device->ref);
    auto driver_name_term = enif_make_string(env, device->driver_name.c_str(), ERL_NIF_LATIN1);
    auto uri_term = enif_make_string(env, device->uri.c_str(), ERL_NIF_LATIN1);
    auto tuple = enif_make_tuple3(env, ref_term, driver_name_term, uri_term);
    device_terms.push_back(tuple);
  }

  return ok(env, enif_make_list_from_array(env, device_terms.data(), device_terms.size()));
}

DECLARE_NIF(list_drivers) {
  // list all available drivers

  iree_hal_driver_registry_t** registry;

  if (!get<iree_hal_driver_registry_t*>(env, argv[0], registry)) {
    return error(env, "invalid driver registry");
  }

  auto [status, drivers] = list_drivers(*registry);
  if (!is_ok(status)) {
    return error(env, get_status_message(status).c_str());
  }

  std::vector<ERL_NIF_TERM> driver_terms;

  for (auto driver : drivers) {
    auto name_term = enif_make_string(env, driver->name.c_str(), ERL_NIF_LATIN1);
    auto full_name_term = enif_make_string(env, driver->full_name.c_str(), ERL_NIF_LATIN1);
    auto tuple = enif_make_tuple2(env, name_term, full_name_term);
    driver_terms.push_back(tuple);
  }

  ERL_NIF_TERM driver_list = enif_make_list_from_array(env, driver_terms.data(), driver_terms.size());

  return ok(env, driver_list);
}

std::string iree_type_to_nx_type(iree_hal_element_type_t type) {
  using type_enum = iree_hal_element_types_t;

  if (type == type_enum::IREE_HAL_ELEMENT_TYPE_INT_8) {
    return "i8";
  } else if (type == type_enum::IREE_HAL_ELEMENT_TYPE_INT_16) {
    return "i16";
  } else if (type == type_enum::IREE_HAL_ELEMENT_TYPE_INT_32) {
    return "i32";
  } else if (type == type_enum::IREE_HAL_ELEMENT_TYPE_INT_64) {
    return "i64";
  } else if (type == type_enum::IREE_HAL_ELEMENT_TYPE_UINT_8) {
    return "u8";
  } else if (type == type_enum::IREE_HAL_ELEMENT_TYPE_UINT_16) {
    return "u16";
  } else if (type == type_enum::IREE_HAL_ELEMENT_TYPE_UINT_32) {
    return "u32";
  } else if (type == type_enum::IREE_HAL_ELEMENT_TYPE_UINT_64) {
    return "u64";
  } else if (type == type_enum::IREE_HAL_ELEMENT_TYPE_BFLOAT_16) {
    return "bf16";
  } else if (type == type_enum::IREE_HAL_ELEMENT_TYPE_FLOAT_16) {
    return "f16";
  } else if (type == type_enum::IREE_HAL_ELEMENT_TYPE_FLOAT_32) {
    return "f32";
  } else if (type == type_enum::IREE_HAL_ELEMENT_TYPE_FLOAT_64) {
    return "f64";
  } else if (type == type_enum::IREE_HAL_ELEMENT_TYPE_COMPLEX_FLOAT_64) {
    return "c64";
  } else if (type == type_enum::IREE_HAL_ELEMENT_TYPE_COMPLEX_FLOAT_128) {
    return "c128";
  }

  return "invalid_type";
}

iree_hal_element_type_t nx_type_to_iree_type(std::string type) {
  using type_enum = iree_hal_element_types_t;

  if (type == "i8") {
    return type_enum::IREE_HAL_ELEMENT_TYPE_INT_8;
  } else if (type == "i16") {
    return type_enum::IREE_HAL_ELEMENT_TYPE_INT_16;
  } else if (type == "i32") {
    return type_enum::IREE_HAL_ELEMENT_TYPE_INT_32;
  } else if (type == "i64") {
    return type_enum::IREE_HAL_ELEMENT_TYPE_INT_64;
  } else if (type == "u8") {
    return type_enum::IREE_HAL_ELEMENT_TYPE_UINT_8;
  } else if (type == "u16") {
    return type_enum::IREE_HAL_ELEMENT_TYPE_UINT_16;
  } else if (type == "u32") {
    return type_enum::IREE_HAL_ELEMENT_TYPE_UINT_32;
  } else if (type == "u64") {
    return type_enum::IREE_HAL_ELEMENT_TYPE_UINT_64;
  } else if (type == "bf16") {
    return type_enum::IREE_HAL_ELEMENT_TYPE_BFLOAT_16;
  } else if (type == "f16") {
    return type_enum::IREE_HAL_ELEMENT_TYPE_FLOAT_16;
  } else if (type == "f32") {
    return type_enum::IREE_HAL_ELEMENT_TYPE_FLOAT_32;
  } else if (type == "f64") {
    return type_enum::IREE_HAL_ELEMENT_TYPE_FLOAT_64;
  } else if (type == "c64") {
    return type_enum::IREE_HAL_ELEMENT_TYPE_COMPLEX_FLOAT_64;
  } else if (type == "c128") {
    return type_enum::IREE_HAL_ELEMENT_TYPE_COMPLEX_FLOAT_128;
  }

  return type_enum::IREE_HAL_ELEMENT_TYPE_NONE;
}

DECLARE_NIF(read_buffer_nif) {
  iree_hal_device_t** device;
  iree::runtime::IREETensor** input;
  int64_t num_bytes;

  if (!get<iree_hal_device_t*>(env, argv[0], device)) {
    return error(env, "invalid device");
  }
  if (!get<iree::runtime::IREETensor*>(env, argv[1], input)) {
    return error(env, "invalid input");
  }
  if (!enif_get_int64(env, argv[2], &num_bytes)) {
    return error(env, "invalid num_bytes");
  }

  ErlNifBinary binary;

  if (!enif_alloc_binary(num_bytes, &binary)) {
    return error(env, "unable to allocate binary");
  }

  if (!(*input)->buffer_view) {
    std::memcpy(binary.data, (*input)->data, num_bytes);
  } else {
    auto status = read_buffer(*device, (*input)->buffer_view, binary.data, num_bytes);
    if (!is_ok(status)) {
      return error(env, get_status_message(status).c_str());
    }
  }

  return ok(env, enif_make_binary(env, &binary));
}

DECLARE_NIF(allocate_buffer) {
  if (argc != 4) {
    return error(env, "invalid number of arguments");
  }

  ErlNifBinary binary;

  iree_hal_device_t** device;

  size_t num_dims;
  std::vector<int64_t> dims;
  std::string type_string;

  if (!enif_inspect_binary(env, argv[0], &binary)) {
    return error(env, "unable to read input data");
  }
  if (!get<iree_hal_device_t*>(env, argv[1], device)) {
    return error(env, "unable to read device");
  }
  if (!get_list(env, argv[2], dims)) {
    return error(env, "unable to read dimensions");
  }
  if (!get_string(env, argv[3], type_string)) {
    return error(env, "unable to read type");
  }

  iree_hal_element_type_t type = nx_type_to_iree_type(type_string);

  if (type == iree_hal_element_types_t::IREE_HAL_ELEMENT_TYPE_NONE) {
    return error(env, "invalid type");
  }

  auto input = new iree::runtime::IREETensor(binary.data, binary.size, dims, type);

  return ok(env, make<iree::runtime::IREETensor*>(env, input));
}

DECLARE_NIF(call_nif) {
  iree_vm_instance_t** instance;
  iree_hal_device_t** device;
  ErlNifBinary bytecode;
  std::vector<iree::runtime::IREETensor*> inputs;
  std::string driver_name;

  if (!get<iree_vm_instance_t*>(env, argv[0], instance)) {
    return error(env, "invalid instance");
  }
  if (!get<iree_hal_device_t*>(env, argv[1], device)) {
    return error(env, "invalid device");
  }
  if (!get_string(env, argv[2], driver_name)) {
    return error(env, "invalid device");
  }
  if (!enif_inspect_binary(env, argv[3], &bytecode)) {
    return error(env, "invalid bytecode");
  }
  if (!get_list(env, argv[4], inputs)) {
    return error(env, "invalid inputs");
  }

  auto [status, result_tensors] = call(*instance, *device, driver_name, bytecode.data, bytecode.size, inputs);

  if (!is_ok(status)) {
    return error(env, get_status_message(status).c_str());
  }

  std::vector<ERL_NIF_TERM> output_terms;
  for (auto tensor : result_tensors.value()) {
    auto tensor_term = make<iree::runtime::IREETensor*>(env, tensor);
    std::vector<ERL_NIF_TERM> dims;
    for (auto dim : tensor->dims) {
      dims.push_back(enif_make_int64(env, dim));
    }
    auto dims_term = enif_make_list_from_array(env, dims.data(), dims.size());
    auto type_term = enif_make_string(env, iree_type_to_nx_type(tensor->type).c_str(), ERL_NIF_LATIN1);
    auto term = enif_make_tuple3(env, tensor_term, dims_term, type_term);
    output_terms.push_back(term);
  }

  return ok(env, enif_make_list_from_array(env, output_terms.data(), output_terms.size()));
}

static ErlNifFunc funcs[] = {
    {"create_instance", 0, create_instance},
    {"get_driver_registry", 0, get_driver_registry},
    {"create_device", 2, create_device},
    {"list_devices", 1, list_devices},
    {"list_devices", 2, list_devices},
    {"list_drivers", 1, list_drivers},
    {"allocate_buffer", 4, allocate_buffer},
    {"read_buffer", 3, read_buffer_nif},
    {"call_io", 5, call_nif, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"call_cpu", 5, call_nif, ERL_NIF_DIRTY_JOB_CPU_BOUND}};

ERL_NIF_INIT(Elixir.NxIREE.Native, funcs, &load, NULL, &upgrade, NULL);
