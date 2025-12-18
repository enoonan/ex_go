defmodule GoRunner do
  @moduledoc """
  Utility module for calling Go binary commands.
  """

  @doc """
  Sends a command to the Go binary and returns the result.

  ## Examples

      iex> GoRunner.send_command("hello")
      {:ok, %{"message" => "Hello from Go!"}}

      iex> GoRunner.send_command("new_customer", %{email: "test@example.com"})
      {:ok, %{"id" => "cus_123", ...}}
  """
  def send_command(command, data \\ %{}) do
    binary_path = Application.app_dir(:ex_go, "priv/bin/main")
    api_key = Application.get_env(:ex_go, :stripe_secret)
    json_data = Jason.encode!(data)

    case System.cmd(binary_path, [api_key, command, json_data], stderr_to_stdout: true) do
      {output, 0} ->
        parse_success(output)

      {error_output, _code} ->
        parse_error(error_output)
    end
  end

  defp parse_success(output) do
    case Jason.decode(output) do
      {:ok, %{"ok" => result}} ->
        case result do
          result when is_binary(result) ->
            case Jason.decode(result) do
              {:ok, decoded} -> {:ok, decoded}
              {:error, _} -> {:ok, result}
            end

          result when is_map(result) ->
            {:ok, result}
        end

      {:ok, %{"error" => error}} ->
        {:error, error}

      {:error, decode_error} ->
        {:error, "Failed to decode response: #{inspect(decode_error)}"}
    end
  end

  defp parse_error(output) do
    case Jason.decode(output) do
      {:ok, %{"error" => error}} -> {:error, error}
      _ -> {:error, "Command failed: #{output}"}
    end
  end
end
