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

int nx_iree_initialize(iree_vm_instance_t* vm_instance, iree_hal_driver_registry_t* driver_registry, char* error_message) {
    vm_instance = create_instance();
    driver_registry = get_driver_registry();
    auto status = register_all_drivers(driver_registry);
    
    if (!is_ok(status) && !iree_status_is_already_exists(status)) {
        if (error_message) {
            std::string msg = get_status_message(status);
            strncpy(error_message, msg.c_str(), msg.length());
        }
        
        return 1;
    }
    
    return 0;
}

iree_hal_device_t* nx_iree_create_device(char* device_uri) {
    iree_hal_driver_registry_t* driver_registry = get_driver_registry();
    register_all_drivers(driver_registry);
    
    return create_device(driver_registry, std::string(device_uri));
}

iree_vm_instance_t* nx_iree_create_instance() {
    return create_instance();
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
        std::cout << "Tensor: " << tensor;
        if (tensor == nullptr) {
            std::cout << "Failed output allocation at index " << i << "\n";
        }
        std::vector<char> *serialized = tensor->serialize();
        serialized_outputs[i] = new char[serialized->size()];
        memcpy(serialized_outputs[i], serialized->data(), serialized->size());
        output_byte_sizes[i] = serialized->size();
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
