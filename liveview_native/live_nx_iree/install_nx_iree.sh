
mv native/swiftui/LiveNxIREE/nx_iree native/swiftui/LiveNxIREE/nx_iree_old

for platform in host ios ios_simulator tvos tvos_simulator visionos visionos_simulator; do
  mix nx_iree.native_download --platform $platform --output-dir native/swiftui/LiveNxIREE/nx_iree/lib/$platform

  if [ $platform == "host" ]; then
    mv native/swiftui/LiveNxIREE/nx_iree/lib/host/include native/swiftui/LiveNxIREE/nx_iree/
  else
    rm -rf native/swiftui/LiveNxIREE/nx_iree/lib/$platform/include
  fi

  rm native/swiftui/LiveNxIREE/nx_iree/lib/$platform/nx_iree-embedded-macos-$platform.tar.gz
done

rm -rf native/swiftui/LiveNxIREE/nx_iree_old
