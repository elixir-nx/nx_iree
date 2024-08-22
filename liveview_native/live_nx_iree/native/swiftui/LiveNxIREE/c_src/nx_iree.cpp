//
//  nx_iree.cpp
//  LiveNxIREE
//
//  Created by Paulo.Valente on 8/21/24.
//

#include "nx_iree.h"

#include <string>
#include <vector>

int func(int x) {
    return x;
}

/*
int nx_iree_initialize(iree_vm_instance_t* vm_instance, iree_hal_driver_registry_t* driver_registry, iree_hal_device_t* device, char* device_uri, char* error_message) {
    vm_instance = create_instance();
    driver_registry = get_driver_registry();
    auto status = register_all_drivers(driver_registry);
    
    if (!is_ok(status)) {
        if (error_message) {
            std::string msg = get_status_message(status);
            strncpy(error_message, msg.c_str(), msg.length());
        }
        
        return 1;
    }
    
    
    device = create_device(std::string(device_uri));
    
    if (!device) {
        const char* msg = "Unable to initialize device\0";
        strncpy(error_message, msg, strlen(msg));
        return 1;
    }
    
    return 0;
}

int nx_iree_call(iree_vm_instance_t* vm_instance, iree_hal_device_t* device, uint64_t bytecode_size, unsigned char* bytecode, uint64_t num_inputs, char** serialized_inputs, uint64_t num_outputs, char** serialized_outputs, char* error_message) {
    std::vector<iree::runtime::IREETensor*> inputs;
    
    for (size_t i = 0; i < num_inputs; i++) {
        inputs.push_back(new iree::runtime::IREETensor(serialized_inputs[i]));
    }
    
    // driver name is hardcoded because there is only a check for CUDA
    auto [status, optional_result] = call(vm_instance, device, "not_cuda", bytecode, static_cast<size_t>(bytecode_size), inputs);
        
    if (!is_ok(status)) {
        if (error_message) {
            std::string msg = get_status_message(status);
            strncpy(error_message, msg.c_str(), msg.length());
        }
        
        return 1;
    }
    
    serialized_outputs = new char*[num_outputs];
    
    auto result = optional_result.value();
    for (size_t i = 0; i < num_outputs; i++) {
        std::vector<char> *serialized = result[i]->serialize();
        serialized_outputs[i] = new char[serialized->size()];
        memcpy(serialized_outputs[i], serialized->data(), serialized->size());
    }
    
    return 0;
}

}
*/
