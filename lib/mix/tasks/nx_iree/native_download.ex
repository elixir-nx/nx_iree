defmodule Mix.Tasks.NxIree.NativeDownload do
  @moduledoc """
  Downloads the native IREE library for the requested platform.

  Currently only supported in macOS arm64 hosts.
  """

  @valid_platforms ~w(host ios ios_simulator visionos visionos_simulator tvos tvos_simulator)
  @platform "--platform <" <> Enum.join(@valid_platforms, "|") <> ">"
  @destination "--destination <path>"
  @shortdoc "#{@platform} #{@destination}"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {parsed, _rest, _errors} =
      OptionParser.parse(args,
        switches: [platform: :string, destination: :string],
        aliases: [p: :platform, d: :destination]
      )

    platform = parsed[:platform]
    destination = parsed[:destination]

    unless platform do
      raise """
      Missing required argument: #{@platform}
      """
    end

    unless destination do
      raise """
      Missing required argument: #{@destination}
      """
    end

    platform = platform |> String.trim() |> String.downcase()
    destination = String.trim(destination)

    os = :os.type()
    arch = List.to_string(:erlang.system_info(:system_architecture))

    case {os, arch} do
      {{:unix, :darwin}, "aarch64" <> _} -> :ok
      {os, arch} -> raise "unsupported host: #{inspect(os)} (#{arch})"
    end

    file = "nx_iree-Darwin-arm64-#{platform}.tar.gz"

    url = LiveNxIREE.MixProject.github_release_path(file)
    :ok = LiveNxIREE.MixProject.download!("Native NxIREE library (#{platform})", url, destination)
  end
end
