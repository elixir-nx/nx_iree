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

static int open_resources(ErlNifEnv* env) {
  const char* mod = "NxIREE";

  if (!open_resource<iree_vm_instance_t*>(env, mod, "iree_vm_instance_t")) {
    return -1;
  }
  return 1;
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

DECLARE_NIF(create_instance_and_register_drivers) {
  // register all drivers
  auto status = register_all_drivers();
  if (!is_ok(status)) {
    return error(env, get_status_message(status).c_str());
  }

  iree_vm_instance_t* vm_instance = create_instance();

  // create the global vm instance
  return ok(env, make<iree_vm_instance_t*>(env, vm_instance));
}

DECLARE_NIF(create_device) {
  // create the ref for a device URI
  return enif_make_atom(env, "ok");
}

DECLARE_NIF(list_devices) {
  if (argc == 0) {
    // list all devices
  }

  iree_hal_driver_t* driver;
  size_t device_count;
  iree_hal_device_info_t* device_infos;

  // list devices for a specific driver

  return enif_make_atom(env, "ok");
}

DECLARE_NIF(list_drivers) {
  // list all available drivers
  auto [status, drivers] = list_drivers();
  if (!is_ok(status)) {
    return error(env, get_status_message(status).c_str());
  }

  std::vector<ERL_NIF_TERM> driver_terms;

  for (auto driver : drivers) {
    auto name_term = enif_make_string(env, driver.name.c_str(), ERL_NIF_LATIN1);
    auto full_name_term = enif_make_string(env, driver.full_name.c_str(), ERL_NIF_LATIN1);
    auto tuple = enif_make_tuple2(env, name_term, full_name_term);
    driver_terms.push_back(tuple);
  }

  ERL_NIF_TERM driver_list = enif_make_list_from_array(env, driver_terms.data(), driver_terms.size());

  return ok(env, driver_list);
}

DECLARE_NIF(call) {
  return enif_make_atom(env, "ok");
}

static ErlNifFunc funcs[] = {
    {"create_instance_and_register_drivers", 0, create_instance_and_register_drivers},
    {"create_device", 1, create_device},
    {"list_devices", 0, list_devices},
    {"list_devices", 1, list_devices},
    {"list_drivers", 0, list_drivers},
    {"call_io", 4, call, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"call_cpu", 4, call, ERL_NIF_DIRTY_JOB_CPU_BOUND}};

ERL_NIF_INIT(Elixir.NxIREE.Native, funcs, &load, NULL, &upgrade, NULL);
