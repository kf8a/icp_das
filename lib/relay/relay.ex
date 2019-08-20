defmodule IcpDas.Relay do
  use Bitwise

  def set(relay, state) do
    # look up module relay
    # get current relay status
    # OR the bitmask for the relay
    # send the command
    # check for reply
  end

  def get(relay) do
  end

  def get_module_status(module) do
    module_string = String.pad_leading(module, 2, "0")
    Enum.join(["$", module_string, "6"], "")
  end

  def bitmask(dio) do
    bin =case dio do
      1 -> 1
      2 -> 2
      3 -> 4
      4 -> 8
    end
    Integer.to_string(bin,2)
    |> String.pad_leading(4, "0")
  end

  def checksum(string) do
    string
    |> String.to_charlist
    |> Enum.sum
    |> Bitwise.band(255)
    |> Integer.to_string(16)
  end

  def command_string(cmd) do
    chk = checksum(cmd)
    Enum.join([cmd, chk], "")
  end

  def parse(<< "!",  address :: binary-size(2), data :: binary >> = cmd) do
    IO.inspect data
  end

  def parse(<< "@", address :: binary-size(2), data_and_cs :: binary >> = cmd) do
    {data, checksum } = String.split_at(data_and_cs, -2)

    IO.inspect data

  end
end
