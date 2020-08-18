# IcpDas

Control ICP-DAS 78000 series relays. Based on the documentation in

http://ftp.icpdas.com/pub/cd/8000cd/napdos/7000/manual/7000dio.pdf


The implements two modules a GenServer that holds a serial port for
communicating with the modules (we use a serial to RS422 converter to talk to
the modules) and a module to generate the command strings to send to the
modules as well as parse the strings returned. The module assumes that checksums
on the ICP-DAS relays are enabled.

The GenServer expects to find a 'private/relay.toml' file to map the module/relay
nomenclature of the ICP-DAS modules to a number, so that relays can be addressed
using integers.

This library uses the `Circuits.Uart` library to handle the actual
communication.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `icp_das` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:icp_das, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/icp_das](https://hexdocs.pm/icp_das).

