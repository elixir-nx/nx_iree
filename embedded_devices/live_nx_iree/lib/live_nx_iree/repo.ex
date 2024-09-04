defmodule LiveNxIREE.Repo do
  use Ecto.Repo,
    otp_app: :live_nx_iree,
    adapter: Ecto.Adapters.Postgres
end
