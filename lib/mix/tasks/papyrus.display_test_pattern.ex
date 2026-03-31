defmodule Mix.Tasks.Papyrus.DisplayTestPattern do
  @moduledoc """
  Display a test pattern on the connected ePaper display.

  Useful for hardware verification and display testing.

  ## Usage

      mix papyrus.display_test_pattern checkerboard
      mix papyrus.display_test_pattern full_white
      mix papyrus.display_test_pattern full_black

  ## Options

      --display     Display module (default: Papyrus.Displays.Waveshare12in48)
      --pattern     Pattern name: checkerboard, full_white, full_black (required)

  ## Examples

      # Display checkerboard pattern
      mix papyrus.display_test_pattern checkerboard

      # Display full white pattern
      mix papyrus.display_test_pattern full_white

      # Use a different display module
      mix papyrus.display_test_pattern checkerboard --display MyCustomDisplay

  """

  use Mix.Task

  @shortdoc "Display a test pattern on the ePaper display"

  @impl true
  def run(args) do
    {opts, args, _invalid} =
      OptionParser.parse(args,
        strict: [
          display: :string,
          pattern: :string
        ]
      )

    display_module =
      Keyword.get(opts, :display, "Papyrus.Displays.Waveshare12in48")
      |> String.to_atom()

    pattern =
      case args do
        [name] -> String.to_atom(name)
        [] -> Keyword.get(opts, :pattern, nil)
      end

    unless pattern do
      Mix.shell().error("Pattern name required. Usage:")
      Mix.shell().info("  mix papyrus.display_test_pattern checkerboard")
      Mix.shell().info("  mix papyrus.display_test_pattern full_white")
      Mix.shell().info("  mix papyrus.display_test_pattern full_black")
      System.halt(1)
    end

    # Start the application
    Application.ensure_all_started(:papyrus)

    Mix.shell().info("Starting display #{inspect(display_module)}...")

    case Papyrus.Display.start_link(display_module: display_module) do
      {:ok, pid} ->
        spec = display_module.spec()
        Mix.shell().info("Display: #{spec.width}x#{spec.height}")
        Mix.shell().info("Pattern: #{pattern}")

        display_pattern(pid, pattern, spec)

      {:error, reason} ->
        Mix.shell().error("Failed to start display: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp display_pattern(pid, :checkerboard, spec) do
    Mix.shell().info("Rendering checkerboard...")
    buffer = Papyrus.TestPattern.checkerboard(spec)
    do_display(pid, buffer)
  end

  defp display_pattern(pid, :full_white, spec) do
    Mix.shell().info("Rendering full white...")
    buffer = Papyrus.TestPattern.full_white(spec)
    do_display(pid, buffer)
  end

  defp display_pattern(pid, :full_black, spec) do
    Mix.shell().info("Rendering full black...")
    buffer = Papyrus.TestPattern.full_black(spec)
    do_display(pid, buffer)
  end

  defp display_pattern(_pid, pattern, _spec) do
    Mix.shell().error("Unknown pattern: #{pattern}")
    Mix.shell().info("Available patterns: checkerboard, full_white, full_black")
    System.halt(1)
  end

  defp do_display(pid, buffer) do
    Mix.shell().info("Sending to display (this may take 10-30 seconds)...")

    case Papyrus.Display.display(pid, buffer) do
      :ok ->
        Mix.shell().info("Pattern displayed successfully!")

      {:error, reason} ->
        Mix.shell().error("Failed to display pattern: #{inspect(reason)}")
        System.halt(1)
    end
  end
end
