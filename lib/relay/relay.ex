defmodule IcpDas.Relay do
  @moduledoc """
  Low level command building for interface with ICP-DAS relays

  This creates and parses the command strings that are sent to the devices
  """
  use Bitwise

  def get(module, relay) do

  end

  def set(%{"module"i => module, "relay" => relay}, 1) do
    set_dio(module, relay)
    |> command_string
  end

  def set(%{"module" => module, "relay" => relay}, 0) do
    clear_dio(module, relay)
    |> command_string
  end

  def get_module_status(module) do
    Enum.join(["$", address(module), "6"], "")
    |> command_string
  end


  def firmware(module) do
    Enum.join(["$", address(module), "F"], "")
    |> command_string
  end

  def set_dio(module, dio) do
    Enum.join(["#", address(module), "A", dio, "01"], "")
    # |> command_string
  end

  def clear_dio(module, dio) do
    Enum.join(["#", address(module), "A", dio, "00"], "")
    # |> command_string
  end


  def bitmask(dio) do
    bin =case dio do
      "1" -> 1
      "2" -> 2
      "3" -> 4
      "4" -> 8
    end
    Integer.to_string(bin,2)
    |> String.pad_leading(4, "0")
  end

  def address(module) do
    module
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
