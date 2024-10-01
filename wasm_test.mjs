// const __dirname = '/Users/paulo.valente/coding/nx_iree/iree-runtime/webassembly/install';
let path =
  "/home/valente/coding/nx_iree/iree-runtime/webassembly/install/./nx_iree_runtime.mjs";
let bytecode_path = "/tmp/add_wasm.bin";

import fs from "fs";

function readFileToStringSync(filePath) {
  try {
    const data = fs.readFileSync(filePath);
    return data;
  } catch (err) {
    console.error("Error reading file:", err);
    throw err;
  }
}

const Module = await import(path)
  .then((mod) => mod.default) // Assuming the default export is a function or value
  .catch((err) => {
    console.error("Error importing module:", err);
    throw err;
  });

let device = Module.createDevice();
console.log(device.$$, device.uri, device.driver_name);

// Create the IREETensors for the inputs
let data1 = new Uint8Array([10, 20, 30]);
let type1 = "u8";
let shape = new Int32Array([3]);
let input1 = new Module.Tensor.create(data1, shape, type1);

let data2 = new Int32Array([1, 2, 3]);
let type2 = "s32";
let input2 = new Module.Tensor.create(data2, shape, type2);

let bytecode_arr = readFileToStringSync(bytecode_path);
console.log(bytecode_arr);
const bytecode_uint8Array = new Uint8Array(
  bytecode_arr.buffer,
  bytecode_arr.byteOffset,
  bytecode_arr.byteLength
);

let bytecode = new Module.DataBuffer.create(bytecode_uint8Array, false);

// Call your WebAssembly function (example)
// let driverRegistry = Module.createDriverRegistry();
// let [_status, drivers] = Module.listDrivers(driverRegistry);
// let [driver_name, driver] = drivers.get(0);

// console.log(driver_name, driver);

// let [status, devices] = Module.listDevicesForDriver(
// driverRegistry,
// driver_name
// );

// let [device_uri, device] = devices.get(0);

// console.log(device_uri, device);

let vminstance = Module.createVMInstance();

let inputs = new Module.vector_Tensor();
inputs.push_back(input1);
inputs.push_back(input2);
console.log(vminstance, device, bytecode, inputs);

let [call_status, outputs] = Module.call(vminstance, device, bytecode, inputs);

console.log(Module.statusIsOK(call_status));

if (!Module.statusIsOK(call_status)) {
  console.error("Error calling the VM instance");
  console.error(Module.getStatusMessage(call_status));
}
