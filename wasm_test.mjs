// const __dirname = '/Users/paulo.valente/coding/nx_iree/iree-runtime/webassembly/install';
let path =
  "/home/valente/coding/nx_iree/iree-runtime/webassembly/install/./nx_iree_runtime.mjs";
let bytecode_path = "/tmp/add_sin_cos.vmfb";

import fs from "fs";

async function debug() {
  console.log(`Process ID: ${process.pid}`);
  console.log("Press Enter to continue...");

  return new Promise((resolve) => {
    process.stdin.setRawMode(true);
    process.stdin.resume();
    process.stdin.on("data", function (data) {
      if (data.toString() === "\r") {
        process.stdin.setRawMode(false);
        process.stdin.pause();
        resolve(); // Resolve the promise when Enter is pressed
      }
    });
  });
}

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
  .then((mod) => mod.default()) // Assuming the default export is a function or value
  .catch((err) => {
    console.error("Error importing module:", err);
    throw err;
  });

let device = Module.createDevice();

// await debug();

// Create the IREETensors for the inputs
console.log("Allocating Arg 1");
let data1 = new Float32Array([-1, 2, -3, 4]);
console.log(data1.byteLength, data1.byteOffset);
let type1 = "f32";
let shape = new Int32Array([4]);
console.log(shape.length);
let input1 = new Module.Tensor.create(data1, shape, type1);
console.log("Input 1: ", input1.toFlatArray());

console.log("Allocating Arg 2");
let data2 = new Int32Array([1, 2, 3, 4]);
let type2 = "s32";
let input2 = new Module.Tensor.create(data2, shape, type2);

console.log("Input 2: ", input2.toFlatArray());

let bytecode_arr = readFileToStringSync(bytecode_path);
const bytecode_uint8Array = new Uint8Array(
  bytecode_arr.buffer,
  bytecode_arr.byteOffset,
  bytecode_arr.byteLength
);

console.log("Allocating Bytecode");
let bytecode = new Module.DataBuffer.create(bytecode_uint8Array);

console.log("Creating VM Instance");
let vminstance = Module.createVMInstance();

console.log("Creating Inputs Vector");
let inputs = new Module.vector_Tensor();
inputs.push_back(input1);
inputs.push_back(input2);

console.log("Calling VM Instance");
let [call_status, outputs] = Module.call(vminstance, device, bytecode, inputs);

if (!Module.statusIsOK(call_status)) {
  console.error("Error calling the VM instance");
  console.error(Module.getStatusMessage(call_status));
}

let results = [];

for (let i = 0; i < outputs.size(); i++) {
  results.push(outputs.get(i).toFlatArray());
}

console.log(results);
