flags = [
  "--iree-input-type=stablehlo_xla",
  "--iree-execution-model=async-internal"
]

driver = System.get_env("NX_IREE_DEFAULT_DRIVER") || "local-sync"
# runtime_options = nil
runtime_options = [device: NxIREE.Device.find_default_device(driver)]

Nx.Defn.global_default_options(
  compiler: NxIREE.Compiler,
  iree_compiler_flags: flags,
  iree_runtime_options: runtime_options
)

Nx.global_default_backend(NxIREE.Backend)

if System.get_env("DEBUG") do
  IO.gets("Press Enter to continue - PID: #{System.pid()}")
end

ExUnit.start()
