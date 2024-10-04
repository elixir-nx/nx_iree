flags = [
  "--iree-input-type=stablehlo_xla",
  "--iree-execution-model=async-internal"
]

Nx.Defn.global_default_options(
  compiler: NxIREE.Compiler,
  iree_compiler_flags: flags
)

Nx.global_default_backend(NxIREE.Backend)

if System.get_env("DEBUG") do
  IO.gets("Press Enter to continue - PID: #{System.pid()}")
end

ExUnit.start()
