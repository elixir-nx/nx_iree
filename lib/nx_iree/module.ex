defmodule NxIREE.Module do
  @doc """
  Holds the bytecode and other metadata for a compiled MLIR module.
  """

  defstruct [:bytecode, :compilation_flags, :mlir_module]

  @type t :: %__MODULE__{
          bytecode: String.t(),
          compilation_flags: list(String.t()),
          mlir_module: String.t()
        }
end
