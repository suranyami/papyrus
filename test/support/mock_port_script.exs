# Mock port script that speaks the Papyrus binary protocol.
# Accepts optional arg: path to response config file (Erlang binary term).
# Config format: %{cmd_byte => {status_byte, message_binary}}
# Default: status=0 (ok), empty message for all commands.

defmodule MockPortMain do
  def run do
    responses = load_responses()
    loop(responses)
  end

  defp load_responses do
    case System.argv() do
      [path] when is_binary(path) ->
        case File.read(path) do
          {:ok, data} -> :erlang.binary_to_term(data)
          _ -> %{}
        end

      _ ->
        %{}
    end
  end

  defp loop(responses) do
    case read_bytes(5) do
      :eof ->
        System.halt(0)

      {:error, _} ->
        System.halt(0)

      <<cmd::8, len::32-big>> ->
        if len > 0 do
          case read_bytes(len) do
            :eof -> System.halt(0)
            {:error, _} -> System.halt(0)
            _payload -> :ok
          end
        end

        {status, msg} = Map.get(responses, cmd, {0, ""})
        msg_bin = if is_binary(msg), do: msg, else: to_string(msg)
        msg_len = byte_size(msg_bin)
        write_bytes(<<status::8, msg_len::32-big, msg_bin::binary>>)
        loop(responses)
    end
  end

  defp read_bytes(n) do
    case :file.read(:standard_io, n) do
      {:ok, data} when byte_size(data) == n -> data
      {:ok, _partial} -> :eof
      :eof -> :eof
      {:error, reason} -> {:error, reason}
    end
  end

  defp write_bytes(data) do
    :file.write(:standard_io, data)
  end
end

MockPortMain.run()
