defmodule NxIREE.VM do
  @moduledoc false

  @cache_key {__MODULE__, :iree_vm_instance}

  def create_instance do
    {:ok, instance} = NxIREE.Native.create_instance()

    :persistent_term.put(@cache_key, instance)
    {:ok, instance}
  end

  def get_instance do
    case :persistent_term.get(@cache_key, nil) do
      nil -> create_instance()
      instance -> instance
    end
  end

  def allocate_buffer(
        %Nx.Tensor{shape: shape, type: type, data: %NxIREE.Backend{} = t},
        device_ref
      ) do
    case t do
      %{data: nil, ref: ref, device_ref: ^device_ref} ->
        # Same device, so we can just return the ref
        ref

      %{data: nil} ->
        # in this case, we're dealing with different devices,
        # so we'll copy data from one to the other
        {:ok, data} = read_buffer(t)
        allocate_buffer(data, device_ref, shape, type)

      %{data: binary} ->
        allocate_buffer(binary, device_ref, Nx.shape(t), Nx.type(t))
    end
  end

  def allocate_buffer(%Nx.Tensor{} = t, device_ref) do
    allocate_buffer(Nx.to_binary(t), device_ref, Nx.shape(t), Nx.type(t))
  end

  def allocate_buffer(n, device_ref) when is_number(n) or is_struct(n, Complex) do
    # allocate a binary backend tensor for data uniformity
    t = Nx.tensor(n, backend: Nx.BinaryBackend)
    data = Nx.to_binary(t)
    shape = {}
    element_type = to_iree_type(Nx.type(t))

    NxIREE.Native.allocate_buffer(data, device_ref, Tuple.to_list(shape), element_type)
  end

  def allocate_buffer(binary, device_ref, shape, type) when is_binary(binary) do
    element_type = to_iree_type(type)
    NxIREE.Native.allocate_buffer(binary, device_ref, Tuple.to_list(shape), element_type)
  end

  def deallocate_buffer(%NxIREE.Backend{} = t) do
    NxIREE.Native.deallocate_buffer(t.ref)
  end

  def read_buffer(%NxIREE.Backend{} = t) do
    read_buffer(t.device, t.ref)
  end

  def read_buffer(device_ref, buffer_ref, num_bytes \\ -1) do
    NxIREE.Native.read_buffer(device_ref, buffer_ref, num_bytes)
  end

  defp to_iree_type(type) do
    case type do
      {:s, size} -> ~c"i#{size}"
      {:u, size} -> ~c"ui#{size}"
      {:bf, 16} -> ~c"bf16"
      {:f, size} -> ~c"f#{size}"
      {:c, size} -> ~c"c#{size}"
    end
  end
end
