defmodule StripeWebhook do
  def verify_signature(payload, signature_header, secret) do
    # Parse the signature header
    %{"t" => timestamp, "v1" => expected_signature} =
      parse_signature_header(signature_header)

    # Compute what the signature should be
    signed_payload = "#{timestamp}.#{payload}"

    computed_signature =
      :crypto.mac(:hmac, :sha256, secret, signed_payload)
      |> Base.encode16(case: :lower)

    # Constant-time comparison
    Plug.Crypto.secure_compare(computed_signature, expected_signature)
  end

  defp parse_signature_header(header) do
    header
    |> String.split(",")
    |> Enum.map(fn pair ->
      [key, value] = String.split(pair, "=", parts: 2)
      {key, value}
    end)
    |> Map.new()
  end
end
