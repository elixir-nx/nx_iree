defmodule NxIREE.VM do
  @moduledoc false

  @cache_key {__MODULE__, :iree_vm_instance}

  def create_instance do
    {:ok, instance} = NxIREE.Native.create_instance_and_register_drivers()

    :persistent_term.put(@cache_key, instance)
  end
end
