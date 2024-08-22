//
//  nx_iree.cpp
//  LiveNxIREE
//
//  Created by Paulo.Valente on 8/21/24.
//

#include "nx_iree.h"
#include "nx_iree/runtime.h"

extern "C" {

int nx_iree_initialize(iree_vm_instance_t* instance, iree_hal_driver_registry_t* driver_registry, iree_hal_device_t* device) {
    
}

int nx_iree_call(uint64_t bytecode_size, char* bytecode, uint64_t num_inputs, char** serialized_inputs, uint64_t num_outputs, char** serialized_outputs, char* error_message) {
    std::vector<iree::runtime::IREETensor> inputs;
    
    for (size_t i = 0; i < num_inputs; i++) {
        inputs.push_back(iree::runtime::IREETensor(serialized_inputs[i]));
    }
    
    auto [status, optional_result] = call(vm_instance, device, driver_name, static_cast<size_t>(bytecode_size), inputs);
    
    if (!is_ok(status)) {
        if (error_message) {
            std::string msg = get_status_message(status);
            strncpy(error_message, msg.c_str(), msg.length());
        }
        
        return 1;
    }
    
    serialized_outputs = new char*[num_outputs];
    
    for (size_t i = 0; i < num_outputs; i++) {
        std::vector<char> *serialized = optional_result.value().serialize();
        serialized_outputs[i] = new char[serialized->size()];
        memcpy(serialized_outputs[i], serialized->data(), serialized->size());
    }
    
    return 0;
}
}
