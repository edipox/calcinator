# Calcinator

JSONAPI views shared between the API controllers and RPC servers.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `calcinator` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:calcinator, "~> 0.1.0"}]
    end
    ```

  2. Ensure `calcinator` is started before your application:

    ```elixir
    def application do
      [applications: [:calcinator]]
    end
    ```

