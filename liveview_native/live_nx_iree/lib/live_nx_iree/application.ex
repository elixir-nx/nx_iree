defmodule LiveNxIREE.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LiveNxIREEWeb.Telemetry,
      LiveNxIREE.Repo,
      {DNSCluster, query: Application.get_env(:live_nx_iree, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LiveNxIREE.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: LiveNxIREE.Finch},
      # Start a worker by calling: LiveNxIREE.Worker.start_link(arg)
      # {LiveNxIREE.Worker, arg},
      # Start to serve requests, typically the last entry
      LiveNxIREEWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LiveNxIREE.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LiveNxIREEWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
