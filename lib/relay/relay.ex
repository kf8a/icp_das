defmodule IcpDas.Relay do
  @moduledoc """
  Low level command building for interface with ICP-DAS relays

  This creates and parses the command strings that are sent to the devices
  """
  use Bitwise
  require Logger

  @doc """
  Generate a string to energize the relay by passing a 1 as the second parameter
  ""
  def set(%{"module" => module, "relay" => relay}, 1) do
    set_dio(module, relay)
    |> command_string
  end

  @doc """
  Generate a string to De-energize the relay by passing a zero as the second parameter
  """
  def set(%{"module" => module, "relay" => relay}, 0) do
    clear_dio(module, relay)
    |> command_string
  end

  @doc """
  Generate a string to get the module status
  """
  def get_module_status(module) do
    Enum.join(["@", address(module)], "")
    |> command_string
  end

  def parse_module_status(raw_data) do
    parse(raw_data)
  end

  def firmware(module) do
    Enum.join(["$", address(module), "F"], "")
    |> command_string
  end

  def set_dio(module, dio) do
    Enum.join(["#", address(module), "1", Integer.to_string(dio), "01"], "")
  end

  def clear_dio(module, dio) do
    Enum.join(["#", address(module), "1", Integer.to_string(dio), "00"], "")
  end

  def address(module) do
    module
    |> Integer.to_string(16)
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

  def parse(<< "!",  address :: binary-size(2), data_and_cs :: binary >> = _cmd) do
    { data, check } = String.split_at(data_and_cs, -2)

    case checksum("@" <> address <> data) == check do
      true -> {:ok, data}
      _ -> {:invalid}
    end
  end

  def parse(<< "@", address :: binary-size(2), data_and_cs :: binary >> = _cmd) do
    { data, check } = String.split_at(data_and_cs, -2)

    case checksum("@" <> address <> data) == check do
      true -> {:ok, data}
      _ -> {:invalid}
    end
  end

  def parse(<< ">", data_and_cs :: binary >> = _cmd) do
    {data, check} = String.split_at(data_and_cs, -2)

    case checksum(">" <> data) == check do
      true -> {:ok, data}
      _ -> {:invalid}
    end
  end

  def parse(cmd) do
    Logger.error(["can't parse ", cmd])
  end
end
