defmodule Papyrus.Hardware.BitmapRenderTest do
  use ExUnit.Case, async: false

  @moduletag :hardware

  @images_dir Path.expand(Path.join([__DIR__, "..", "..", "examples", "images"]))

  setup do
    display_module =
      Application.get_env(:papyrus, :test_display_module, Papyrus.Displays.Waveshare12in48)

    {:ok, display} = Papyrus.Display.start_link(display_module: display_module)

    on_exit(fn ->
      if Process.alive?(display), do: Papyrus.Display.sleep(display)
    end)

    {:ok, display: display, spec: Papyrus.Display.spec(display)}
  end

  test "renders each sample image without error", %{display: display, spec: spec} do
    images = @images_dir |> Path.join("*.png") |> Path.wildcard() |> Enum.sort()
    assert images != [], "No PNG images found in #{@images_dir}"

    Enum.each(images, fn path ->
      name = Path.basename(path)
      IO.puts("\n  Loading: #{name}")

      {:ok, buffer} = Papyrus.Bitmap.from_image(path, spec)
      IO.puts("  Buffer: #{byte_size(buffer)} bytes")

      # For :three_color displays, from_image/2 returns a single B&W plane.
      # Duplicate it to satisfy the two-plane (black + red) requirement.
      display_buffer =
        case spec.color_mode do
          :three_color -> buffer <> buffer
          _ -> buffer
        end

      assert :ok == Papyrus.Display.display(display, display_buffer)
      IO.puts("  Displayed — inspect the screen now.")
      IO.puts("  Press Enter to continue to next image...")
      IO.read(:line)
    end)
  end

  test "renders checkerboard test pattern without error", %{display: display, spec: spec} do
    IO.puts("\n  Displaying checkerboard test pattern...")
    pattern = Papyrus.TestPattern.checkerboard(spec)

    display_buffer =
      case spec.color_mode do
        :three_color -> pattern <> pattern
        _ -> pattern
      end

    assert :ok == Papyrus.Display.display(display, display_buffer)
    IO.puts("  Displayed — verify alternating black/white pattern on screen.")
    IO.puts("  Press Enter to continue...")
    IO.read(:line)
  end
end
