defmodule NxIREE.Native do
  @moduledoc false
  @on_load :__on_load__

  def __on_load__ do
    # libnx_iree.so wraps libnx_iree_runtime.so/dylib and provides a NIF interface
    path = :filename.join(:code.priv_dir(:nx_iree), "libnx_iree")
    :erlang.load_nif(path, 0)
  end

  def list_devices, do: :erlang.nif_error(:undef)
  def list_devices(_driver), do: :erlang.nif_error(:undef)
  def list_drivers, do: :erlang.nif_error(:undef)

  def create_device(_device_uri), do: :erlang.nif_error(:undef)

  def call_io(_bytecode, _inputs, _function, _device_ref), do: :erlang.nif_error(:undef)
  def call_cpu(_bytecode, _inputs, _function, _device_ref), do: :erlang.nif_error(:undef)
end
