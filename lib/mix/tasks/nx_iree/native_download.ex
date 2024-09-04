defmodule Mix.Tasks.NxIree.NativeDownload do
  @moduledoc """
  Downloads the native IREE library for the requested platform.

  Currently only supported in macOS arm64 hosts.
  """

  @valid_platforms ~w(host ios ios_simulator visionos visionos_simulator tvos tvos_simulator)
  @platform "--platform <" <> Enum.join(@valid_platforms, "|") <> ">"
  @output_dir "--output-dir <path>"
  @shortdoc "#{@platform} #{@output_dir}"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {parsed, _rest, _errors} =
      OptionParser.parse(args,
        switches: [platform: :string, output_dir: :string],
        aliases: [p: :platform, d: :output_dir]
      )

    platform = parsed[:platform]
    output_dir = parsed[:output_dir]

    unless platform do
      raise """
      Missing required argument: #{@platform}
      """
    end

    unless output_dir do
      raise """
      Missing required argument: #{@output_dir}
      """
    end

    platform = platform |> String.trim() |> String.downcase()
    output_dir = String.trim(output_dir)

    os = :os.type()
    arch = List.to_string(:erlang.system_info(:system_architecture))

    case {os, arch} do
      {{:unix, :darwin}, "aarch64" <> _} -> :ok
      {os, arch} -> raise "unsupported host: #{inspect(os)} (#{arch})"
    end

    file = "nx_iree-embedded-macos-#{platform}.tar.gz"

    File.mkdir_p!(output_dir)

    downloaded_file = Path.join(output_dir, file)

    url = NxIREE.MixHelpers.github_release_path(file)
    :ok = NxIREE.MixHelpers.download!("Native NxIREE library (#{platform})", url, downloaded_file)

    :ok =
      downloaded_file
      |> String.to_charlist()
      |> :erl_tar.extract([:compressed, cwd: String.to_charlist(output_dir)])
  end
end
