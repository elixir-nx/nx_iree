//
//  LiveNxIREE.swift
//  LiveNxIREE
//

import SwiftUI

@main
struct LiveNxIREE: App {
    init() {
        // Allocate memory for the pointers
        let vmInstance = UnsafeMutablePointer<iree_vm_instance_t>.allocate(capacity: 1)
        let driverRegistry = UnsafeMutablePointer<iree_hal_driver_registry_t>.allocate(capacity: 1)
        let errorMessage = UnsafeMutablePointer<CChar>.allocate(capacity: 256)
                
        // Call the initialization function
        let result = nx_iree_initialize(vmInstance, driverRegistry, errorMessage)
            
        if result != 0 {
            // Handle the error
            let errorString = String(cString: errorMessage)
            print("Error initializing nx_iree: \(errorString)")
        } else {
            globalVmInstance = vmInstance
            globalDriverRegistry = driverRegistry
            print("nx_iree initialized successfully.")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
