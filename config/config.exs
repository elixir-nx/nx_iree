import Config

if config_env() == :test do
  config :nx_iree, :add_backend_on_inspect, false
end
