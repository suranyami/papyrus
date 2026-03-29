defmodule Papyrus.ProtocolTest do
  use ExUnit.Case, async: true
  alias Papyrus.Protocol

  describe "encode_request/2" do
    test "encodes :init with empty payload" do
      assert Protocol.encode_request(:init) == <<0x01, 0::32-big>>
    end

    test "encodes :display with payload" do
      payload = <<1, 2, 3, 4>>
      result = Protocol.encode_request(:display, payload)
      assert result == <<0x02, 4::32-big, 1, 2, 3, 4>>
    end

    test "encodes :clear with empty payload" do
      assert Protocol.encode_request(:clear) == <<0x03, 0::32-big>>
    end

    test "encodes :sleep with empty payload" do
      assert Protocol.encode_request(:sleep) == <<0x04, 0::32-big>>
    end

    test "encodes :display with large payload" do
      payload = :binary.copy(<<0xFF>>, 160_392)
      result = Protocol.encode_request(:display, payload)
      <<0x02, len::32-big, rest::binary>> = result
      assert len == 160_392
      assert byte_size(rest) == 160_392
    end
  end

  describe "decode_response/1" do
    test "decodes success with empty message" do
      assert Protocol.decode_response(<<0, 0::32-big>>) == {:ok, ""}
    end

    test "decodes success with message" do
      assert Protocol.decode_response(<<0, 2::32-big, "ok">>) == {:ok, "ok"}
    end

    test "decodes error with message" do
      assert Protocol.decode_response(<<1, 5::32-big, "error">>) == {:error, "error"}
    end

    test "returns :incomplete for partial data" do
      assert Protocol.decode_response(<<0, 0>>) == :incomplete
    end

    test "returns :incomplete for empty binary" do
      assert Protocol.decode_response(<<>>) == :incomplete
    end
  end
end
