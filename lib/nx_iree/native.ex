defmodule NxIREE.Native do
  @moduledoc false
  @on_load :__on_load__

  def __on_load__ do
    # libnx_iree.so wraps libnx_iree_runtime.so/dylib and provides a NIF interface
    path = :filename.join(:code.priv_dir(:nx_iree), "libnx_iree")
    :erlang.load_nif(path, 0)
  end

  def create_instance, do: :erlang.nif_error(:undef)
  def get_driver_registry, do: :erlang.nif_error(:undef)

  def list_devices(_registry), do: :erlang.nif_error(:undef)
  def list_devices(_registry, _driver), do: :erlang.nif_error(:undef)
  def list_drivers(_registry), do: :erlang.nif_error(:undef)

  def create_device(_registry, _device_uri), do: :erlang.nif_error(:undef)

  def deallocate_buffer(_reference), do: :erlang.nif_error(:undef)
  def allocate_buffer(_data, _device_ref, _dims, _element_type), do: :erlang.nif_error(:undef)
  def read_buffer(_device_ref, _input_ref, _num_bytes), do: :erlang.nif_error(:undef)

  def call_io(_instance_ref, _device_ref, _driver_name, _bytecode, _inputs),
    do: :erlang.nif_error(:undef)

  def call_cpu(_instance_ref, _device_ref, _driver_name, _bytecode, _inputs),
    do: :erlang.nif_error(:undef)

  def serialize_tensor(_reference), do: :erlang.nif_error(:undef)
  def deserialize_tensor(_binary), do: :erlang.nif_error(:undef)
end
