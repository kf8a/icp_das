defmodule IcpDas.Relay do
  use Bitwise

  def set(relay, state) do
    # look up module relay
    # set_dio(module, dio)
    # |> command_string
    # |> send()
    # check for reply
  end

  def get(relay) do

  end

  def get_module_status(module) do
    Enum.join(["$", address(module), "6"], "")
    |> command_string
  end

  def send(cmd) do

  end

  def firmware(module) do
    Enum.join(["$", address(module), "F"], "")
    |> command_string
  end

  # iex(38)> Circuits.UART.write(pid, Relay.command_string("#07A000"))
  # iex(39)> Circuits.UART.write(pid, Relay.command_string("#08A001"))
  def set_dio(module, dio) do
    Enum.join(["#", address(module), "A", Integer.to_string(dio), "01"], "")
    # |> command_string
  end

  def clear_dio(module, dio) do
    Enum.join(["#", address(module), "A", Integer.to_string(dio), "00"], "")
    # |> command_string
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

  def address(module) do
    module
    |> Integer.to_string
    |> String.pad_leading(2, "0")
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
