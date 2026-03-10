defmodule Papyrus.Protocol do
  @moduledoc """
  Binary encode/decode for the Papyrus port protocol.

  ## Wire format

  **Request** (Elixir → C port):

      [1 byte: cmd] [4 bytes: payload_len big-endian uint32] [payload_len bytes]

  **Response** (C port → Elixir):

      [1 byte: status — 0=ok, 1=error] [4 bytes: msg_len big-endian uint32] [msg_len bytes]

  ## Commands

  | Byte | Atom       | Payload                    |
  |------|------------|----------------------------|
  | 0x01 | `:init`    | empty                      |
  | 0x02 | `:display` | 160,392-byte image buffer  |
  | 0x03 | `:clear`   | empty                      |
  | 0x04 | `:sleep`   | empty                      |
  """

  @cmd_init 0x01
  @cmd_display 0x02
  @cmd_clear 0x03
  @cmd_sleep 0x04

  @type command :: :init | :display | :clear | :sleep
  @type decode_result :: {:ok, binary()} | {:error, binary()} | :incomplete

  @doc "Encode a command + payload into a length-prefixed binary."
  @spec encode_request(command(), binary()) :: binary()
  def encode_request(cmd, payload \\ <<>>) do
    byte = cmd_byte(cmd)
    len = byte_size(payload)
    <<byte::8, len::32-big, payload::binary>>
  end

  @doc """
  Decode a response from the port.

  Returns `{:ok, msg}`, `{:error, msg}`, or `:incomplete` if not enough
  bytes have arrived yet.
  """
  @spec decode_response(binary()) :: decode_result()
  def decode_response(<<status::8, len::32-big, msg::binary-size(len)>>) do
    case status do
      0 -> {:ok, msg}
      _ -> {:error, msg}
    end
  end

  def decode_response(_incomplete), do: :incomplete

  defp cmd_byte(:init), do: @cmd_init
  defp cmd_byte(:display), do: @cmd_display
  defp cmd_byte(:clear), do: @cmd_clear
  defp cmd_byte(:sleep), do: @cmd_sleep
end
