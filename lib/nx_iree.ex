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

    try do
      {output, 0} =
        System.cmd(
          Path.join(:code.priv_dir(:nx_iree), "iree-compile"),
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

    input_refs = Enum.map(inputs, &NxIREE.VM.allocate_buffer(&1, device_ref))

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
          Enum.map(
            refs,
            &%Nx.Tensor{
              # type: out_type,
              # shape: out_shape,
              data: %NxIREE.Tensor{
                ref: &1,
                data: nil,
                device_uri: device,
                device: device_ref,
                driver: driver_name
              }
            }
          )

        {:ok, tensors}

      {:error, error} ->
        raise "IREE call failed due to: #{inspect(error)}"
    end
  end

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
