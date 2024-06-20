defmodule NxIREE.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = []

    :ok = NxIREE.VM.create_instance()

    Supervisor.start_link(children, strategy: :one_for_one, name: NxIREE.Supervisor)
  end
end
