defmodule IcpDas.Relay do
  use Bitwise

  def set(relay, state) do
  end

  def get(relay) do
  end

  def checksum(string) do
    string
    |> String.to_charlist
    |> Enum.sum
    |> Bitwise.band(255)
    |> Integer.to_string(16)
  end

  def command_string(address, cmd) do
    total = Enum.join([address, cmd], "")

    chk = checksum(total)
    Enum.join([total, chk,  "\r"], "")
  end

  def parse(<< "!",  address :: binary-size(2), data :: binary >> = cmd) do
    IO.inspect data
  end

  def parse(<< "@", address :: binary-size(2), data_and_cs :: binary >> = cmd) do
    {data, checksum } = String.split_at(data_and_cs, -2)

    IO.inspect data

  end
end
