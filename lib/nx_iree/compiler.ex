defmodule NxIREE.Compiler do
  @moduledoc """
  Compiler for Nx defn
  """

  def to_bytecode(fun, templates, opts \\ []) do
    opts = opts |> Keyword.put(:output_mode, :bytecode) |> Keyword.put(:compiler, __MODULE__)

    Nx.Defn.compile(fun, templates, opts)
  catch
    {:bytecode, %{bytecode: bytecode, output_container: output_container}} ->
      {:ok, %{bytecode: bytecode, output_container: output_container}}
  end

  @behaviour Nx.Defn.Compiler

  @impl true
  def __compile__(_key, vars, fun, opts) do
    {iree_compiler_flags, opts} = Keyword.pop(opts, :iree_compiler_flags, nil)
    {iree_runtime_options, opts} = Keyword.pop(opts, :iree_runtime_options, [])
    {output_mode, opts} = Keyword.pop(opts, :output_mode, nil)

    unless is_list(iree_compiler_flags) do
      raise "missing :iree_compiler_flags option"
    end

    %{mlir_module: mlir_module, output_container: output_container, used_inputs: used_inputs} =
      EXLA.to_mlir_module(fun, vars, Keyword.put(opts, :within_defn_compiler, true))

    bytecode = NxIREE.compile(mlir_module, iree_compiler_flags)

    if output_mode == :bytecode do
      throw({:bytecode, %{bytecode: bytecode, output_container: output_container}})
    else
      fn [inputs] ->
        filtered_inputs =
          filter_inputs_by_indices(inputs, used_inputs)

        {:ok, results} =
          NxIREE.call(
            bytecode,
            filtered_inputs,
            iree_runtime_options
          )

        {res, []} =
          Nx.Defn.Composite.traverse(output_container, results, fn _, [r | acc] ->
            {r, acc}
          end)

        [res]
      end
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

  defp filter_inputs_by_indices(args, inputs) do
    filter_by_indices_list(args, 0, Enum.sort(inputs), fn x, _ -> x end)
  end

  defp filter_by_indices_list([var | vars], i, [i | inputs], callback),
    do: [callback.(var, i) | filter_by_indices_list(vars, i + 1, inputs, callback)]

  defp filter_by_indices_list([_var | vars], i, inputs, callback),
    do: filter_by_indices_list(vars, i + 1, inputs, callback)

  defp filter_by_indices_list([], _i, [], _callback),
    do: []
end
