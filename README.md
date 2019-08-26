# IcpDas

Control ICP-DAS 78000 series relays. Only implements setting relays at this
point, reading the current state is planned.

http://ftp.icpdas.com/pub/cd/8000cd/napdos/7000/manual/7000dio.pdf

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

