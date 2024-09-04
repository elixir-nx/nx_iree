//
//  nx_iree.cpp
//  LiveNxIREE
//
//  Created by Paulo.Valente on 8/21/24.
//

#include "nx_iree.h"
#include <nx_iree/runtime.h>

#include <string>
#include <vector>
#include <iostream>

void nx_iree_release_device(iree_hal_device_t* device) {
    // TODO: actually release device
    return;
}

iree_hal_device_t* nx_iree_create_device(char* device_uri) {
    iree_hal_driver_registry_t* driver_registry = get_driver_registry();
    register_all_drivers(driver_registry);
    
    return create_device(driver_registry, std::string(device_uri));
}

iree_vm_instance_t* nx_iree_create_instance() {
    return create_instance();
}

unsigned char* nx_iree_image_call(iree_vm_instance_t* vm_instance, iree_hal_device_t* device, uint64_t bytecode_size, unsigned char* bytecode, uint64_t* input_dims, unsigned char* input_data, char* error_message, uint32_t seed, float noise_amount) {
    if (!input_data) {
        return nullptr;
    }
    
    std::vector<iree::runtime::IREETensor*> inputs;
    
    std::vector<int64_t> input_dims_vec;
    
    size_t input_size = 1;
    for (int i = 0; i < 3; i++){
        input_size *= input_dims[i];
        input_dims_vec.push_back(input_dims[i]);
    }
        
    inputs.push_back(new iree::runtime::IREETensor(
                                                   input_data,
                                                   input_size,
                                                   input_dims_vec,
                                                   iree_hal_element_types_t::IREE_HAL_ELEMENT_TYPE_UINT_8));
    
    input_dims_vec.clear();
    
    inputs.push_back(new iree::runtime::IREETensor(&seed, 4, {},                                                    iree_hal_element_types_t::IREE_HAL_ELEMENT_TYPE_UINT_32));
    
    inputs.push_back(new iree::runtime::IREETensor(&noise_amount, 8, {},                                                    iree_hal_element_types_t::IREE_HAL_ELEMENT_TYPE_FLOAT_32));
    
    // driver name is hardcoded because there is only a check for CUDA
    auto [status, optional_result] = call(vm_instance, device, "not_cuda", bytecode, static_cast<size_t>(bytecode_size), inputs);
    
    for (auto input: inputs) {
        free(input->data);
        input->data = nullptr;
        input->dims.clear();
        free(input);
    }
        
    if (!is_ok(status) || !optional_result.has_value()) {
        std::string msg = get_status_message(status);
        std::cout << msg << std::endl;
        strncpy(error_message, msg.c_str(), msg.length());
        return nullptr;
    }
        
    iree::runtime::IREETensor *tensor= optional_result.value()[0];
    
    auto output = new unsigned char[tensor->size];
    
    if (output == nullptr) {
      get_status_message(status);
      return nullptr;
    }

    status = read_buffer(device, tensor->buffer_view, output, input_size);

    if (!iree_status_is_ok(status)) {
        std::string msg = get_status_message(status);
        std::cout << msg << std::endl;
        strncpy(error_message, msg.c_str(), msg.length());
        return nullptr;
    }
    
    free(tensor->data);
    tensor->data = nullptr;
    tensor->dims.clear();
    free(tensor->buffer_view);
    free(tensor);
    
    get_status_message(status); // workaround so we can free status
        
    return output;
}

char** nx_iree_call(iree_vm_instance_t* vm_instance, iree_hal_device_t* device, uint64_t bytecode_size, unsigned char* bytecode, uint64_t num_inputs, char** serialized_inputs, uint64_t num_outputs, char* error_message, uint64_t* output_byte_sizes) {
    std::vector<iree::runtime::IREETensor*> inputs;
    
    for (size_t i = 0; i < num_inputs; i++) {
        inputs.push_back(new iree::runtime::IREETensor(serialized_inputs[i]));
    }
    
    // driver name is hardcoded because there is only a check for CUDA
    auto [status, optional_result] = call(vm_instance, device, "not_cuda", bytecode, static_cast<size_t>(bytecode_size), inputs);
        
    if (!is_ok(status) || !optional_result.has_value()) {
        std::string msg = get_status_message(status);
        strncpy(error_message, msg.c_str(), msg.length());
        return nullptr;
    }
    
    auto serialized_outputs = new char*[num_outputs];
    
    std::vector<iree::runtime::IREETensor *> result = optional_result.value();
    for (size_t i = 0; i < num_outputs; i++) {
        iree::runtime::IREETensor *tensor = result[i];
        std::vector<char> *serialized = tensor->serialize();
        serialized_outputs[i] = new char[serialized->size()];
        memcpy(serialized_outputs[i], serialized->data(), serialized->size());
        output_byte_sizes[i] = serialized->size();
        delete tensor;
    }
    
    
    
    return serialized_outputs;
}

char** nx_iree_list_all_devices(uint64_t* count) {
    iree_hal_driver_registry_t* registry = get_driver_registry();
    std::vector<iree::runtime::Device*> devices;
    iree_status_t status = list_devices(registry, devices);
    
    if (!iree_status_is_ok(status)) {
        count = 0;
        return nullptr;
    }
    
    *count = devices.size();
    
    char** output = reinterpret_cast<char**>(malloc(sizeof(char*) * *count));
    
    for (size_t i = 0; i < *count; i++){
        auto device = devices[i];
        size_t length = device->uri.length();
        const char* uri = device->uri.c_str();
        output[i] = new char[length + 1];
        strncpy(output[i], uri, length);
    }
    
    return output;
}
