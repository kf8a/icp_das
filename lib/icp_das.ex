defmodule IcpDas do
  @moduledoc """
  Interface with ICP-DAS relays.

  Provides a way to address a series of ICP-DAS modules. It expects to recieve a serial port on startup that is used
  to communicate with the ICP-DAS modules. This module uses the `Circuits.Uart` library to do the low level communication.

  Uses the `/private/relay.toml` file to provide the mapping between the ICP-DAS module/relay nomenclature and
  an integer, to make it simpler to address multiple ICP-DAS modules.

  """

  require Logger

  alias IcpDas.Relay
  use GenServer
  use Bitwise

  @doc """
  Start the GenServer by passing in a port that will be used to communicate with the ICP-DAS modules.

  Returns:  `{:ok, pid}`

  ## Examples

      iex> {:ok, pid} = IcpDas.start_link('/dev/ttyUSB0')
      {:ok, pid}

  """
  def start_link(port) do
    GenServer.start_link(__MODULE__, %{port: port}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, uart} = Circuits.UART.start_link
    {:ok, %{uart: uart, port: state[:port]}, {:continue, :load_relay_mapping}}
  end

  @doc """
  Returns a specification to start the module under a supervisor. The initial argument is the port
  used to communicate with the ICP-DAS modules
  """
  def child_spec(port) do
  %{
    id: IcpDas,
    start: {IcpDas, :start_link, [port]}
  }
  end


  @doc """
  Turn on a relay numbered `relay`

  Returns: `:ok`

  ## Examples

      iex> IcpDas.on(pid, 1)
      :ok

  """
  def on(pid, relay) do
    relay_string = normalize_relay(relay)

    GenServer.cast(pid, {:on, relay_string})
  end

  @doc """
  Turn off a relay numbered `relay`

  ## Examples

        iex> IcpDas.off(pid, 1)
        :ok

  """
  def off(pid, relay) do
    relay_string = normalize_relay(relay)

    GenServer.cast(pid, {:off, relay_string})
  end

  @doc """
  Returns the on or off state of relay `relay`

  ## Examples

        iex> IcpDas(pid, 1)
        {:ok, :on}

  """
  def state(pid, relay) do
    relay_string = normalize_relay(relay)

    GenServer.call(pid, {:state, relay_string})
  end

  @doc """
  List the configured relay mapping that was defined in `private/relay.toml`
  """
  def list_relays(pid) do
    GenServer.call(pid, :list_relays)
  end


  defp write_raw(pid, cmd) do
    GenServer.cast(pid, {:raw_write, cmd})
  end

  defp read_module_init(pid) do
    GenServer.call(pid, :read_module_init)
  end

  defp lookup(relay, relays) do
    Map.fetch(relays,relay)
  end

  defp normalize_relay(relay) when is_integer(relay), do: to_string(relay)
  defp normalize_relay(relay),  do: relay

  @impl true
  def handle_continue(:load_relay_mapping, state) do
    {:ok, data} = File.read(Path.join(:code.priv_dir(:icp_das), "relay.toml"))
    {:ok, relays} = Toml.decode(data)
    Circuits.UART.open(state[:uart], state[:port], speed: 9600, active: false, framing: {Circuits.UART.Framing.Line, separator: "\r"})
    {:noreply, Map.merge(state, relays)}
  end

  @impl true
  def handle_cast({:on, relay}, state) do
    case lookup(relay, state["relay"]) do
      {:ok, relays} ->
        relays
        |> Relay.set(1)
        |> write_serial(state[:uart])

        {:ok, _data} = read_serial(state[:uart])
      _ ->
        Logger.error "icp_das: unknown relay #{relay}"
        {:error}
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:off, relay}, state) do
    case lookup(relay, state["relay"]) do
      {:ok, relays} ->
        relays
        |> Relay.set(0)
        |> write_serial(state[:uart])

        {:ok, _data} = read_serial(state[:uart])
      _ ->
        Logger.error "icp_das: unknown relay #{relay}"
        {:error}
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:raw_write, cmd}, state) do
    write_serial(cmd, state[:uart])
    IO.inspect read_serial(state[:uart])
    {:noreply, state}
  end

  @impl true
  def handle_call(:read_module_init, _from, state) do
    write_serial("$002", state[:uart])
    {:ok, data } = read_serial(state[:uart])
    IO.inspect data
  end

  @impl true
  def handle_call({:state, relay}, _from, state) do
    result = case lookup(relay, state["relay"]) do
      {:ok, relay_tuple} ->
          %{"module" => module, "relay" => dio} = relay_tuple
          Relay.get_module_status(module)
          |> write_serial(state[:uart])

        {:ok, data} = read_serial(state[:uart])
        case Relay.parse(data) do
          {:ok, datum} ->
            {:ok, << first, _second >> }  = Base.decode16(datum)

            case band(first, 1 <<< dio) do
              0 -> :off
              _ -> :on
            end
          {:invalid} ->
              Logger.error "icp_das: Relay parse failure #{inspect data}"
              {:error}
        end
      _ ->
        Logger.error "icp_das: unknown relay #{relay}"
        {:error}
    end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:list_relays, _from, state) do
    {:reply, Map.keys(state["relay"]), state}
  end

  defp write_serial(cmd, pid) do
    Circuits.UART.write(pid, cmd)
  end

  defp read_serial(pid) do
    Circuits.UART.read(pid)
  end
end
