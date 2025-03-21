defmodule IcpDas do
  @moduledoc """
  Interface with ICP-DAS relays.

  Provides a way to address a series of ICP-DAS modules. It expects to recieve a
  the serial_number of a usb serial port on startup that is used
  to communicate with the ICP-DAS modules.
  This module uses the `Circuits.Uart` library to do the low level communication.

  Uses the `/private/relay.toml` file to provide the mapping
  between the ICP-DAS module/relay nomenclature and
  an integer, to make it simpler to address multiple ICP-DAS modules.

  The format of the `relay.toml` file is:

  ```toml
  [relay]

    [relay.1]
    module = 8
    relay = 0

    [relay.2]
    module = 2
    relay = 0
  ```

  """

  require Logger

  alias IcpDas.Relay
  use GenServer
  import Bitwise

  @doc """
  Start the GenServer by passing in a port that will be used to communicate with the ICP-DAS modules.

  Returns:  `{:ok, pid}`

  ## Examples

      iex> {:ok, pid} = IcpDas.start_link("serial_number")
      {:ok, pid}

  """
  def start_link(serial_number) do
    GenServer.start_link(__MODULE__, %{serial_number: serial_number}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, uart} = Circuits.UART.start_link()

    {port, _} =
      Circuits.UART.enumerate()
      |> find_port(state[:serial_number])

    new_state =
      state
      |> Map.put(:uart, uart)
      |> Map.put(:request, :none)
      |> Map.put(:port, port)

    {:ok, new_state, {:continue, :load_relay_mapping}}
  end

  defp find_port(ports, serial_number) do
    Enum.find(ports, {"ICP_PORT", ""}, fn {_port, value} ->
      correct_port?(value, serial_number)
    end)
  end

  defp correct_port?(%{serial_number: number}, serial) do
    number == serial
  end

  defp correct_port?(%{}, _serial) do
    false
  end

  @doc """
  Returns a specification to start the module under a supervisor. The initial argument is the port
  used to communicate with the ICP-DAS modules
  """
  def child_spec(port) do
    %{
      id: IcpDas,
      start: {IcpDas, :start_link, [port]}
    }
  end

  @doc """
  Turn on a relay numbered `relay`

  Returns: `:ok`

  ## Examples

      # iex> {:ok, pid} = IcpDas.start_link("serial_number")
      # iex> IcpDas.on(pid, 1)
      # :ok

  """
  def on(pid, relay) do
    relay_string = normalize_relay(relay)

    GenServer.cast(pid, {:on, relay_string})
  end

  @doc ~S"""
  Turn off a relay numbered `relay`
  """
  def off(pid, relay) do
    relay_string = normalize_relay(relay)

    GenServer.cast(pid, {:off, relay_string})
  end

  @doc ~S"""
  Returns the on or off state of relay `relay`
  """
  def state(pid, relay) do
    relay_string = normalize_relay(relay)

    GenServer.call(pid, {:state, relay_string})
  end

  @doc """
  List the configured relay mapping that was defined in `private/relay.toml`
  """
  def list_relays(pid) do
    GenServer.call(pid, :list_relays)
  end

  defp write_raw(pid, cmd) do
    GenServer.cast(pid, {:raw_write, cmd})
  end

  defp read_module_init(pid) do
    GenServer.call(pid, :read_module_init)
  end

  defp lookup(relay, relays) do
    Map.fetch(relays, relay)
  end

  defp normalize_relay(relay) when is_integer(relay), do: to_string(relay)
  defp normalize_relay(relay), do: relay

  @impl true
  def handle_continue(:load_relay_mapping, state) do
    {:ok, data} = File.read(Path.join(:code.priv_dir(:icp_das), "relay.toml"))
    {:ok, relays} = Toml.decode(data)

    Circuits.UART.open(state[:uart], state[:port],
      speed: 9600,
      active: false,
      framing: {Circuits.UART.Framing.Line, separator: "\r"}
    )

    {:noreply, Map.merge(state, relays)}
  end

  @impl true
  def handle_cast({:on, relay}, state) do
    new_state =
      case lookup(relay, state["relay"]) do
        {:ok, relays} ->
          relays
          |> Relay.set(1)
          |> write_serial(state[:uart])

          :telemetry.execute([:relay, :on], %{relay: relay, timestamp: DateTime.utc_now()})

          case read_serial(state[:uart], "on") do
            # TODO push error handling up,
            {:error, _msg} ->
              Process.send_after(self(), :reconnect, 100)
              Map.put(state, :request, {:on, relay})

            _ ->
              state
          end

        _ ->
          Logger.error("icp_das: unknown relay #{relay}")
          state
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:off, relay}, state) do
    new_state =
      case lookup(relay, state["relay"]) do
        {:ok, relays} ->
          relays
          |> Relay.set(0)
          |> write_serial(state[:uart])

          :telemetry.execute([:relay, :off], %{relay: relay, timestamp: DateTime.utc_now()})

          case read_serial(state[:uart], "off") do
            {:error, _msg} ->
              # TODO: when to try to reconnect
              Process.send_after(self(), :reconnect, 100)
              Map.put(state, :request, {:off, relay})

            _ ->
              state
          end

        _ ->
          Logger.error("icp_das: unknown relay #{relay}")
          state
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:raw_write, cmd}, state) do
    write_serial(cmd, state[:uart])
    {:noreply, state}
  end

  def handle_cast(:reconnect, state) do
    :ok = Circuits.UART.close(state[:uart])

    new_state =
      case Circuits.UART.open(state[:uart], state[:port],
             speed: 9600,
             active: false,
             framing: {Circuits.UART.Framing.Line, separator: "\r"}
           ) do
        :ok ->
          # re cast the original data request that failed
          case state[:request] do
            :none ->
              :telemetry.execute([:relay, :reconnect], %{timestamp: DateTime.utc_now()})
              state

            _ ->
              Process.send_after(self(), state[:request], 200)
              Map.put(state, :request, :none)
          end

        {:error, msg} ->
          Logger.error("icp_das: reconnect error: #{inspect(msg)}")
          Process.send_after(self(), :reconnect, 100)
          state
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:read_module_init, _from, state) do
    write_serial("$002", state[:uart])
    result = read_serial(state[:uart], "init")
    {:reply, result, state}
  end

  @impl true
  def handle_call({:state, relay}, _from, state) do
    result =
      case lookup(relay, state["relay"]) do
        {:ok, relay_tuple} ->
          %{"module" => module, "relay" => dio} = relay_tuple

          Relay.get_module_status(module)
          |> write_serial(state[:uart])

          :telemetry.execute([:relay, :check_state], %{
            timestamp: DateTime.utc_now(),
            relay: relay,
            module: module,
            dio: dio
          })

          data = read_serial(state[:uart], "state")

          :telemetry.execute([:relay, :state], %{
            timestamp: DateTime.utc_now(),
            relay: relay,
            module: module,
            dio: dio,
            data: data
          })

          parse(data, dio)

        _ ->
          Logger.error("icp_das: unknown relay #{relay}")
          {:error, "icp_das: unknown relay #{relay}"}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:list_relays, _from, state) do
    {:reply, Map.keys(state["relay"]), state}
  end

  defp write_serial(cmd, pid) do
    Circuits.UART.write(pid, cmd)
  end

  defp read_serial(pid, operation_name) do
    case Circuits.UART.read(pid, 1000) do
      {:ok, datum} ->
        datum

      {:error, msg} ->
        Logger.error("icp_das #{operation_name}: connection error #{inspect(msg)}")
        # Process.send_after(self(), :reconnect, 100)
        {:error, "icp_das #{operation_name}: connection error #{inspect(msg)}"}
    end
  end

  defp parse(data, dio) do
    case Relay.parse(data) do
      {:ok, datum} ->
        {:ok, <<first, _second>>} = Base.decode16(datum)

        case band(first, 1 <<< dio) do
          0 -> :off
          _ -> :on
        end

      :invalid ->
        Logger.error("icp_das: Relay parse failure #{inspect(data)}")
        {:error, "icp_das: Relay parse failure #{inspect(data)}"}
    end
  end
end
