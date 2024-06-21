defmodule NxIREE.Device do
  @moduledoc false

  @device_key {__MODULE__, :devices}
  @registry_key {__MODULE__, :driver_registry}

  def init() do
    {:ok, driver_registry} = NxIREE.Native.get_driver_registry()
    :persistent_term.put(@registry_key, driver_registry)

    dbg(driver_registry)

    IO.gets("Press enter - #{System.pid()}")

    {:ok, drivers} = NxIREE.Native.list_drivers(driver_registry)

    devices =
      Enum.flat_map(drivers, fn {name, _} ->
        dbg(name)
        {:ok, devices} = NxIREE.Native.list_devices(driver_registry, name)
        dbg(devices)
      end)

    cache =
      Map.new(devices, fn {device_ref, driver_name, device_uri} ->
        kind =
          if List.starts_with?(device_uri, ~c"local-sync") do
            :cpu
          else
            :io
          end

        {to_string(device_uri), {device_ref, to_string(driver_name), kind}}
      end)

    :persistent_term.put(@device_key, cache)
  end

  def list_drivers do
    driver_registry = :persistent_term.get(@registry_key)

    case NxIREE.Native.list_drivers(driver_registry) do
      {:ok, drivers} ->
        drivers =
          Map.new(drivers, fn {name, full_name} -> {to_string(name), to_string(full_name)} end)

        {:ok, drivers}

      error ->
        error
    end
  end

  def list do
    devices = :persistent_term.get(@device_key)
    {:ok, Map.keys(devices)}
  end

  def list(driver) do
    devices = :persistent_term.get(@device_key)

    driver = to_string(driver)

    devices =
      for {_device_uri, {_ref, driver_name, _kind}} = entry <- devices,
          driver_name == driver,
          into: %{} do
        entry
      end

    {:ok, Map.keys(devices)}
  end

  def get(device_uri) do
    devices = :persistent_term.get(@device_key)

    case Map.get(devices, device_uri) do
      nil -> {:error, :unknown_device}
      {device_ref, _driver, kind} -> {:ok, device_ref, kind}
    end
  end
end
