defmodule IcpDas do
  @moduledoc """
  Interface with ICP-DAS relays

  """

  alias IcpDas.Relay
  use GenServer

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

  def state(relay) do
    {1,2} |> Relay.get(relay)
  end

  def lookup(relay, relays) do
    relays[relay]
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
    {:noreply, Map.merge(state, relays)}
  end

  def handle_cast({:on, relay}, state) do
    lookup(relay, state["relay"])
    |> Relay.set(1)
    |> write_serial(state[:uart])

    {:noreply, state}
  end

  def handle_cast({:off, relay}, state) do
    lookup(relay, state["relay"])
    |> Relay.set(0)
    |> write_serial(state[:uart])
    {:noreply, state}
  end
end
