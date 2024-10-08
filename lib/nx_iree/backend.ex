defmodule NxIREE.Backend do
  @moduledoc """
  A thin `Nx.Backend` implementation for IREE.

  Provides simple `from_binary/2` and `to_binary/1` calls, as well as
  handling output buffer references for IREE call outputs.
  """

  defstruct [:data, :ref, :device, :device_uri, :driver]

  @behaviour Nx.Backend

  @impl true
  def init(_opts) do
    []
  end

  @impl true
  def inspect(%Nx.Tensor{} = tensor, inspect_opts) do
    limit = if inspect_opts.limit == :infinity, do: :infinity, else: inspect_opts.limit + 1

    data = to_binary(tensor, min(limit, Nx.size(tensor)))

    tensor
    |> Nx.Backend.inspect(data, inspect_opts)
    |> maybe_add_signature(tensor)
  end

  if Application.compile_env(:nx_iree, :add_backend_on_inspect, true) do
    defp maybe_add_signature(result, %Nx.Tensor{data: %__MODULE__{device_uri: device_uri}}) do
      Inspect.Algebra.concat([
        "NxIREE.Backend(#{device_uri})",
        Inspect.Algebra.line(),
        result
      ])
    end
  else
    defp maybe_add_signature(result, _tensor) do
      result
    end
  end

  @impl true
  def constant(out, number, opts) do
    {:ok, %NxIREE.Device{ref: device_ref, uri: device_uri}} = NxIREE.Device.get(opts[:device])

    {:ok, ref} = NxIREE.VM.allocate_buffer(number, device_ref)

    data = %__MODULE__{ref: ref, device: device_ref, device_uri: device_uri}

    %{out | data: data}
  end

  @impl true
  def from_binary(out, binary, opts) do
    {:ok, %NxIREE.Device{ref: device_ref, uri: device_uri}} = NxIREE.Device.get(opts[:device])

    {:ok, ref} = NxIREE.VM.allocate_buffer(binary, device_ref, out.shape, out.type)

    %{
      out
      | data: %__MODULE__{ref: ref, device: device_ref, device_uri: device_uri}
    }
  end

  @impl true
  def backend_deallocate(tensor) do
    :ok = NxIREE.VM.deallocate_buffer(tensor.data)
  end

  @impl true
  def backend_copy(tensor, module, backend_options) do
    data = to_binary(tensor, -1)

    tensor = Nx.BinaryBackend.from_binary(tensor, data, [])
    Nx.BinaryBackend.backend_copy(tensor, module, backend_options)
  end

  @impl true
  def backend_transfer(tensor, module, backend_options) do
    data = to_binary(tensor, -1)
    out_tensor = Nx.BinaryBackend.from_binary(tensor, data, [])
    :ok = backend_deallocate(tensor)
    Nx.BinaryBackend.backend_transfer(out_tensor, module, backend_options)
  end

  @impl true
  def to_binary(%Nx.Tensor{type: {_, size}, data: data}, limit) do
    bytes =
      if limit == -1 do
        limit
      else
        div(size, 8) * limit
      end

    # TO-DO: implement reading with limit. For now, truncate locally
    data =
      case data do
        %{data: nil} ->
          {:ok, binary} = NxIREE.VM.read_buffer(data.device, data.ref, bytes)
          binary

        %{data: data} ->
          data
      end

    if limit == -1 or byte_size(data) == bytes do
      data
    else
      binary_part(data, 0, bytes)
    end
  end

  @impl true
  def to_batched(out, tensor, opts) do
    leftover = opts[:leftover]

    batch_size = elem(out.shape, 0)
    axis_size = elem(tensor.shape, 0)

    remainder = rem(axis_size, batch_size)
    num_full_batches = div(axis_size, batch_size)

    range =
      if remainder != 0 and leftover == :repeat do
        0..num_full_batches
      else
        0..(num_full_batches - 1)
      end

    Stream.map(range, fn
      ^num_full_batches ->
        expr_fun = fn tensor ->
          Nx.concatenate([
            Nx.slice_along_axis(tensor, num_full_batches * batch_size, remainder),
            Nx.slice_along_axis(tensor, 0, batch_size - remainder)
          ])
        end

        jit([], expr_fun, [tensor])

      i ->
        expr_fun = fn tensor, start_idx ->
          Nx.slice_along_axis(tensor, start_idx, batch_size)
        end

        start_idx = i * batch_size
        jit([], expr_fun, [tensor, start_idx])
    end)
  end

  @impl true
  def concatenate(out, tensors, axis) do
    copied = Enum.map(tensors, &Nx.backend_copy(&1, Nx.BinaryBackend))
    result = Nx.BinaryBackend.concatenate(out, copied, axis)
    Nx.backend_transfer(result, {NxIREE.Backend, jit_opts([], tensors)})
  end

  @impl true
  def stack(out, tensors, axis) do
    copied = Enum.map(tensors, &Nx.backend_copy(&1, Nx.BinaryBackend))
    result = Nx.BinaryBackend.stack(out, copied, axis)
    Nx.backend_transfer(result, {NxIREE.Backend, jit_opts([], tensors)})
  end

  @impl true
  def slice(out, tensor, start_indices, lengths, strides) do
    out = Nx.to_template(out)

    if Enum.all?(start_indices, &is_integer/1) do
      expr_fun = fn tensor ->
        Nx.Defn.Expr.slice(out, tensor, start_indices, lengths, strides)
      end

      jit([], expr_fun, [tensor])
    else
      expr_fun = fn tensor, start_indices ->
        Nx.Defn.Expr.slice(out, tensor, Tuple.to_list(start_indices), lengths, strides)
      end

      jit([], expr_fun, [tensor | start_indices], [tensor, List.to_tuple(start_indices)])
    end
  end

  @impl true
  def put_slice(out, tensor, start_indices, slice) do
    out = Nx.to_template(out)

    if Enum.all?(start_indices, &is_integer/1) do
      expr_fun = fn tensor, slice ->
        Nx.Defn.Expr.put_slice(out, tensor, start_indices, slice)
      end

      jit([], expr_fun, [tensor, slice])
    else
      expr_fun = fn tensor, start_indices, slice ->
        Nx.Defn.Expr.put_slice(out, tensor, Tuple.to_list(start_indices), slice)
      end

      jit(
        [],
        expr_fun,
        [tensor, slice | start_indices],
        [tensor, List.to_tuple(start_indices), slice]
      )
    end
  end

  @impl true
  def optional(name, args, fun) do
    # Here we take the leading tensor arguments and pass them as JIT arguments
    {tensors, rest} = Enum.split_while(args, &is_struct(&1, Nx.Tensor))

    wrapper_fun = fn tensors ->
      Nx.Defn.Expr.optional(name, Tuple.to_list(tensors) ++ rest, fun)
    end

    jit([], wrapper_fun, tensors, [List.to_tuple(tensors)])
  end

  @impl true
  def to_pointer(_, _) do
    raise "function not supported yet by NxIREE"
  end

  @impl true
  def from_pointer(_, _, _, _, _) do
    raise "function not supported yet by NxIREE"
  end

  binary_ops =
    [:add, :subtract, :multiply, :pow, :remainder, :divide, :atan2, :min, :max, :quotient] ++
      [:bitwise_and, :bitwise_or, :bitwise_xor, :left_shift, :right_shift] ++
      [:equal, :not_equal, :greater, :less, :greater_equal, :less_equal] ++
      [:logical_and, :logical_or, :logical_xor]

  unary_ops =
    [:exp, :expm1, :log, :log1p, :sigmoid, :cos, :sin, :tan] ++
      [:cosh, :sinh, :tanh, :acos, :asin, :atan, :acosh, :asinh, :atanh] ++
      [:sqrt, :rsqrt, :cbrt, :is_nan, :is_infinity, :erf, :erfc, :erf_inv] ++
      [:abs, :bitwise_not, :ceil, :conjugate, :floor, :negate, :round, :sign] ++
      [:count_leading_zeros, :population_count, :real, :imag]

  callbacks =
    [
      {:eye, [:backend_options], []},
      {:iota, [:axis, :backend_options], []},
      {:as_type, [:tensor], [:tensor]},
      {:bitcast, [:tensor], [:tensor]},
      {:reshape, [:tensor], [:tensor]},
      {:squeeze, [:tensor, :axes], [:tensor]},
      {:broadcast, [:tensor, :shape, :axes], [:tensor]},
      {:transpose, [:tensor, :axes], [:tensor]},
      {:pad, [:tensor, :pad_value, :padding_config], [:tensor, :pad_value]},
      {:reverse, [:tensor, :axes], [:tensor]},
      {:dot, [:left, :c1, :b1, :right, :c2, :b2], [:left, :right]},
      {:clip, [:tensor, :min, :max], [:tensor, :min, :max]},
      {:gather, [:input, :indices, :opts], [:input, :indices]},
      {:select, [:pred, :on_true, :on_false], [:pred, :on_true, :on_false]},
      {:conv, [:tensor, :kernel, :opts], [:tensor, :kernel]},
      {:all, [:tensor, :opts], [:tensor]},
      {:any, [:tensor, :opts], [:tensor]},
      {:sum, [:tensor, :opts], [:tensor]},
      {:product, [:tensor, :opts], [:tensor]},
      {:reduce_max, [:tensor, :opts], [:tensor]},
      {:reduce_min, [:tensor, :opts], [:tensor]},
      {:argmax, [:tensor, :opts], [:tensor]},
      {:argmin, [:tensor, :opts], [:tensor]},
      {:reduce, [:tensor, :acc, :opts, :fun], [:tensor, :acc]},
      {:window_reduce, [:tensor, :acc, :shape, :opts, :fun], [:tensor, :acc]},
      {:window_sum, [:tensor, :shape, :opts], [:tensor]},
      {:window_product, [:tensor, :shape, :opts], [:tensor]},
      {:window_max, [:tensor, :shape, :opts], [:tensor]},
      {:window_min, [:tensor, :shape, :opts], [:tensor]},
      {:sort, [:tensor, :opts], [:tensor]},
      {:argsort, [:tensor, :opts], [:tensor]},
      {:window_scatter_max, [:tensor, :source, :init_value, :window_dims, :opts],
       [:tensor, :source, :init_value]},
      {:window_scatter_min, [:tensor, :source, :init_value, :window_dims, :opts],
       [:tensor, :source, :init_value]},
      {:indexed_add, [:tensor, :indices, :updates, :opts], [:tensor, :indices, :updates]},
      {:indexed_put, [:tensor, :indices, :updates, :opts], [:tensor, :indices, :updates]},
      {:lu, [:tensor, :opts], [:tensor]},
      {:triangular_solve, [:a, :b, :opts], [:a, :b]},
      {:fft, [:tensor, :opts], [:tensor]},
      {:ifft, [:tensor, :opts], [:tensor]}
    ] ++
      for(op <- binary_ops, do: {op, [:left, :right], [:left, :right]}) ++
      for(op <- unary_ops, do: {op, [:tensor], [:tensor]})

  for {name, args, tensor_args} <- callbacks do
    args = Enum.map(args, &Macro.var(&1, __MODULE__))
    tensor_args = Enum.map(tensor_args, &Macro.var(&1, __MODULE__))

    backend_options = Enum.find(args, [], &match?({:backend_options, _, _}, &1))

    @impl true
    def unquote(name)(out, unquote_splicing(args)) do
      out = Nx.to_template(out)

      expr_fun = fn unquote_splicing(tensor_args) ->
        Nx.Defn.Expr.unquote(name)(out, unquote_splicing(args))
      end

      jit(unquote(backend_options), expr_fun, [unquote_splicing(tensor_args)])
    end
  end

  defp jit(opts, fun, args), do: jit(opts, fun, args, args)

  defp jit(opts, fun, tensors, args) do
    Nx.Defn.jit_apply(
      fun,
      args,
      [compiler: NxIREE.Compiler, on_conflict: :force] ++ jit_opts(tensors, opts)
    )
  end

  defp jit_opts(_tensors, _opts) do
    Nx.Defn.default_options()
    # {priority_client, priority_did, backup_client, backup_did} =
    #   for %T{data: %B{buffer: %EXLA.DeviceBuffer{client_name: client_name, device_id: device_id}}} <-
    #         tensors,
    #       reduce: {nil, nil, nil, nil} do
    #     {^client_name, ^device_id, _, _} = acc ->
    #       acc

    #     {priority_client, priority_did, backup_client, backup_did} ->
    #       # If the client supports automatic transfers (typically host),
    #       # it should not win over the cuda/rocm. At the same time,
    #       # if it is the only device, we don't want to discard it.
    #       case EXLA.Client.fetch!(client_name) do
    #         %{automatic_transfers: true, default_device_id: ^device_id} ->
    #           {priority_client, priority_did, client_name, device_id}

    #         _ ->
    #           {client_name, device_id, backup_client, backup_did}
    #       end
    #   end

    # client =
    #   opts[:client] || priority_client || backup_client ||
    #     EXLA.Client.default_name()

    # device_id =
    #   opts[:device_id] || priority_did || backup_did ||
    #     EXLA.Client.fetch!(client).default_device_id

    # [client: client, device_id: device_id]
  end
end
