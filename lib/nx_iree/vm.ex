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

  # TO-DO: provide a skeleton backend to transfer buffers from one computation
  # to another. For now, we will bring data back to the CPU.
  def allocate_buffer(%Nx.Tensor{} = t, device_ref) do
    data = Nx.to_binary(t)
    shape = Nx.shape(t)
    element_type = to_iree_type(Nx.type(t))

    {:ok, buffer_ref} =
      NxIREE.Native.allocate_buffer(data, device_ref, Tuple.to_list(shape), element_type)

    buffer_ref
  end

  def allocate_buffer(n, device_ref) when is_number(n) do
    # allocate a binary backend tensor for data uniformity
    t = Nx.tensor(n, backend: Nx.BinaryBackend)
    data = Nx.to_binary(t)
    shape = {}
    element_type = to_iree_type(Nx.type(t))

    {:ok, buffer_ref} =
      NxIREE.Native.allocate_buffer(data, device_ref, Tuple.to_list(shape), element_type)

    buffer_ref
  end

  def read_buffer(device_ref, buffer_ref) do
    {:ok, binary} = NxIREE.Native.read_buffer(device_ref, buffer_ref)
    binary
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
