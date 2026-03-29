defmodule Papyrus.MockPort do
  @moduledoc """
  Provides helpers for the mock port used in testing.

  The mock port is an Elixir script that speaks the Papyrus
  length-prefixed binary protocol over stdin/stdout. It responds
  with `{:ok, ""}` to every command by default.

  ## Configuring responses per-test (D-02)

  To test error paths, create a response file that maps command bytes
  to `{status, message}` tuples:

      responses = %{0x03 => {1, "hardware fault"}}  # :clear returns error
      path = Papyrus.MockPort.write_response_file(responses, "my_test")
      {:ok, pid} = Papyrus.Display.start_link(
        display_module: MyDisplay,
        port_binary: Papyrus.MockPort.port_executable(path)
      )

  ## Default usage

      {:ok, pid} = Papyrus.Display.start_link(
        display_module: MyDisplay,
        port_binary: Papyrus.MockPort.port_executable()
      )
  """

  @doc """
  Return the path to the wrapper shell script (no response config).

  The mock will return `{:ok, ""}` for every command.
  """
  @spec port_executable() :: String.t()
  def port_executable do
    wrapper_path()
  end

  @doc """
  Return a path to a per-invocation wrapper script that passes the
  response file path as an argument to the mock port script.

  Since `Papyrus.Display` uses `Port.open({:spawn_executable, path}, ...)`
  without args support, the response file path is baked into a
  per-invocation wrapper script written to the system temp directory.
  """
  @spec port_executable(String.t()) :: String.t()
  def port_executable(response_file_path) do
    tmp_dir = System.tmp_dir!()
    hash = :erlang.phash2(response_file_path, 1_000_000)
    tmp_wrapper = Path.join(tmp_dir, "papyrus_mock_#{hash}.sh")
    script_path = mock_script_path()

    File.write!(tmp_wrapper, """
    #!/bin/sh
    exec elixir "#{script_path}" "#{response_file_path}"
    """)

    File.chmod!(tmp_wrapper, 0o755)
    tmp_wrapper
  end

  @doc """
  Write a response configuration file for the mock port.

  `responses` is a map of `%{cmd_byte => {status_byte, message_binary}}`.
  Command bytes: 0x01 = :init, 0x02 = :display, 0x03 = :clear, 0x04 = :sleep.

  Returns the path to the written file.

  ## Example

      responses = %{0x03 => {1, "clear failed"}}
      path = MockPort.write_response_file(responses, "my_test")
  """
  @spec write_response_file(map(), String.t()) :: String.t()
  def write_response_file(responses, label \\ "test") when is_map(responses) do
    tmp_dir = System.tmp_dir!()

    path =
      Path.join(
        tmp_dir,
        "papyrus_mock_responses_#{label}_#{System.unique_integer([:positive])}.bin"
      )

    File.write!(path, :erlang.term_to_binary(responses))
    path
  end

  @doc "Map of command atoms to their byte values, for building response configs."
  @spec command_byte(atom()) :: non_neg_integer()
  def command_byte(:init), do: 0x01
  def command_byte(:display), do: 0x02
  def command_byte(:clear), do: 0x03
  def command_byte(:sleep), do: 0x04

  # At compile time, resolve the source directory relative to this file.
  # This file lives at lib/papyrus/mock_port.ex, so __DIR__ is lib/papyrus/,
  # and the project root is two levels up.
  @project_root Path.expand("../..", __DIR__)

  defp wrapper_path do
    Path.join([@project_root, "test", "support", "mock_port.sh"])
  end

  defp mock_script_path do
    Path.join([@project_root, "test", "support", "mock_port_script.exs"])
  end
end
