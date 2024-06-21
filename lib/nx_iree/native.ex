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

  def call_io(_bytecode, _inputs, _function, _device_ref), do: :erlang.nif_error(:undef)
  def call_cpu(_bytecode, _inputs, _function, _device_ref), do: :erlang.nif_error(:undef)
end
