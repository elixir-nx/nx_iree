# NxIREE

Companion library to [EXLA](https://github.com/elixir-nx/exla), providing bindings for the [IREE](https://iree.dev) runtime for MLIR.

MLIR modules can be obtained from Nx functions by calling `EXLA.to_mlir_module/2` on them.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `nx_iree` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nx_iree, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/nx_iree>.

