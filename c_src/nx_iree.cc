#include <iree/hal/driver.h>
#include <iree/hal/driver_registry.h>

#include <functional>
#include <iostream>
#include <map>
#include <string>

#include "erl_nif.h"

static int open_resources(ErlNifEnv* env) {
  const char* mod = "NxIREE";

  // if (!exla::nif::open_resource<mlir::MLIRContext*>(env, mod, "MLIRContext")) {
  //   return -1;
  // }
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
  // create the global vm instance
  return enif_make_atom(env, "ok");
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

  // call list_drivers from .so
  return enif_make_atom(env, "ok");
}

DECLARE_NIF(call) {
  return enif_make_atom(env, "ok");
}

static ErlNifFunc funcs[] = {
    {"create_device", 1, create_device},
    {"list_devices", 0, list_devices},
    {"list_devices", 1, list_devices},
    {"list_drivers", 0, list_drivers},
    {"call_io", 4, call, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"call_cpu", 4, call, ERL_NIF_DIRTY_JOB_CPU_BOUND}};

ERL_NIF_INIT(Elixir.NxIREE.Native, funcs, &load, NULL, &upgrade, NULL);
