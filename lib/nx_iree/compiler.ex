defmodule NxIREE.Compiler do
  @moduledoc """
  Compiler for Nx defn
  """

  alias NxIREE.Compiler.GraphSplitter

  def to_bytecode(fun, templates, opts \\ []) do
    opts = opts |> Keyword.put(:output_mode, :bytecode) |> Keyword.put(:compiler, __MODULE__)

    Nx.Defn.compile(fun, templates, opts)
  catch
    {:bytecode, result} ->
      {:ok, result}
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

    has_target_backend_flag? =
      Enum.any?(iree_compiler_flags, &String.starts_with?(&1, "--iree-hal-target-backends"))

    {iree_compiler_flags, backend} =
      cond do
        is_nil(iree_runtime_options[:device]) and not has_target_backend_flag? ->
          %{compiler_target_backend: backend} = NxIREE.Device.default_device()
          flag = "--iree-hal-target-backends=#{backend}"
          {[flag | iree_compiler_flags], backend}

        not has_target_backend_flag? ->
          {:ok, %{compiler_target_backend: backend}} =
            NxIREE.Device.get(iree_runtime_options[:device])

          {["--iree-hal-target-backends=#{backend}" | iree_compiler_flags], backend}

        true ->
          "--iree-hal-target-backends=" <> backend =
            Enum.find(
              iree_compiler_flags,
              &String.starts_with?(&1, "--iree-hal-target-backends=")
            )

          {iree_compiler_flags, backend}
      end

    exla_opts = opts |> Keyword.put(:within_defn_compiler, true) |> Keyword.put(:client, :host)

    if output_mode != :bytecode and backend == "metal-spirv" do
      compile_with_graph_splitter(
        fun,
        vars,
        exla_opts,
        iree_compiler_flags,
        iree_runtime_options
      )
    else
      compile_without_graph_splitter(
        fun,
        vars,
        exla_opts,
        iree_compiler_flags,
        iree_runtime_options,
        output_mode
      )
    end
  end

  defp compile_without_graph_splitter(
         fun,
         vars,
         exla_opts,
         iree_compiler_flags,
         iree_runtime_options,
         output_mode
       ) do
    %{mlir_module: mlir_module, output_container: output_container, used_inputs: used_inputs} =
      EXLA.to_mlir_module(fun, vars, exla_opts)

    nx_iree_module =
      NxIREE.compile(mlir_module, iree_compiler_flags, output_container: output_container)

    if output_mode == :bytecode do
      throw({:bytecode, nx_iree_module})
    else
      fn [inputs] ->
        filtered_inputs =
          filter_inputs_by_indices(inputs, used_inputs)

        {:ok, result} =
          NxIREE.call(
            nx_iree_module,
            filtered_inputs,
            iree_runtime_options
          )

        [result]
      end
    end
  end

  defp compile_with_graph_splitter(
         fun,
         vars,
         exla_opts,
         iree_compiler_flags,
         iree_runtime_options
       ) do
    expr = fun.(vars)

    {stages, _, _} = GraphSplitter.traverse(expr)

    function_chain =
      for {stage_id, tag, expr, arguments, argument_sources} <- stages do
        fun = fn _ -> expr end

        %{mlir_module: mlir_module, output_container: output_container, used_inputs: used_inputs} =
          EXLA.to_mlir_module(fun, Map.values(arguments), exla_opts)

        iree_compiler_flags =
          if tag == :force_host do
            Enum.map(iree_compiler_flags, fn
              "--iree-hal-target-backends=metal-spirv" -> "--iree-hal-target-backends=llvm-cpu"
              flag -> flag
            end)
          else
            iree_compiler_flags
          end

        iree_runtime_options =
          if tag == :force_host do
            {:ok, device} = NxIREE.Device.get("local-sync://")
            Keyword.put(iree_runtime_options, :device, device)
          else
            Keyword.put_new(
              iree_runtime_options,
              :device,
              NxIREE.Device.find_default_device("metal")
            )
          end

        nx_iree_module =
          NxIREE.compile(mlir_module, iree_compiler_flags, output_container: output_container)

        runtime_fun = fn [inputs] ->
          filtered_inputs =
            filter_inputs_by_indices(inputs, used_inputs)

          {:ok, result} =
            NxIREE.call(
              nx_iree_module,
              filtered_inputs,
              iree_runtime_options
            )

          [result]
        end

        {stage_id, tag, iree_runtime_options[:device], runtime_fun, arguments, argument_sources}
      end

    fn [args] ->
      input_sources =
        args
        |> Enum.with_index()
        |> Map.new(fn {arg, idx} ->
          {{nil, idx}, arg}
        end)

      {_input_sources, result} =
        for {stage_id, _tag, device, runtime_fun, arguments, argument_sources} <- function_chain,
            reduce: {input_sources, nil} do
          {input_sources, _prev_result} ->
            {args, input_sources} =
              Enum.map_reduce(arguments, input_sources, fn {id, param}, input_sources ->
                %Nx.Tensor{data: %Nx.Defn.Expr{op: :parameter, args: [idx]}} = param
                source_key = argument_sources[id]

                case input_sources[source_key] do
                  input when is_function(input, 0) ->
                    val = input.()

                    val =
                      Nx.Defn.Composite.traverse(val, fn
                        %Nx.Tensor{data: %NxIREE.Backend{}} = t -> t
                        t -> Nx.backend_transfer(t, {NxIREE.Backend, device: device})
                      end)

                    {{idx, val}, Map.put(input_sources, source_key, val)}

                  val ->
                    {{idx, val}, input_sources}
                end
              end)

            args =
              args
              |> Enum.sort_by(&elem(&1, 0))
              |> Enum.map(fn {_idx, arg} ->
                {:ok, buffer_ref} = NxIREE.VM.allocate_buffer(arg, device.ref)
                arg = put_in(arg.data.ref, buffer_ref)
                put_in(arg.data.device, device.ref)
                put_in(arg.data.device_uri, device.uri)
                put_in(arg.data.driver, device.driver_name)
              end)

            [results] = runtime_fun.([args])

            input_sources =
              [results]
              |> Nx.Defn.Composite.flatten_list()
              |> Enum.with_index()
              |> Enum.reduce(input_sources, fn {result, idx}, acc ->
                Map.put(acc, {stage_id, idx}, result)
              end)

            {input_sources, [results]}
        end

      result
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
