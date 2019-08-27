defmodule IcpDas do
  @moduledoc """
  Interface with ICP-DAS relays

  """

  alias IcpDas.Relay
  use GenServer
  use Bitwise

  def start_link() do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    {:ok, uart} = Circuits.UART.start_link
    {:ok, %{uart: uart}, {:continue, :load_relay_mapping}}
  end

  def on(pid, relay) do
    GenServer.cast(pid, {:on, relay})
  end

  def off(pid, relay) do
    GenServer.cast(pid, {:off, relay})
  end

  def state(pid, relay) do
    GenServer.call(pid, {:state, relay})
  end

  def lookup(relay, relays) do
    Map.fetch(relays,relay)
  end


  def write_serial(cmd, pid) do
    Circuits.UART.write(pid, cmd)
  end

  def read_serial(pid) do
    Circuits.UART.read(pid)
  end

  def handle_continue(:load_relay_mapping, state) do
    {:ok, data} = File.read(Path.join(:code.priv_dir(:icp_das), "relay.toml"))
    {:ok, relays} = Toml.decode(data)
    Circuits.UART.open(state[:uart], "ttyUSB0", speed: 9600, active: false, framing: {Circuits.UART.Framing.Line, separator: "\r"})
    {:noreply, Map.merge(state, relays)}
  end

  def handle_cast({:on, relay}, state) do
    case lookup(relay, state["relay"]) do
      {:ok, relays} ->
        relays
        |> Relay.set(1)
        |> write_serial(state[:uart])

        {:ok, data} = read_serial(state[:uart])
        IO.inspect Relay.parse(data)
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

        {:ok, data} = read_serial(state[:uart])
        IO.inspect Relay.parse(data)
      _ -> {:error}
    end

    {:noreply, state}
  end

  def binmask(dio) do
    case dio do
      0 -> 0
      1 -> 1
      2 -> 2
      3 -> 4
      4 -> 8
    end
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
end
