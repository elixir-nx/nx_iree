NxIREE.list_drivers() |> IO.inspect(label: "drivers")

{:ok, [dev | _]} = NxIREE.list_devices("metal") |> IO.inspect()

# Obtained by using EXLA.to_mlir_module(fn a, b -> Nx.add(Nx.cos(a), Nx.sin(b)) end, [Nx.template({4}, :f32), Nx.template({4}, :s64)])
mlir_module = """
module {
  func.func public @main(%arg0: tensor<4xf32>, %arg1: tensor<4xi64>) -> tensor<4xf32> {
    %0 = stablehlo.cosine %arg0 : tensor<4xf32>
    %1 = stablehlo.convert %arg1 : (tensor<4xi64>) -> tensor<4xf32>
    %2 = stablehlo.sine %1 : tensor<4xf32>
    %3 = stablehlo.add %0, %2 : tensor<4xf32>
    return %3 : tensor<4xf32>
  }
}
"""

# flags = ["--iree-hal-target-backends=cuda", "--iree-input-type=stablehlo_xla", "--iree-execution-model=async-internal"]
flags = ["--iree-hal-target-backends=metal-spirv", "--iree-input-type=stablehlo_xla", "--iree-execution-model=async-internal"]

%NxIREE.Module{} = module = NxIREE.compile(mlir_module, flags)

arg0 = Nx.tensor([1.0, 2.0, 3.0, 4.0])
arg1 = Nx.tensor([1, -1, 1, -1])

IO.gets("Press enter to continue - #{System.pid()}")
{:ok, [result]} = NxIREE.call(module, [arg0, arg1], device: dev) |> IO.inspect()

IO.inspect(result, limit: 4)


IO.gets("Press enter to finish")
