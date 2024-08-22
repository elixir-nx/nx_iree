//
//  nx_iree.h
//  LiveNxIREE
//
//  Created by Paulo.Valente on 8/21/24.
//

#ifndef nx_iree_h
#define nx_iree_h

#include <cstdint>

extern "C" {
    int nx_iree_initialize(iree_vm_instance_t* instance, iree_hal_driver_registry_t* driver_registry, iree_hal_device_t* device);
    int nx_iree_call(uint64_t bytecode_size, char* bytecode, uint64_t num_inputs, char** serialized_inputs, uint64_t num_outputs, char** serialized_outputs, char* error_message);
}

#endif /* nx_iree_h */
