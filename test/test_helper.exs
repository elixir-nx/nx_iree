{:ok, [dev | _]} = NxIREE.list_devices("local-sync")

flags = [
  "--iree-hal-target-backends=llvm-cpu",
  "--iree-input-type=stablehlo_xla",
  "--iree-execution-model=async-internal"
]

Nx.Defn.global_default_options(
  compiler: NxIREE.Compiler,
  iree_compiler_flags: flags,
  iree_runtime_options: [device: dev]
)

Nx.global_default_backend(NxIREE.Backend)

ExUnit.start()
