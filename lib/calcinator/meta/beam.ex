defmodule Calcinator.Meta.Beam do
  @moduledoc """
  Stores and extracts BEAM metadata from JSONAPI meta.
  """

  # CONSTANTS

  @version :v1

  # Functions

  @doc """
  Decodes the repo and owner process for the connection.
  """
  @spec decode(String.t) :: map | no_return
  def decode(encoded) do
    # See https://github.com/phoenixframework/phoenix_ecto/blob/90ba79feef55e31573047f789b3561f4ab7f30f6/lib/
    #   phoenix_ecto/sql/sandbox.ex#L73-L79
    encoded
    |> Base.url_decode64!
    |> :erlang.binary_to_term
    |> case do
      {@version, map} when is_map(map) -> map
      _ -> %{}
    end
  end

  @doc """
  Encodes and versions the repo and current process, so it can be used for the connection ownership
  """
  @spec encode([module, ...] | module) :: String.t
  def encode(repo) do
    repo
    |> versioned
    |> :erlang.term_to_binary
    |> Base.url_encode64
  end

  @spec get(map) :: map
  def get(meta) do
    case Map.fetch(meta, :beam) do
      {:ok, beam} -> decode(beam)
      :error -> %{}
    end
  end

  @doc """
  `repo` and owner process in a versioned format
  """
  @spec versioned([module] | module) :: {unquote(@version), map}
  def versioned(repo) do
    {@version, Interpreter.Sandbox.version1_token(repo)}
  end

  @doc """
  Puts BEAM metadata into `meta`
  """
  @spec put(map, [module, ...] | module) :: map
  def put(meta, repo), do: Map.put(meta, :beam, encode(repo))
end
