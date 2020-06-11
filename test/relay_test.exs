defmodule RelayTestdo do
  use ExUnit.Case
  doctest IcpDas.Relay

  alias IcpDas.Relay

  test "assemble a command" do
    assert Relay.command_string("$012") == "$012B7"
    assert Relay.command_string("$010001") == "$01000146"
    assert Relay.command_string("$010000") == "$01000045"
  end

  test "generate an on command for module 7 relay 0" do
    assert Relay.set_dio(7,0) == "#071001"
  end

  test "generate an on command for module 6 relay 2" do
    assert Relay.set_dio(6,2) == "#061201"
  end

  test "generate an off command for module 7 relay 0" do
    assert Relay.clear_dio(7,0) == "#071000"
  end

  test "generate an off command for module 6 relay 2" do
    assert Relay.clear_dio(6,2) == "#061200"
  end

  test "command to get firmware version of module 1" do
    assert Relay.firmware(1) == "$01FCB"
  end
end
