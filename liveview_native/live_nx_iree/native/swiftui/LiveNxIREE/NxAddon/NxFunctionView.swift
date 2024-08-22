//
//  NxFunction.swift
//  LiveNxIREE
//
//  Created by Paulo.Valente on 8/22/24.
//

import SwiftUI
import LiveViewNative

@LiveElement
struct NxFunctionView<Root: RootRegistry>: View {
    @_documentation(visibility: public)
    @LiveAttribute("bytecode") private var bytecode: String? = nil
    @LiveAttribute("signature") private var signature: String? = nil
    @LiveAttribute("device") private var device: String? = nil
    @LiveAttribute("trigger") private var trigger: Bool = false
    @Event("on-execution", type: "change") private var change
    
    var body: some View {
        VStack {
            if signature != nil {
                Text(signature!)
                    .padding()
            }
        }
        .onAppear() {
            run()
        }
        .onChange(of: bytecode) {
            run()  // Run the function when bytecode changes
        }
    }
    
    private func run() {
        if bytecode == nil {
            return
        }
       // Custom logic that should run when execute is set to true
       print("Executing function \(signature ?? "None") on device: \(device ?? "None")")
        
       change(value: "Sending something back")
   }
}
