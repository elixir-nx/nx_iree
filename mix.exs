defmodule NxIree.MixProject do
  use Mix.Project

  def project do
    n_jobs = to_string(max(System.schedulers_online() - 2, 1))

    [
      app: :nx_iree,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:nx_iree, :elixir_make] ++ Mix.compilers(),
      aliases: [
        "compile.nx_iree": &compile/1
      ],
      make_env: fn ->
        priv_path = Path.join(Mix.Project.app_path(), "priv")
        cwd_relative_to_priv = relative_to(File.cwd!(), priv_path)

        %{
          "MIX_BUILD_EMBEDDED" => "#{Mix.Project.config()[:build_embedded]}",
          "CWD_RELATIVE_TO_PRIV_PATH" => cwd_relative_to_priv,
          "MAKE_NUM_JOBS" => n_jobs,
          "IREE_GIT_REV" => nx_iree_config().tag,
          "IREE_SOURCE_DIR" => nx_iree_config().source_dir
        }
      end
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elixir_make, "~> 0.6", runtime: false}
    ]
  end

  defp compile(args) do
    download_and_unzip(args)
  end

  defp nx_iree_config() do
    version = System.get_env("NX_IREE_VERSION", "20240604.914")
    env_dir = System.get_env("NX_IREE_COMPILER_DIR")
    source_env_dir = System.get_env("NX_IREE_SOURCE_DIR")

    dir = env_dir || Path.join(__DIR__, "cache/iree-compiler")
    source_dir = source_env_dir || Path.join(__DIR__, "cache/iree-source")

    %{
      version: version,
      tag: "candidate-#{version}",
      base: "iree",
      env_dir: env_dir,
      dir: dir,
      source_dir: source_dir,
      compiler_path: Path.join([dir, "compiler/_mlir_libs/iree-compile"])
    }
  end

  defp download_and_unzip(args) do
    nx_iree_config = nx_iree_config()

    cache_dir =
      if dir = System.get_env("NX_IREE_CACHE") do
        Path.expand(dir)
      else
        :filename.basedir(:user_cache, "iree")
      end

    if "--force" in args do
      File.rm_rf(nx_iree_config.dir)
      File.rm_rf(nx_iree_config.source_dir)
      File.rm_rf(cache_dir)
    end

    if File.dir?(nx_iree_config.dir) do
      {:ok, []}
    else
      download_and_unzip(cache_dir, nx_iree_config)
    end
  end

  defp download_and_unzip(cache_dir, nx_iree_config) do
    File.mkdir_p!(cache_dir)

    nx_iree_zip =
      Path.join(cache_dir, "iree-compiler-#{nx_iree_config.version}.zip")

    unless File.exists?(nx_iree_zip) do
      # Download nx_iree

      os = :os.type()

      arch =
        case List.to_string(:erlang.system_info(:system_architecture)) do
          "x86_64" <> _ -> "x86_64"
          "aarch64" <> _ -> "aarch64"
          "amd64" <> _ -> "amd64"
        end

      url =
        case {os, arch} do
          {{:unix, :linux}, arch} ->
            "https://github.com/iree-org/iree/releases/download/candidate-#{nx_iree_config.version}/iree_compiler-#{nx_iree_config.version}-cp310-cp310-manylinux_2_27_#{arch}.manylinux_2_28_#{arch}.whl"

          {{:unix, :darwin}, _} ->
            # MacOS
            "https://github.com/iree-org/iree/releases/download/candidate-#{nx_iree_config.version}/iree_compiler-#{nx_iree_config.version}-cp311-cp311-macosx_13_0_universal2.whl"

          os ->
            Mix.raise("OS #{inspect(os)} is not supported")
        end

      download!(url, nx_iree_zip)
    end

    :ok
  end

  defp assert_network_tool!() do
    unless network_tool() do
      raise "expected either curl or wget to be available in your system, but neither was found"
    end
  end

  defp download!(url, dest) do
    assert_network_tool!()

    case download(url, dest) do
      :ok ->
        :ok

      _ ->
        raise "unable to download iree from #{url}"
    end
  end

  defp download(url, dest) do
    {command, args} =
      case network_tool() do
        :curl -> {"curl", ["--fail", "-L", url, "-o", dest]}
        :wget -> {"wget", ["-O", dest, url]}
      end

    IO.puts("Downloading iree from #{url}")

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

  # Returns `path` relative to the `from` directory.
  defp relative_to(path, from) do
    path_parts = path |> Path.expand() |> Path.split()
    from_parts = from |> Path.expand() |> Path.split()
    {path_parts, from_parts} = drop_common_prefix(path_parts, from_parts)
    root_relative = for _ <- from_parts, do: ".."
    Path.join(root_relative ++ path_parts)
  end

  defp drop_common_prefix([h | left], [h | right]), do: drop_common_prefix(left, right)
  defp drop_common_prefix(left, right), do: {left, right}
end
