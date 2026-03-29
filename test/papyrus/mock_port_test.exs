defmodule Papyrus.MockPortTest do
  use ExUnit.Case, async: true

  alias Papyrus.MockPort
  alias Papyrus.Protocol

  @moduletag timeout: 30_000

  describe "port_executable/0" do
    test "returns path to an existing executable file" do
      path = MockPort.port_executable()
      assert File.exists?(path), "Expected mock port wrapper to exist at #{path}"
      stat = File.stat!(path)
      # Check executable bit (owner execute)
      assert Bitwise.band(stat.mode, 0o100) != 0, "Expected #{path} to be executable"
    end
  end

  describe "write_response_file/2" do
    test "creates a file that exists on disk" do
      responses = %{0x03 => {1, "hw fault"}}
      path = MockPort.write_response_file(responses, "test_create")
      assert File.exists?(path)
      # Cleanup
      File.rm(path)
    end

    test "file contains valid Erlang term binary that round-trips" do
      responses = %{0x01 => {0, "ok"}, 0x03 => {1, "error msg"}}
      path = MockPort.write_response_file(responses, "test_roundtrip")
      data = File.read!(path)
      decoded = :erlang.binary_to_term(data)
      assert decoded == responses
      File.rm(path)
    end
  end

  describe "command_byte/1" do
    test "returns correct byte values" do
      assert MockPort.command_byte(:init) == 0x01
      assert MockPort.command_byte(:display) == 0x02
      assert MockPort.command_byte(:clear) == 0x03
      assert MockPort.command_byte(:sleep) == 0x04
    end
  end

  describe "mock port protocol - default responses" do
    setup do
      port =
        Port.open({:spawn_executable, MockPort.port_executable()}, [
          :binary,
          :exit_status,
          :use_stdio
        ])

      on_exit(fn ->
        if Port.info(port) != nil do
          Port.close(port)
        end
      end)

      {:ok, port: port}
    end

    test "responds to :init command with success (status=0)", %{port: port} do
      Port.command(port, Protocol.encode_request(:init))
      assert_receive {^port, {:data, data}}, 10_000
      assert Protocol.decode_response(data) == {:ok, ""}
    end

    test "responds to :clear command with success", %{port: port} do
      Port.command(port, Protocol.encode_request(:clear))
      assert_receive {^port, {:data, data}}, 10_000
      assert Protocol.decode_response(data) == {:ok, ""}
    end

    test "responds to :display command with payload with success", %{port: port} do
      payload = :binary.copy(<<0xFF>>, 100)
      Port.command(port, Protocol.encode_request(:display, payload))
      assert_receive {^port, {:data, data}}, 10_000
      assert Protocol.decode_response(data) == {:ok, ""}
    end

    test "responds to :sleep command with success", %{port: port} do
      Port.command(port, Protocol.encode_request(:sleep))
      assert_receive {^port, {:data, data}}, 10_000
      assert Protocol.decode_response(data) == {:ok, ""}
    end

    test "exits cleanly when port is closed (stdin EOF)", %{port: port} do
      ref = Port.monitor(port)
      Port.close(port)
      assert_receive {:DOWN, ^ref, :port, ^port, :normal}, 10_000
    end
  end

  describe "mock port protocol - configurable error responses" do
    test "returns error response for :clear when configured, :init still defaults to success" do
      responses = %{MockPort.command_byte(:clear) => {1, "hw fault"}}
      response_file = MockPort.write_response_file(responses, "clear_error_test")

      port =
        Port.open({:spawn_executable, MockPort.port_executable(response_file)}, [
          :binary,
          :exit_status,
          :use_stdio
        ])

      on_exit(fn ->
        if Port.info(port) != nil do
          Port.close(port)
        end

        File.rm(response_file)
      end)

      # :init should default to success (not in response map)
      Port.command(port, Protocol.encode_request(:init))
      assert_receive {^port, {:data, init_data}}, 10_000
      assert Protocol.decode_response(init_data) == {:ok, ""}

      # :clear should return the configured error
      Port.command(port, Protocol.encode_request(:clear))
      assert_receive {^port, {:data, clear_data}}, 10_000
      assert Protocol.decode_response(clear_data) == {:error, "hw fault"}
    end

    test "returns error response for :init when configured" do
      responses = %{MockPort.command_byte(:init) => {1, "init failed"}}
      response_file = MockPort.write_response_file(responses, "init_error_test")

      port =
        Port.open({:spawn_executable, MockPort.port_executable(response_file)}, [
          :binary,
          :exit_status,
          :use_stdio
        ])

      on_exit(fn ->
        if Port.info(port) != nil do
          Port.close(port)
        end

        File.rm(response_file)
      end)

      Port.command(port, Protocol.encode_request(:init))
      assert_receive {^port, {:data, data}}, 10_000
      assert Protocol.decode_response(data) == {:error, "init failed"}
    end
  end
end
