defmodule NxIREE.MixHelpers do
  @moduledoc false
  def github_release_path(file, version \\ nil) do
    version = version || File.read!(Path.join(:code.priv_dir(:nx_iree), "VERSION"))

    Path.join(
      "https://github.com/elixir-nx/nx_iree/releases/download/v#{version}/",
      file
    )
  end

  def download!(name, url, dest) do
    case download(name, url, dest) do
      :ok ->
        :ok

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, reason} ->
        raise "unable to download #{name} from #{url}: #{inspect(reason)}"
    end
  end

  defp download(name, url, dest) do
    {:ok, _} = Application.ensure_all_started(:req)

    Req.new(url: url, into: File.stream!(dest, [:write, :binary]))
    |> Req.Request.prepend_response_steps(
      pre_redirect: &Req.Steps.redirect/1,
      handle_non_200_responses: fn
        {request, %{status: 200} = response} ->
          {request, response}

        {request, response} ->
          {%{request | into: nil}, response}
      end
    )
    |> Req.get()
    |> case do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: status}} ->
        raise "unable to download #{name} from #{url}: status #{status}"

      {:error, reason} ->
        raise "unable to download #{name} from #{url}: #{inspect(reason)}"
    end
  end
end
