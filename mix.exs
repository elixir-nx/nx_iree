defmodule NxIREE.MixProject do
  use Mix.Project

  @version "0.0.1-pre.2"

  def project do
    n_jobs = to_string(max(System.schedulers_online() - 2, 1))

    [
      app: :nx_iree,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:nx_iree, :elixir_make] ++ Mix.compilers(),
      aliases: [
        "compile.nx_iree": &compile/1,
        "iree.version": &version/1
      ],
      make_env: fn ->
        priv_path = Path.join(Mix.Project.app_path(), "priv")
        cwd_relative_to_priv = relative_to(File.cwd!(), priv_path)

        %{
          "MIX_BUILD_EMBEDDED" => "#{Mix.Project.config()[:build_embedded]}",
          "CWD_RELATIVE_TO_PRIV_PATH" => cwd_relative_to_priv,
          "MAKE_NUM_JOBS" => n_jobs,
          "IREE_GIT_REV" => nx_iree_config().tag,
          "NX_IREE_SOURCE_DIR" => nx_iree_config().source_dir,
          "NX_IREE_CACHE_SO" => nx_iree_config().nx_iree_so_path,
          "NX_IREE_PREFER_PRECOMPILED" => to_string(nx_iree_config().use_precompiled)
        }
      end
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {NxIREE.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elixir_make, "~> 0.6", runtime: false},
      {:nx, github: "elixir-nx/nx", sparse: "nx", override: true},
      {:exla, github: "elixir-nx/nx", sparse: "exla"}
    ]
  end

  defp version(_args) do
    IO.puts(nx_iree_config().tag)
  end

  defp compile(args) do
    :ok = download_and_unzip_iree_release(args)

    if nx_iree_config().use_precompiled and not File.exists?(nx_iree_config().nx_iree_so_path) do
      download_precompiled_nx_iree_lib()
    else
      :ok
    end
  end

  defp nx_iree_config() do
    version = System.get_env("NX_IREE_VERSION", "20240604.914")
    tag = System.get_env("NX_IREE_GIT_REV", "candidate-20240604.914")

    env_dir = System.get_env("NX_IREE_COMPILER_DIR")

    home_cache = Path.join(System.fetch_env!("HOME"), ".cache")

    source_env_dir =
      System.get_env("NX_IREE_SOURCE_DIR", Path.join([home_cache, "nx_iree", "iree-#{tag}"]))

    dir = env_dir || Path.join(__DIR__, "cache/iree")
    source_dir = source_env_dir || Path.join(__DIR__, "cache/iree-source")

    use_precompiled = System.get_env("NX_IREE_PREFER_PRECOMPILED", "true") in ["1", "true"]

    %{
      version: version,
      tag: tag,
      base: "iree",
      env_dir: env_dir,
      dir: dir,
      source_dir: source_dir,
      use_precompiled: use_precompiled,
      nx_iree_so_path: Path.join("cache", "libnx_iree.so"),
      nx_iree_tar_gz_path: Path.join("cache", "libnx_iree.tar.gz")
    }
  end

  defp download_and_unzip_iree_release(args) do
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
      :ok
    else
      download_and_unzip_iree_release(cache_dir, nx_iree_config)
    end
  end

  defp download_and_unzip_iree_release(cache_dir, nx_iree_config) do
    File.mkdir_p!(cache_dir)

    nx_iree_zip =
      Path.join(cache_dir, "iree-compiler-#{nx_iree_config.version}.zip")

    unless File.exists?(nx_iree_zip) do
      # Download iree release for the compiler
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

      download!("IREE", url, nx_iree_zip)
    end

    # Unpack libtorch and move to the target cache dir
    parent_iree_dir = Path.dirname(nx_iree_config.dir)
    File.mkdir_p!(parent_iree_dir)

    # Extract to the parent directory (it will be inside the libtorch directory)
    {:ok, _} =
      nx_iree_zip
      |> String.to_charlist()
      |> :zip.unzip(cwd: String.to_charlist(parent_iree_dir))

    # Remove stray files

    File.rm_rf(Path.join(parent_iree_dir, "iree_compiler.egg-info"))
    File.rm_rf(Path.join(parent_iree_dir, "iree_compiler-#{nx_iree_config.version}.dist-info"))

    iree_compile_path =
      Path.join([parent_iree_dir, "iree", "compiler", "_mlir_libs", "iree-compile"])

    iree_lld_path =
      Path.join([parent_iree_dir, "iree", "compiler", "_mlir_libs", "iree-lld"])

    File.chmod!(iree_compile_path, 0o755)
    File.chmod!(iree_lld_path, 0o755)

    priv_path = Path.join(Mix.Project.app_path(), "priv")
    File.mkdir_p!(priv_path)

    link_name = Path.join(priv_path, "iree-compile")

    File.rm(link_name)
    File.ln_s!(iree_compile_path, link_name)

    :ok
  end

  defp download_precompiled_nx_iree_lib() do
    nx_iree_config = nx_iree_config()

    arch =
      case to_string(:erlang.system_info(:system_architecture)) do
        "x86_64" <> _ -> "x86_64"
        "aarch64" <> _ -> "aarch64"
        _ -> Mix.raise("Unsupported architecture")
      end

    nif_version = :erlang.system_info(:nif_version)

    os_name =
      case :os.type() do
        {:unix, :darwin} ->
          "macos"

        {:unix, :linux} ->
          "linux"

        os ->
          Mix.raise("OS #{inspect(os)} is not supported")
      end

    # This is the precompiled path, which should match what's included in releases
    # by the github actions workflows
    version_path = "libnx_iree-#{os_name}-#{arch}-nif-#{nif_version}"
    source_tar_path = "#{version_path}.tar.gz"
    zip_name = nx_iree_config.nx_iree_tar_gz_path

    download!(
      "NxIREE NIFs",
      "https://github.com/elixir-nx/nx_iree/releases/download/v#{@version}/#{source_tar_path}",
      zip_name
    )

    parent_dir = Path.dirname(zip_name)

    :ok =
      zip_name
      |> String.to_charlist()
      |> :erl_tar.extract([:compressed, cwd: String.to_charlist(parent_dir)])

    File.rename(
      Path.join([parent_dir, version_path, "libnx_iree.so"]),
      Path.join(parent_dir, "libnx_iree.so")
    )

    File.rename(
      Path.join([parent_dir, version_path, "iree-runtime"]),
      Path.join(parent_dir, "iree-runtime")
    )

    File.rmdir(Path.join(parent_dir, version_path))

    :ok
  end

  defp assert_network_tool!() do
    unless network_tool() do
      raise "expected either curl or wget to be available in your system, but neither was found"
    end
  end

  defp download!(name, url, dest) do
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
