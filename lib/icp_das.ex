defmodule IcpDas do
  @moduledoc """
  Interface with ICP-DAS relays

  """

  alias IcpDas.Relay
  use GenServer
  use Bitwise

  def start_link(port) do
    GenServer.start_link(__MODULE__, %{port: port}, name: __MODULE__)
  end

  def init(state) do
    {:ok, uart} = Circuits.UART.start_link
    {:ok, %{uart: uart, port: state[:port]}, {:continue, :load_relay_mapping}}
  end

  @doc """
  Turn on a relay
  """
  def on(pid, relay) do
    relay_string = normalize_relay(relay)

    GenServer.cast(pid, {:on, relay_string})
  end

  @doc """
  Turn off a relay
  """
  def off(pid, relay) do
    relay_string = normalize_relay(relay)

    GenServer.cast(pid, {:off, relay_string})
  end

  @doc """
  Returns the state of a relay
  """
  def state(pid, relay) do
    relay_string = normalize_relay(relay)

    GenServer.call(pid, {:state, relay_string})
  end

  @doc """
  List the configured relays
  """
  def list_relays(pid) do
    GenServer.call(pid, :list_relays)
  end

  def write_raw(pid, cmd) do
    GenServer.cast(pid, {:raw_write, cmd})
  end

  def read_module_init(pid) do
    GenServer.call(pid, :read_module_init)
  end

  defp lookup(relay, relays) do
    Map.fetch(relays,relay)
  end

  defp normalize_relay(relay) when is_integer(relay), do: to_string(relay)
  defp normalize_relay(relay),  do: relay

  def handle_continue(:load_relay_mapping, state) do
    {:ok, data} = File.read(Path.join(:code.priv_dir(:icp_das), "relay.toml"))
    {:ok, relays} = Toml.decode(data)
    Circuits.UART.open(state[:uart], state[:port], speed: 9600, active: false, framing: {Circuits.UART.Framing.Line, separator: "\r"})
    {:noreply, Map.merge(state, relays)}
  end

  def handle_cast({:on, relay}, state) do
    case lookup(relay, state["relay"]) do
      {:ok, relays} ->
        relays
        |> Relay.set(1)
        |> write_serial(state[:uart])

        {:ok, _data} = read_serial(state[:uart])
      _ -> {:error}
    end

    {:noreply, state}
  end

  def handle_cast({:off, relay}, state) do
    case lookup(relay, state["relay"]) do
      {:ok, relays} ->
        relays
        |> Relay.set(0)
        |> write_serial(state[:uart])

        {:ok, _data} = read_serial(state[:uart])
      _ -> {:error}
    end

    {:noreply, state}
  end

  def handle_cast({:raw_write, cmd}, state) do
    write_serial(cmd, state[:uart])
    IO.inspect read_serial(state[:uart])
    {:noreply, state}
  end

  def handle_call(:read_module_init, _from, state) do
    write_serial("$002", state[:uart])
    {:ok, data } = read_serial(state[:uart])
    IO.inspect data
  end

  def handle_call({:state, relay}, _from, state) do
    result = case lookup(relay, state["relay"]) do
      {:ok, relay_tuple} ->
          %{"module" => module, "relay" => dio} = relay_tuple
          Relay.get_module_status(module)
          |> write_serial(state[:uart])

        {:ok, data} = read_serial(state[:uart])
        {:ok, datum} = Relay.parse(data)
        {:ok, << first, _second >> }  = Base.decode16(datum)

        case band(first, 1 <<< dio) do
          0 -> :off
          _ -> :on
        end
      _ -> {:error}
    end

    {:reply, result, state}
  end

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
