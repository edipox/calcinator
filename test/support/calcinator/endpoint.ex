defmodule Calcinator.Endpoint do
  @moduledoc """
  `Phoenix.Endpoint` for `Calcinator.PryIn.InstrumenterTest`
  """

  use Phoenix.Endpoint, otp_app: :calcinator

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison,
    length: 25_000_000 # 25 MB

  plug Plug.MethodOverride
  plug Plug.Head

  plug PryIn.Plug
  plug Calcinator.Router
end
