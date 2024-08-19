defmodule NxIREE.MixHelpers do
  @moduledoc false
  def github_release_path(file) do
    version = File.read!(Path.join(:code.priv_dir(:nx_iree), "/VERSION"))

    Path.join(
      "https://github.com/elixir-nx/nx_iree/releases/download/v#{version}/",
      file
    )
  end

  defp assert_network_tool!() do
    unless network_tool() do
      raise "expected either curl or wget to be available in your system, but neither was found"
    end
  end

  def download!(name, url, dest) do
    assert_network_tool!()

    case download(name, url, dest) do
      :ok ->
        :ok

      _ ->
        raise "unable to download iree from #{url}"
    end
  end

  defp download(name, url, dest) do
    {command, args} =
      case network_tool() do
        :curl -> {"curl", ["--fail", "-L", url, "-o", dest]}
        :wget -> {"wget", ["-O", dest, url]}
      end

    IO.puts("Downloading #{name} from #{url}")

    case System.cmd(command, args) do
      {_, 0} -> :ok
      _ -> :error
    end
  end

  defp network_tool() do
    cond do
      executable_exists?("curl") -> :curl
      executable_exists?("wget") -> :wget
      true -> nil
    end
  end

  defp executable_exists?(name), do: not is_nil(System.find_executable(name))
end
