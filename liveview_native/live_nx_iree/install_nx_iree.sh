mix nx_iree.native_download --platform ios --output-dir native/swiftui/LiveNxIREE/nx_iree/lib/ios
mix nx_iree.native_download --platform ios_simulator --output-dir native/swiftui/LiveNxIREE/nx_iree/lib/ios_simulator
mix nx_iree.native_download --platform tvos --output-dir native/swiftui/LiveNxIREE/nx_iree/lib/tvos
mix nx_iree.native_download --platform tvos_simulator --output-dir native/swiftui/LiveNxIREE/nx_iree/lib/tvos_simulator
mix nx_iree.native_download --platform visionos --output-dir native/swiftui/LiveNxIREE/nx_iree/lib/visionos
mix nx_iree.native_download --platform visionos_simulator --output-dir native/swiftui/LiveNxIREE/nx_iree/lib/visionos_simulator
mix nx_iree.native_download --platform host --output-dir native/swiftui/LiveNxIREE/nx_iree/lib/host

mv native/swiftui/LiveNxIREE/nx_iree/lib/host/libnx_iree_runtime.so native/swiftui/LiveNxIREE/nx_iree/lib/libnx_iree_runtime-host.so
mv native/swiftui/LiveNxIREE/nx_iree/lib/ios/libnx_iree_runtime.so native/swiftui/LiveNxIREE/nx_iree/lib/libnx_iree_runtime-ios.so
mv native/swiftui/LiveNxIREE/nx_iree/lib/ios_simulator/libnx_iree_runtime.so native/swiftui/LiveNxIREE/nx_iree/lib/libnx_iree_runtime-ios_simulator.so
mv native/swiftui/LiveNxIREE/nx_iree/lib/tvos/libnx_iree_runtime.so native/swiftui/LiveNxIREE/nx_iree/lib/libnx_iree_runtime-tvos.so
mv native/swiftui/LiveNxIREE/nx_iree/lib/tvos_simulator/libnx_iree_runtime.so native/swiftui/LiveNxIREE/nx_iree/lib/libnx_iree_runtime-tvos_simulator.so
mv native/swiftui/LiveNxIREE/nx_iree/lib/visionos/libnx_iree_runtime.so native/swiftui/LiveNxIREE/nx_iree/lib/libnx_iree_runtime-visionos.so
mv native/swiftui/LiveNxIREE/nx_iree/lib/visionos_simulator/libnx_iree_runtime.so native/swiftui/LiveNxIREE/nx_iree/lib/libnx_iree_runtime-visionos_simulator.so

rm -rf native/swiftui/LiveNxIREE/nx_iree/lib/host
rm -rf native/swiftui/LiveNxIREE/nx_iree/lib/ios
rm -rf native/swiftui/LiveNxIREE/nx_iree/lib/ios_simulator
rm -rf native/swiftui/LiveNxIREE/nx_iree/lib/visionos
rm -rf native/swiftui/LiveNxIREE/nx_iree/lib/visionos_simulator
rm -rf native/swiftui/LiveNxIREE/nx_iree/lib/tvos
rm -rf native/swiftui/LiveNxIREE/nx_iree/lib/tvos_simulator
