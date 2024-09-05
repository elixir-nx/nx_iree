Mix.install([
  {:axon, github: "elixir-nx/axon", branch: "main"},
  {:nx_iree, path: "."},
  {:nx, github: "elixir-nx/nx", sparse: "nx", override: true},
  {:exla, github: "elixir-nx/nx", sparse: "exla", override: true}
], system_env: %{"NX_IREE_PREFER_PRECOMPILED" => false})

NxIREE.list_drivers() |> IO.inspect(label: "drivers")

{:ok, [dev | _]} = NxIREE.list_devices("metal")

flags = ["--iree-hal-target-backends=metal-spirv", "--iree-input-type=stablehlo_xla", "--iree-execution-model=async-internal"]
Nx.Defn.default_options(compiler: NxIREE.Compiler, iree_compiler_flags: flags, iree_runtime_options: [device: dev])

model =
  Axon.input("x", shape: {nil, 3})
  |> Axon.dense(8, activation: :relu)
  |> Axon.dense(1, activation: :relu)

Nx.Defn.default_options(compiler: NxIREE.Compiler, iree_compiler_flags: flags, iree_runtime_options: [device: dev])
# Nx.Defn.default_options(compiler: EXLA, iree_compiler_flags: flags, iree_runtime_options: [device: dev])

template = %{"x" => Nx.template({10, 3}, :f32)}

{init_fn, predict_fn} = Axon.build(model, [])
init_params = Nx.Defn.jit_apply(init_fn, [template, Axon.ModelState.new(Axon.ModelState.empty())])

IO.puts("\n\n\n======= BEGIN predict_compiled_fn =======\n\n\n")
predict_compiled_fn = Nx.Defn.compile(predict_fn, [init_params, template])
IO.puts("\n\n\n======= END predict_compiled_fn =======\n\n\n")

IO.puts("\n\n\n======= BEGIN predict_compiled_fn CALL =======\n\n\n")
predict_compiled_fn.(init_params, Nx.iota({10, 3}, type: :f32)) |> dbg()
IO.puts("\n\n\n======= END predict_compiled_fn CALL =======\n\n\n")
