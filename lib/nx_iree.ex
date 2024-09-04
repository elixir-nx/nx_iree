defmodule NxIREE do
  @moduledoc """
  Documentation for `NxIREE`.
  """

  @doc """
  Compiles the given MLIR module with the given list of flags.

  Returns the bytecode for the compiled module.

  ## Examples

      iex> mlir_module = \"""
      ...> func.func @main(%arg0: tensor<4xf32>, %arg1: tensor<4xf32>) -> tensor<4xf32> {
      ...>   %0 = "stablehlo.multiply"(%arg0, %arg1) : (tensor<4xf32>, tensor<4xf32>) -> tensor<4xf32>
      ...>   return %0 : tensor<4xf32>
      ...> }
      ...>\"""
      iex> flags = ["--iree-hal-target-backends=llvm-cpu", "--iree-input-type=stablehlo_xla", "--iree-execution-model=async-internal"]
      iex> NxIREE.compile(mlir_module, flags)
  """
  def compile(mlir_module, flags \\ []) do
    {:ok, tmpfile} = create_temp_file(mlir_module)

    compiler_path = Path.join(:code.priv_dir(:nx_iree), "iree-compile")
    IO.puts(mlir_module)

    try do
      {output, 0} =
        System.cmd(
          compiler_path,
          flags ++ [tmpfile]
        )

      %NxIREE.Module{bytecode: output, compilation_flags: flags, mlir_module: mlir_module}
    after
      File.rm(tmpfile)
    end
  end

  defp create_temp_file(content) do
    tmpfile = Path.join(System.tmp_dir!(), "#{System.unique_integer()}-nx-iree-tempfile.mlir")

    case File.write(tmpfile, content) do
      :ok -> {:ok, tmpfile}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calls a function in the given module with the provided Nx inputs.

  ## Options

    # `:function` - The name of the function to call in the module. If not provided, will default to `"main"`.
    * `:device` - The device to run the module on. If not provided, will default to `"local-sync://".
      Valid values can be obtained through `list_devices/0` or `list_devices/1`.
  """
  def call(%NxIREE.Module{bytecode: bytecode}, inputs, opts \\ []) do
    opts = Keyword.validate!(opts, function: "main", device: "local-sync://")

    device = opts[:device]

    {device_ref, kind} =
      case NxIREE.Device.get(device) do
        {:ok, device_ref, kind} -> {device_ref, kind}
        _ -> raise ArgumentError, "received unknown device URI: #{inspect(opts[:device])}"
      end

    [driver_name, _] = String.split(device, "://", parts: 2)

    input_refs =
      Enum.map(inputs, fn
        %Nx.Tensor{data: %NxIREE.Tensor{ref: ref}} ->
          ref

        fun when is_function(fun, 0) ->
          NxIREE.VM.allocate_buffer(fun.(), device_ref)

        t ->
          NxIREE.VM.allocate_buffer(t, device_ref)
      end)

    instance_ref = NxIREE.VM.get_instance()

    result =
      if kind == :cpu do
        NxIREE.Native.call_cpu(instance_ref, device_ref, driver_name, bytecode, input_refs)
      else
        NxIREE.Native.call_io(instance_ref, device_ref, driver_name, bytecode, input_refs)
      end

    case result do
      {:ok, refs} ->
        tensors =
          Enum.map(refs, fn {ref, dims, type_str} ->
            %Nx.Tensor{
              names: Enum.map(dims, fn _ -> nil end),
              type: type_str_to_nx(type_str),
              shape: List.to_tuple(dims),
              data: %NxIREE.Tensor{
                ref: ref,
                data: nil,
                device_uri: device,
                device: device_ref,
                driver: driver_name
              }
            }
          end)

        {:ok, tensors}

      {:error, error} ->
        raise "IREE call failed due to: #{inspect(error)}"
    end
  end

  defp type_str_to_nx(~c"i8"), do: {:s, 8}
  defp type_str_to_nx(~c"i16"), do: {:s, 16}
  defp type_str_to_nx(~c"i32"), do: {:s, 32}
  defp type_str_to_nx(~c"i64"), do: {:s, 64}
  defp type_str_to_nx(~c"u8"), do: {:u, 8}
  defp type_str_to_nx(~c"u16"), do: {:u, 16}
  defp type_str_to_nx(~c"u32"), do: {:u, 32}
  defp type_str_to_nx(~c"u64"), do: {:u, 64}
  defp type_str_to_nx(~c"bf16"), do: {:bf, 16}
  defp type_str_to_nx(~c"f16"), do: {:f, 16}
  defp type_str_to_nx(~c"f32"), do: {:f, 32}
  defp type_str_to_nx(~c"f64"), do: {:f, 64}
  defp type_str_to_nx(~c"c64"), do: {:c, 64}
  defp type_str_to_nx(~c"c128"), do: {:c, 128}

  @doc """
  Lists all devices available for running IREE modules.
  """
  @spec list_devices(String.t()) :: {:ok, list(String.t())}
  def list_devices do
    # This function returns a tagged tuple for uniformity with the arity-1 clause.
    NxIREE.Device.list()
  end

  @doc """
  Lists all devices available in a given driver for running IREE modules.

  Valid drivers can be obtained through `list_drivers/0`.
  """
  @spec list_devices(String.t()) :: {:ok, list(String.t())} | {:error, :unknown_driver}
  def list_devices(driver) do
    NxIREE.Device.list(driver)
  end

  @doc """
  Lists all drivers available for running IREE modules.
  """
  @spec list_drivers() :: {:ok, list(String.t())} | {:error, :unknown_driver}
  def list_drivers do
    NxIREE.Device.list_drivers()
  end
end
