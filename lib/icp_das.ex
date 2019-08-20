defmodule IcpDas do
  @moduledoc """
  Documentation for IcpDas.
  """

  alias IcpDas.Relay

  def on(relay) do
    Relay.set(relay, 1)
  end

  def off(relay) do
    Relay.set(relay, 0)
  end

  def state(relay) do
    Relay.get(relay)
  end

end
