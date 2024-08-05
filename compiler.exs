NxIREE.list_drivers() |> IO.inspect(label: "drivers")

{:ok, [dev | _]} = NxIREE.list_devices("metal") |> IO.inspect()

fun = fn ->
  key = Nx.Random.key(42)
  {val, _key} = Nx.Random.uniform(key, 0.0, 1.0)

  val
  # Nx.cos(a)
  # |> Nx.add(Nx.sin(b))
  # |> Nx.add(val)
end

# args = [Nx.template({4}, :f32), Nx.template({4}, :s64)]
args = []
flags = ["--iree-hal-target-backends=metal-spirv", "--iree-input-type=stablehlo_xla", "--iree-execution-model=async-internal"]

Nx.Defn.default_options(compiler: NxIREE.Compiler, iree_compiler_flags: flags, iree_runtime_options: [device: dev])

f = Nx.Defn.compile(fun, args)

arg0 = Nx.tensor([1.0, 2.0, 3.0, 4.0])
arg1 = Nx.tensor([1, -1, 1, -1])
f.(arg0, arg1)
