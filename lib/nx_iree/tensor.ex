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
  def constant(out, number) do
    data = out |> Nx.BinaryBackend.constant(number) |> Nx.to_binary()

    %__MODULE__{data: data}
  end

  @impl true
  def from_binary(out, binary, opts) do
    device_uri = opts[:device]

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
    data = to_binary(tensor)
    tensor = Nx.BinaryBackend.from_binary(data, tensor.type)
    Nx.BinaryBackend.backend_copy(tensor, module, backend_options)
  end

  @impl true
  def backend_transfer(tensor, module, backend_options) do
    data = to_binary(tensor)
    out_tensor = Nx.BinaryBackend.from_binary(data, tensor.type)
    :ok = backend_deallocate(tensor)
    Nx.BinaryBackend.backend_transfer(out_tensor, module, backend_options)
  end

  @impl true
  def to_binary(%__MODULE__{data: data}, limit) do
    # TO-DO: implement reading with limit. For now, truncate locally

    case data do
      %{data: nil} ->
        NxIREE.VM.read_buffer(data.device, data.ref)

      %{data: data} ->
        data
    end
    |> binary_part(0, limit)
  end
end
