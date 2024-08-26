defmodule LiveNxIREEWeb.CameraLive do
  use LiveNxIREEWeb, :live_view
  use LiveNxIREENative, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # register the liveview with presence.
    # This will make it so that we can interact with the liveview
    # from outside of the liveview itself.

    # this can probably be achieved by just changing assigns from within a handle_info call, somehow

    # need to figure out how to push and pull events from LVN. otherwise, we'll fallback
    # to a long-polling approach from within the liveview itself using a jobqueue via pubsub.

    dbg(self())

    socket =
      assign(socket,
        bytecode: nil,
        function_signature: nil,
        device_uri: nil,
        inputs: nil,
        num_outputs: nil,
        available_devices: [],
        height: 270,
        width: 480
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Contexts")
    |> assign(:home, nil)
  end

  @impl true
  def handle_event("nx-executed", serialized_outputs, socket) do
    {outputs, []} =
      Nx.Defn.Composite.traverse(
        socket.assigns.output_container,
        serialized_outputs,
        fn node, [base64 | acc] ->
          {:ok, ref} = base64 |> Base.decode64!() |> NxIREE.Native.deserialize_tensor()

          uri = "local-sync://"

          {:ok, device, _} = NxIREE.Device.get(uri)

          t = %Nx.Tensor{
            node
            | data: %NxIREE.Tensor{
                device_uri: uri,
                device: device,
                ref: ref
              }
          }

          {t, acc}
        end
      )

    send(socket.assigns.reply_to_pid, {:nx, :executed, outputs})

    {:noreply, socket}
  end

  def handle_event("nx-mounted", devices, socket) do
    available_devices =
      devices
      |> Enum.reject(&String.ends_with?(&1, "://default"))
      |> Enum.sort_by(&get_device_priority/1, :asc)
      |> Enum.map(fn device ->
        key = get_device_key(device)
        {key, %{uri: device, compiler_flag: get_device_flag(key)}}
      end)
      |> Enum.group_by(fn {k, _} -> k end, fn {_, v} -> v end)

    seed = System.system_time()

    function = fn image ->
      alpha = image[[.., .., 3..3]]

      noise = 0.25
      image = image[[.., .., 0..2]]
      {random, _} = Nx.Random.uniform(Nx.Random.key(seed), 0, noise, shape: Nx.shape(image))
      image = Nx.divide(image, 255) |> Nx.multiply(1 - noise)

      image =
        image
        |> Nx.add(random)
        |> Nx.multiply(255)
        |> Nx.as_type(:u8)

      Nx.concatenate([image, alpha], axis: -1)
    end

    {target_device, platform} = {:metal, :ios}

    %{compiler_flag: backend_flag, uri: device_uri} =
      case available_devices[target_device] do
        nil ->
          Enum.random(
            available_devices[:cpu] ||
              [%{compiler_flag: "--iree-hal-target-backends=llvm-cpu", uri: "local-sync://"}]
          )

        devices ->
          Enum.random(devices)
      end

    platform_flag =
      case {target_device, platform} do
        {:metal, platform} -> ["--iree-metal-target-platform=#{platform}"]
        _ -> []
      end

    compiler_flags =
      [
        backend_flag,
        "--iree-input-type=stablehlo_xla",
        "--iree-execution-model=async-internal"
      ] ++ platform_flag

    inputs = [Nx.template({socket.assigns.height, socket.assigns.width, 4}, :u8)]

    {:ok, %{bytecode: %NxIREE.Module{bytecode: bytecode}, output_container: output_container}} =
      NxIREE.Compiler.to_bytecode(function, inputs, iree_compiler_flags: compiler_flags)

    {_, num_outputs} =
      Nx.Defn.Composite.traverse(output_container, 0, fn node, acc -> {node, acc + 1} end)

    socket =
      socket
      |> assign(:bytecode, Base.encode64(bytecode))
      |> assign(:output_container, output_container)
      |> assign(:function_signature, get_signature(function, inputs, output_container))
      |> assign(:device_uri, device_uri)
      |> assign(:num_outputs, num_outputs)
      |> assign(:available_devices, available_devices)

    {:noreply, socket}
  end

  defp get_device_priority(device) do
    case device do
      "metal://" <> _ -> 0
      "cuda://" <> _ -> 0
      "rocm://" <> _ -> 0
      "local-sync://" <> _ -> 1
      _ -> 2
    end
  end

  defp get_device_key(device) do
    case device do
      "metal://" <> _ -> :metal
      "cuda://" <> _ -> :cuda
      "rocm://" <> _ -> :rocm
      "local-sync://" <> _ -> :cpu
      _ -> :cpu
    end
  end

  defp get_device_flag(device) do
    case device do
      :metal -> "--iree-hal-target-backends=metal-spirv"
      :cpu -> "--iree-hal-target-backends=llvm-cpu"
    end
  end

  defp get_signature({mod, fun, _a}, input_templates, output_container) do
    "#{inspect(mod)}.#{fun}(#{to_flat_type(input_templates)}) -> #{to_flat_type(output_container)}"
  end

  defp get_signature(fun, input_templates, output_container) do
    "#{inspect(fun)}(#{to_flat_type(input_templates)}) -> #{to_flat_type(output_container)}"
  end

  defp to_flat_type(container) do
    List.wrap(container)
    |> Nx.Defn.Composite.flatten_list()
    |> Enum.map(fn t ->
      type_as_string(t) <> "x" <> Enum.join(Tuple.to_list(Nx.shape(t)), "x")
    end)
    |> Enum.join(", ")
  end

  defp type_as_string(tensor) do
    {t, s} = Nx.type(tensor)

    "#{t}#{s}"
  end
end
