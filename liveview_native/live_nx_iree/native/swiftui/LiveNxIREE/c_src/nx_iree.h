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

iree_vm_instance_t* nx_iree_create_instance();
iree_hal_device_t* nx_iree_create_device(char* device_uri);
char** nx_iree_call(iree_vm_instance_t* vm_instance, iree_hal_device_t* device, uint64_t bytecode_size, unsigned char* bytecode, uint64_t num_inputs, char** serialized_inputs, uint64_t num_outputs, char* error_message, uint64_t* output_byte_sizes);

// this function expects to receive a single image ordered as channels x height x width and return an image with the same dimensions
unsigned char* nx_iree_image_call(iree_vm_instance_t* vm_instance, iree_hal_device_t* device, uint64_t bytecode_size, unsigned char* bytecode, uint64_t* input_dims, unsigned char* input_data, char* error_message, uint32_t seed);

char** nx_iree_list_all_devices(uint64_t* count);

#ifdef __cplusplus
}
#endif


#endif /* nx_iree_h */
