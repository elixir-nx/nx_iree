defmodule LiveNxIREEWeb.HomeLive do
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

    socket = assign(socket, bytecode: nil, function_signature: nil, device: nil)

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

  # def handle_info({:nx, :execute, function, input_templates}, socket) do
  #   socket =
  #     assign(
  #       socket,
  #       :bytecode,
  #       Base.encode64(inspect({:nx, :execute, function, input_templates}))
  #     )

  #   {:noreply, socket}
  # end

  @impl true
  def handle_info({:nx, :execute, function, input_templates, target_device, reply_to_pid}, socket) do
    fun =
      case function do
        {m, f, a} ->
          Function.capture(m, f, a)

        _ ->
          raise """
          Expected a tuple of module, function, and arguments, but got: #{inspect(function)}
          """
      end

    {backend_flag, runtime_device} =
      case target_device do
        :metal ->
          {"--iree-hal-target-backends=metal-spirv", "metal://default"}

        :cpu ->
          {"--iree-hal-target-backends=llvm-cpu", "local-sync://default"}
      end

    compiler_flags = [
      backend_flag,
      "--iree-input-type=stablehlo_xla",
      "--iree-execution-model=async-internal"
    ]

    {:ok, %{bytecode: %NxIREE.Module{bytecode: bytecode}, output_container: output_container}} =
      NxIREE.Compiler.to_bytecode(fun, input_templates, iree_compiler_flags: compiler_flags)

    socket =
      socket
      |> assign(:bytecode, Base.encode64(bytecode))
      |> assign(:output_container, output_container)
      |> assign(:function_signature, get_signature(function, input_templates, output_container))
      |> assign(:device, runtime_device)
      |> assign(:reply_to_pid, reply_to_pid)

    {:noreply, socket}
  end

  @impl true
  def handle_event("nx-executed", params, socket) do
    send(socket.assigns.reply_to_pid, {:nx, :executed, params})

    {:noreply, assign(socket, :reply_to_pid, nil)}
  end

  defp get_signature({mod, fun, _a}, input_templates, output_container) do
    "#{inspect(mod)}.#{fun}(#{to_flat_type(input_templates)}) -> #{to_flat_type(output_container)}"
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
