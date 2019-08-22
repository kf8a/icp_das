defmodule IcpDas do
  @moduledoc """
  Documentation for IcpDas.
  """

  alias IcpDas.Relay
  use GenServer

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

  defp lookup(_relay) do
    {1,2}
  end

  def write_serial(cmd, pid) do
    Circuits.UART.write(pid, cmd)
  end

  def read_serial(pid) do
    Circuits.UART.read(pid)
  end

  def handle_call(:load_relay_mapping, state) do
    {:ok, data} = File.read("relay.yml")
    {:ok, relays} = Toml.decode(data)
    {:noreply, Map.merge(state, relays["relay"])}
  end

  def handle_cast({:on, relay}, state) do
    lookup(relay)
    |> Relay.set(1)
    |> write_serial(state[:uart])
    {:noreply, state}
  end

  def handle_cast({:off, relay}, state) do
    lookup(relay)
    |> Relay.set(0)
    |> write_serial(state[:uart])
    {:noreply, state}
  end
end
