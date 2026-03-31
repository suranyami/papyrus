defmodule Papyrus.DisplayTest do
  use ExUnit.Case

  alias Papyrus.Display
  alias Papyrus.MockPort
  alias Papyrus.Displays.Waveshare12in48

  # Display tests are NOT async — they open OS ports and must serialize.
  # Increase timeout for elixir script startup.
  @moduletag timeout: 30_000

  describe "start_link/1 with mock port (happy path)" do
    test "starts successfully with mock port" do
      {:ok, pid} =
        Display.start_link(
          display_module: Waveshare12in48,
          port_binary: MockPort.port_executable()
        )

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "spec/1 returns the display spec" do
      {:ok, pid} =
        Display.start_link(
          display_module: Waveshare12in48,
          port_binary: MockPort.port_executable()
        )

      spec = Display.spec(pid)
      assert spec.model == :waveshare_12in48
      assert spec.width == 1304
      GenServer.stop(pid)
    end
  end

  describe "commands with mock port (happy path)" do
    setup do
      {:ok, pid} =
        Display.start_link(
          display_module: Waveshare12in48,
          port_binary: MockPort.port_executable()
        )

      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, display: pid}
    end

    test "clear/1 returns :ok", %{display: pid} do
      assert Display.clear(pid) == :ok
    end

    test "sleep/1 returns :ok", %{display: pid} do
      assert Display.sleep(pid) == :ok
    end

    test "display/2 with correct buffer size returns :ok", %{display: pid} do
      spec = Display.spec(pid)
      # three_color needs 2x buffer_size (black plane + red plane)
      buffer = :binary.copy(<<0xFF>>, 2 * spec.buffer_size)
      assert Display.display(pid, buffer) == :ok
    end

    test "display/2 with wrong buffer size returns error", %{display: pid} do
      assert {:error, {:bad_buffer_size, _}} = Display.display(pid, <<1, 2, 3>>)
    end
  end

  describe "error-path commands with configurable mock (D-02)" do
    test "clear/1 returns error when mock is configured to fail on :clear" do
      responses = %{MockPort.command_byte(:clear) => {1, "hardware fault"}}
      response_file = MockPort.write_response_file(responses, "clear_error")
      mock_path = MockPort.port_executable(response_file)

      {:ok, pid} =
        Display.start_link(
          display_module: Waveshare12in48,
          port_binary: mock_path
        )

      # :init was not configured to fail, so start_link succeeds (default {:ok, ""})
      assert Process.alive?(pid)

      # :clear IS configured to fail
      result = Display.clear(pid)
      assert {:error, _reason} = result

      # GenServer stays alive after an error response — only port exit stops it
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "sleep/1 returns error when mock is configured to fail on :sleep" do
      responses = %{MockPort.command_byte(:sleep) => {1, "sleep denied"}}
      response_file = MockPort.write_response_file(responses, "sleep_error")
      mock_path = MockPort.port_executable(response_file)

      {:ok, pid} =
        Display.start_link(
          display_module: Waveshare12in48,
          port_binary: mock_path
        )

      assert Process.alive?(pid)

      result = Display.sleep(pid)
      assert {:error, _reason} = result

      # GenServer stays alive after an error response
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end
end
