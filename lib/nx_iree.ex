defmodule NxIree do
  @moduledoc """
  Documentation for `NxIree`.
  """

  @doc """
  Compiles the given MLIR module with the given list of flags.

  Returns the bytecode for the compiled module.

  ## Examples

      iex> mlir_module = \"""
      ...> func.func @simple_mul(%arg0: tensor<4xf32>, %arg1: tensor<4xf32>) -> tensor<4xf32> {
      ...>   %0 = "stablehlo.multiply"(%arg0, %arg1) : (tensor<4xf32>, tensor<4xf32>) -> tensor<4xf32>
      ...>   return %0 : tensor<4xf32>
      ...> }
      ...>\"""
      iex> flags = ["--iree-hal-target-backends=llvm-cpu", "--iree-input-type=stablehlo_xla", "--iree-execution-model=async-internal"]
      iex> NxIree.compile(mlir_module, flags)
  """
  def compile(mlir_module, flags \\ []) do
    {:ok, tmpfile} = create_temp_file(mlir_module)

    try do
      {output, 0} =
        System.cmd(
          Path.join(:code.priv_dir(:nx_iree), "iree-compile"),
          dbg(flags ++ [tmpfile])
        )

      output
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
end
