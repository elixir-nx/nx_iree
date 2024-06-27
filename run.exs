NxIREE.list_drivers() |> IO.inspect(label: "drivers")

{:ok, [cuda_dev | _]} = NxIREE.list_devices("cuda") |> IO.inspect()

mlir_module = """
module {
  func.func @main(%arg0: tensor<4xf32>, %arg1: tensor<4xf32>) -> tensor<4xf32> {
    %0 = "stablehlo.multiply"(%arg0, %arg1) : (tensor<4xf32>, tensor<4xf32>) -> tensor<4xf32>
    return %0 : tensor<4xf32>
  }
}
"""

flags = ["--iree-hal-target-backends=cuda", "--iree-input-type=stablehlo_xla", "--iree-execution-model=async-internal"]

%NxIREE.Module{} = module = NxIREE.compile(mlir_module, flags)

arg0 = Nx.tensor([1.0, 2.0, 3.0, 4.0])
arg1 = Nx.tensor([1.0, -1.0, 1.0, -1.0])

{:ok, [result]} = NxIREE.call(module, [arg0, arg1], device: cuda_dev) |> IO.inspect()

NxIREE.VM.read_buffer(result.device, result.ref) |> Nx.from_binary(:f32) |> IO.inspect()

IO.gets("Press enter to finish")
