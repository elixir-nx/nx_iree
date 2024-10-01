defmodule NxIREE.Device do
  @moduledoc false

  @device_key {__MODULE__, :devices}
  @registry_key {__MODULE__, :driver_registry}
  @default_device_key {__MODULE__, :default_device}

  defstruct [:ref, :driver_name, :kind, :id, :uri, :compiler_target_backend]

  def init() do
    {:ok, driver_registry} = NxIREE.Native.get_driver_registry()
    :persistent_term.put(@registry_key, driver_registry)

    {:ok, drivers} = NxIREE.Native.list_drivers(driver_registry)

    devices =
      Enum.flat_map(drivers, fn {name, _} ->
        {:ok, devices} = NxIREE.Native.list_devices(driver_registry, name)
        devices
      end)
      |> dbg()

    cache =
      devices
      |> Enum.map(fn {device_ref, driver_name, device_uri, device_id} ->
        kind =
          if List.starts_with?(device_uri, ~c"local-sync") do
            :cpu
          else
            :io
          end

        device_uri = to_string(device_uri)

        driver_name = to_string(driver_name)

        %__MODULE__{
          uri: device_uri,
          ref: device_ref,
          driver_name: driver_name,
          kind: kind,
          id: device_id,
          compiler_target_backend: compiler_target_backend(driver_name)
        }
      end)
      |> sort_devices_by_priority()

    :persistent_term.put(@device_key, cache)

    :persistent_term.put(@default_device_key, find_default_device())
  end

  defp compiler_target_backend("metal"), do: "metal-spirv"
  defp compiler_target_backend("cuda"), do: "cuda"
  defp compiler_target_backend("rocm"), do: "rocm"
  defp compiler_target_backend("vulkan"), do: "vulkan-spirv"
  defp compiler_target_backend("local-sync"), do: "llvm-cpu"
  defp compiler_target_backend("local-task"), do: "llvm-cpu"
  defp compiler_target_backend(_), do: nil

  defp sort_devices_by_priority(devices) do
    Enum.sort_by(devices, fn device ->
      if String.ends_with?(device.uri, "://") or String.ends_with?(device.uri, "://default") do
        -1
      else
        device.id
      end
    end)
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
    {:ok, devices}
  end

  def list(driver) do
    devices = :persistent_term.get(@device_key)

    driver = to_string(driver)

    devices = Enum.filter(devices, &(&1.driver_name == driver))

    {:ok, devices}
  end

  def get(nil) do
    {:ok, default_device()}
  end

  def get(%__MODULE__{} = device) do
    {:ok, device}
  end

  def get(device_uri) do
    devices = :persistent_term.get(@device_key)

    case Enum.find(devices, &(&1.uri == device_uri)) do
      nil -> {:error, :unknown_device}
      device -> {:ok, device}
    end
  end

  def default_device do
    :persistent_term.get(@default_device_key)
  end

  def find_default_device do
    {:ok, drivers} = list_drivers()

    drivers =
      Enum.sort_by(
        drivers,
        fn {name, _} ->
          case name do
            "cuda" -> 0
            "rocm" -> 0
            "metal" -> 0
            "vulkan" -> 0
            _ -> 1
          end
        end,
        :asc
      )

    Enum.find_value(drivers, fn {driver_name, _} -> find_default_device(driver_name) end)
  end

  def find_default_device(driver) do
    {:ok, devices} = list(driver)
    Enum.at(devices, 0)
  end
end
