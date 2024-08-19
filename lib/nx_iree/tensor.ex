defmodule NxIREE.Tensor do
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
        "NxIREE.Tensor(#{device_uri})",
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
    device_uri = opts[:device]

    device_ref =
      case NxIREE.Device.get(device_uri) do
        {:ok, device_ref, _kind} -> device_ref
        _ -> raise ArgumentError, "received unknown device URI: #{inspect(device_uri)}"
      end

    {:ok, ref} = NxIREE.VM.allocate_buffer(number, device_ref)

    data = %__MODULE__{ref: ref, device: device_ref, device_uri: device_uri}

    %{out | data: data}
  end

  @impl true
  def from_binary(out, binary, opts) do
    device_uri = opts[:device] || "local-sync://default"

    device_ref =
      case NxIREE.Device.get(device_uri) do
        {:ok, device_ref, _kind} -> device_ref
        _ -> raise ArgumentError, "received unknown device URI: #{inspect(device_uri)}"
      end

    {:ok, ref} = NxIREE.VM.allocate_buffer(binary, device_ref, out.shape, out.type)

    %{
      out
      | data: %__MODULE__{ref: ref, device: device_ref, device_uri: device_uri}
    }
  end

  @impl true
  def backend_deallocate(_tensor) do
    # TO-DO: implement VM.deallocate_buffer
    :ok
  end

  @impl true
  def backend_copy(tensor, module, backend_options) do
    data = to_binary(tensor, -1)
    tensor = Nx.BinaryBackend.from_binary(data, tensor.type, [])
    Nx.BinaryBackend.backend_copy(tensor, module, backend_options)
  end

  @impl true
  def backend_transfer(tensor, module, backend_options) do
    data = to_binary(tensor, -1)
    out_tensor = Nx.BinaryBackend.from_binary(data, tensor.type, [])
    :ok = backend_deallocate(tensor)
    Nx.BinaryBackend.backend_transfer(out_tensor, module, backend_options)
  end

  @impl true
  def to_binary(%Nx.Tensor{type: {_, size}, data: data}, limit) do
    bytes = div(size, 8) * limit
    # TO-DO: implement reading with limit. For now, truncate locally
    data =
      case data do
        %{data: nil} ->
          NxIREE.VM.read_buffer(data.device, data.ref, bytes)

        %{data: data} ->
          data
      end

    if byte_size(data) == bytes do
      data
    else
      binary_part(data, 0, bytes)
    end
  end

  funs =
    Nx.Backend.behaviour_info(:callbacks) --
      (Nx.Backend.behaviour_info(:optional_callbacks) ++ Module.definitions_in(__MODULE__, :def))

  for {fun, arity} <- funs do
    args = Macro.generate_arguments(arity, __MODULE__)

    @impl true
    def unquote(fun)(unquote_splicing(args)) do
      raise "function not supported by the NxIREE backend"
    end
  end
end
