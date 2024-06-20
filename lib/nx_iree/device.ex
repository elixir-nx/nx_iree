defmodule NxIREE.Device do
  @moduledoc false

  @cache_key {__MODULE__, :devices}

  def init() do
    {:ok, devices} = NxIREE.Native.list_devices()

    cache =
      Map.new(devices, fn device ->
        kind =
          if String.starts_with?(device, "local-sync") do
            :cpu
          else
            :io
          end

        {:ok, device_ref} = NxIREE.Native.create_device(device)

        {device, {device_ref, kind}}
      end)

    :persistent_term.put(@cache_key, cache)
  end

  def get(device_uri) do
    devices = :persistent_term.get(@cache_key)

    case Map.get(devices, device_uri) do
      nil -> {:error, :unknown_device}
      {device_ref, kind} -> {:ok, device_ref, kind}
    end
  end
end
