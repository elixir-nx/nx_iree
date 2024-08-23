//
//  nx_iree.h
//  LiveNxIREE
//
//  Created by Paulo.Valente on 8/21/24.
//

#ifndef nx_iree_h
#define nx_iree_h

#include <iree/hal/api.h>
#include <iree/vm/api.h>

#ifdef __cplusplus
extern "C" {
#endif

int nx_iree_initialize(iree_vm_instance_t* vm_instance, iree_hal_driver_registry_t* driver_registry, char* error_message);
iree_hal_device_t* nx_iree_create_device(char* device_uri);
int nx_iree_call(iree_vm_instance_t* vm_instance, iree_hal_device_t* device, uint64_t bytecode_size, unsigned char* bytecode, uint64_t num_inputs, char** serialized_inputs, uint64_t num_outputs, char** serialized_outputs, char* error_message);


#ifdef __cplusplus
}
#endif


#endif /* nx_iree_h */
