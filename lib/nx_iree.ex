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
  def compile(mlir_module, flags, opts \\ []) do
    output_container = opts[:output_container]
    {:ok, tmpfile} = create_temp_file(mlir_module)

    compiler_path = opts[:compiler_path] || Path.join(:code.priv_dir(:nx_iree), "iree-compile")

    try do
      {output, 0} =
        System.cmd(
          compiler_path,
          flags ++ [tmpfile]
        )

      %NxIREE.Module{
        bytecode: output,
        compilation_flags: flags,
        mlir_module: mlir_module,
        output_container: output_container
      }
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
  def call(
        %NxIREE.Module{bytecode: bytecode, output_container: output_container},
        inputs,
        opts \\ []
      ) do
    opts = Keyword.validate!(opts, function: "main", device: nil)

    {:ok, %NxIREE.Device{driver_name: driver_name, ref: device_ref, uri: device_uri}} =
      NxIREE.Device.get(opts[:device])

    input_refs =
      Enum.map(inputs, fn
        %Nx.Tensor{data: %NxIREE.Backend{ref: ref}} ->
          ref

        fun when is_function(fun, 0) ->
          {:ok, ref} = NxIREE.VM.allocate_buffer(fun.(), device_ref)
          ref

        t ->
          {:ok, ref} = NxIREE.VM.allocate_buffer(t, device_ref)
          ref
      end)

    instance_ref = NxIREE.VM.get_instance()

    result =
      NxIREE.Native.call_io(instance_ref, device_ref, driver_name, bytecode, input_refs)

    case result do
      {:ok, refs} ->
        {tensors, []} =
          Nx.Defn.Composite.traverse(output_container, refs, fn hole,
                                                                [{ref, _dims, _type_str} | refs] ->
            data = %NxIREE.Backend{
              ref: ref,
              data: nil,
              device_uri: device_uri,
              device: device_ref,
              driver: driver_name
            }

            {%{hole | data: data}, refs}
          end)

        # tensors =
        #   Enum.map(refs, fn {ref, dims, type_str} ->
        #     %Nx.Tensor{
        #       names: Enum.map(dims, fn _ -> nil end),
        #       type: type_str_to_nx(type_str),
        #       shape: List.to_tuple(dims),
        #       data: %NxIREE.Backend{
        #         ref: ref,
        #         data: nil,
        #         device_uri: device,
        #         device: device_ref,
        #         driver: driver_name
        #       }
        #     }
        #   end)

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
