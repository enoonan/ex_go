defmodule ExGoWeb.StripeWebhookController do
  use ExGoWeb, :controller

  def handle(conn, params) do
    payload = conn.assigns[:raw_body] |> List.first()
    signature = conn |> Plug.Conn.get_req_header("stripe-signature") |> List.first()
    secret = Application.get_env(:ex_go, :stripe_webhook_secret)

    start = System.monotonic_time(:millisecond)

    if StripeWebhook.verify_signature(payload, signature, secret) do
      duration = System.monotonic_time(:millisecond) - start
      params |> IO.inspect()
      IO.puts("VERIFIED in #{duration}ms")
    else
      duration = System.monotonic_time(:millisecond) - start
      IO.puts("NOT VERIFIED!!! :() - took #{duration}ms")
    end

    conn |> json(%{result: :ok})
  end
end
