defmodule Papyrus.Display do
  @moduledoc """
  GenServer that owns the port to the `epd_port` C binary.

  All hardware operations are serialized through this process. Each call
  blocks until the C binary sends back a response (which may take up to
  ~30 seconds for a full display refresh).

  If the port exits unexpectedly (hardware fault, lgpio error), the
  GenServer stops with reason `{:port_exited, exit_status}` and the
  supervising tree can restart it.
  """

  use GenServer
  require Logger
  alias Papyrus.Protocol

  defstruct [:port, :spec, :pending_from, :buffer]

  @port_binary "epd_port"

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Start a Display GenServer.

  ## Options

  - `:display_module` — module implementing `Papyrus.DisplaySpec` (required)
  - `:name` — registered name for the GenServer (optional)
  - `:port_binary` — path to the port executable; defaults to the bundled
    `priv/epd_port` binary (optional, useful for testing)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {gen_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, gen_opts)
  end

  @doc "Send a full-frame image buffer. Blocks until the display refreshes."
  @spec display(GenServer.server(), binary()) :: :ok | {:error, term()}
  def display(server, image), do: GenServer.call(server, {:display, image}, :infinity)

  @doc "Clear the display to white. Blocks until complete."
  @spec clear(GenServer.server()) :: :ok | {:error, term()}
  def clear(server), do: GenServer.call(server, :clear, :infinity)

  @doc "Put the display into deep sleep. Blocks until confirmed."
  @spec sleep(GenServer.server()) :: :ok | {:error, term()}
  def sleep(server), do: GenServer.call(server, :sleep, :infinity)

  @doc "Return the `%Papyrus.DisplaySpec{}` for this display."
  @spec spec(GenServer.server()) :: Papyrus.DisplaySpec.t()
  def spec(server), do: GenServer.call(server, :spec)

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl GenServer
  def init(opts) do
    display_module = Keyword.fetch!(opts, :display_module)
    display_spec = display_module.spec()

    port_path =
      Keyword.get(opts, :port_binary, port_binary_path())

    port =
      Port.open({:spawn_executable, port_path}, [
        :binary,
        :exit_status,
        :use_stdio
      ])

    state = %__MODULE__{port: port, spec: display_spec, pending_from: nil, buffer: <<>>}

    case send_command(state, :init) do
      {:ok, new_state} -> {:ok, new_state}
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:display, image}, from, %{spec: spec} = state) do
    expected = spec.buffer_size

    case byte_size(image) do
      ^expected ->
        send_async(state, from, :display, image)

      actual ->
        {:reply, {:error, {:bad_buffer_size, expected: expected, got: actual}}, state}
    end
  end

  def handle_call(:clear, from, state) do
    send_async(state, from, :clear)
  end

  def handle_call(:sleep, from, state) do
    send_async(state, from, :sleep)
  end

  def handle_call(:spec, _from, state) do
    {:reply, state.spec, state}
  end

  @impl GenServer
  def handle_info({port, {:data, chunk}}, %{port: port} = state) do
    new_buffer = state.buffer <> chunk

    case Protocol.decode_response(new_buffer) do
      :incomplete ->
        {:noreply, %{state | buffer: new_buffer}}

      result ->
        reply =
          case result do
            {:ok, _msg} -> :ok
            {:error, msg} -> {:error, msg}
          end

        if state.pending_from do
          GenServer.reply(state.pending_from, reply)
        end

        {:noreply, %{state | pending_from: nil, buffer: <<>>}}
    end
  end

  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    Logger.error("epd_port exited with status #{code}")

    if state.pending_from do
      GenServer.reply(state.pending_from, {:error, {:port_exited, code}})
    end

    {:stop, {:port_exited, code}, state}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp send_command(state, cmd, payload \\ <<>>) do
    request = Protocol.encode_request(cmd, payload)
    Port.command(state.port, request)

    receive do
      {port, {:data, data}} when port == state.port ->
        case Protocol.decode_response(data) do
          {:ok, _} -> {:ok, state}
          {:error, msg} -> {:error, msg}
          :incomplete -> {:error, :incomplete_response}
        end

      {port, {:exit_status, code}} when port == state.port ->
        {:error, {:port_exited, code}}
    after
      30_000 ->
        {:error, :timeout}
    end
  end

  defp send_async(state, from, cmd, payload \\ <<>>) do
    request = Protocol.encode_request(cmd, payload)
    Port.command(state.port, request)
    {:noreply, %{state | pending_from: from, buffer: <<>>}}
  end

  defp port_binary_path do
    :code.priv_dir(:papyrus)
    |> Path.join(@port_binary)
  end
end
