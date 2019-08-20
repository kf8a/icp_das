defmodule RelayTestdo do
  use ExUnit.Case
  doctest IcpDas.Relay

  alias IcpDas.Relay

  test "assemble a command" do
    assert Relay.command_string("$012") == "$012B7"
    assert Relay.command_string("$010001") == "$01000146"
    assert Relay.command_string("$010000") == "$01000045"
  end

  test "generate correct bitmask for dio channel" do
    assert Relay.bitmask(1) == "0001"
    assert Relay.bitmask(2) == "0010"
    assert Relay.bitmask(3) == "0100"
    assert Relay.bitmask(4) == "1000"
  end

  test "generates an on command for module 1 DO 1" do
    assert Relay.set(1,1) == "$01000146"
  end

  test "generates an off command for module 1 DO 1" do
    assert Relay.set(1,0) == "$01000045"
  end

  test "command to get firmware version of module 1" do
    assert Relay.firmware(1) == "$01FCB"
  end
end
