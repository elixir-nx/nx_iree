defmodule NxIREE.Compiler do
  @moduledoc """
  Compiler for Nx defn
  """

  @behaviour Nx.Defn.Compiler

  @impl true
  def __compile__(key, vars, fun, opts) do
    output_container = fun.(vars)

    {iree_compiler_flags, opts} = Keyword.pop(opts, :iree_compiler_flags, nil)
    {iree_runtime_options, opts} = Keyword.pop(opts, :iree_runtime_options, [])

    unless is_list(iree_compiler_flags) do
      raise "missing :iree_compiler_flags option"
    end

    mlir_module = EXLA.to_mlir_module(key, vars, opts)

    bytecode = NxIREE.compile(mlir_module, iree_compiler_flags)

    fn [inputs] ->
      {:ok, results} =
        NxIREE.call(
          bytecode,
          Enum.map(inputs, fn f ->
            f.()
          end),
          iree_runtime_options
        )

      {res, []} =
        Nx.Defn.Composite.traverse(output_container, Enum.reverse(results), fn _, [r | acc] ->
          {r, acc}
        end)

      [res]
    end
  end

  @impl true
  def __jit__(key, vars, fun, args_list, opts) do
    __compile__(key, vars, fun, opts).(args_list)
  end

  @impl true
  def __stream__(_key, _input, _acc, _vars, _fun, _args, _opts) do
    raise "__stream__ not supported yet in NxIREE"
  end

  @impl true
  defdelegate __partitions_options__(opts), to: EXLA.Defn

  @impl true
  defdelegate __to_backend__(opts), to: EXLA.Defn
end
