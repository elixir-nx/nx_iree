// const __dirname = '/Users/paulo.valente/coding/nx_iree/iree-runtime/webassembly/install';
let path =
  "/Users/paulo.valente/coding/nx_iree/iree-runtime/webassembly/install/./nx_iree_runtime.mjs";
let bytecode_path = "/tmp/add_wasm.bin";

const fs = await import("fs");

function readFileToStringSync(filePath) {
  try {
    const data = fs.readFileSync(filePath, "utf8"); // 'utf8' ensures the result is a string
    return data;
  } catch (err) {
    console.error("Error reading file:", err);
    throw err;
  }
}

const Module = await import(path).then((x) => x.default());

// Create the IREETensors for the inputs
let data1 = new Uint8Array([10, 20, 30]);
let type1 = "u8";
let shape = new Int32Array([3]);
let input1 = new Module.Tensor.create(data1, shape, type1);

let data2 = new Int32Array([1, 2, 3]);
let type2 = "s32";
let input2 = new Module.Tensor.create(data2, shape, type2);

let bytecode_base64 = readFileToStringSync(bytecode_path);
let bytecode_arr = atob(bytecode_base64);
let bytecode = new Module.DataBuffer.create(bytecode_arr, false);

// Call your WebAssembly function (example)
let driverRegistry = Module.createDriverRegistry();
let [_status, drivers] = Module.listDrivers(driverRegistry);
let [driver_name, driver] = drivers.get(0);

let [status, devices] = Module.listDevicesForDriver(
  driverRegistry,
  driver_name
);

let [device_uri, device] = devices.get(0);

let vminstance = Module.createVMInstance();

console.log(vminstance, device, driver_name, bytecode);
let inputs = new Module.vector_Tensor();
inputs.push_back(input1);
inputs.push_back(input2);

let result = Module.call(vminstance, device, driver_name, bytecode, inputs);
