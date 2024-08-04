NxIREE.list_drivers() |> IO.inspect(label: "drivers")

{:ok, [dev | _]} = NxIREE.list_devices("metal") |> IO.inspect()

fun = fn a, b -> dbg(Nx.add(Nx.cos(a), Nx.sin(b))) end
args = [Nx.template({4}, :f32), Nx.template({4}, :s64)]
flags = ["--iree-hal-target-backends=metal-spirv", "--iree-input-type=stablehlo_xla", "--iree-execution-model=async-internal"]

Nx.Defn.default_options(compiler: NxIREE.Compiler, iree_compiler_flags: flags, iree_runtime_options: [device: dev])

f = Nx.Defn.compile(fun, args)

arg0 = Nx.tensor([1.0, 2.0, 3.0, 4.0])
arg1 = Nx.tensor([1, -1, 1, -1])
f.(arg0, arg1)
