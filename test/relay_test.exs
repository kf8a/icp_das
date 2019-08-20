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

  test "generate an on command for module 7 relay 0" do
    assert Relay.set_dio(7,0) == "#07A001"
  end

  test "generate an on command for module 6 relay 2" do
    assert Relay.set_dio(6,2) == "#06A201"
  end

  test "generate an off command for module 7 relay 0" do
    assert Relay.clear_dio(7,0) == "#07A000"
  end

  test "generate an off command for module 6 relay 2" do
    assert Relay.clear_dio(6,2) == "#06A200"
  end

  test "command to get firmware version of module 1" do
    assert Relay.firmware(1) == "$01FCB"
  end
end
