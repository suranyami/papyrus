# examples/load_images.exs
#
# Loads all PNG images from examples/images/ and displays them sequentially.
# Run on a Raspberry Pi with a connected display:
#
#   mix run examples/load_images.exs
#   mix run examples/load_images.exs --model Papyrus.Displays.MyDisplay --delay 5

{opts, _, _} = OptionParser.parse(System.argv(), strict: [model: :string, delay: :integer])

display_module =
  case opts[:model] do
    nil -> Papyrus.Displays.Waveshare12in48
    name -> String.to_existing_atom("Elixir.#{name}")
  end

delay_ms = (opts[:delay] || 3) * 1000

IO.puts("Starting display: #{inspect(display_module)}")
{:ok, display} = Papyrus.Display.start_link(display_module: display_module)

spec = Papyrus.Display.spec(display)
IO.puts("Display: #{spec.width}x#{spec.height}, #{spec.buffer_size} bytes/frame")

images_dir = Path.join(__DIR__, "images")
images = images_dir |> Path.join("*.png") |> Path.wildcard() |> Enum.sort()

if images == [] do
  IO.puts("No PNG images found in #{images_dir}")
  System.halt(1)
end

IO.puts("Found #{length(images)} image(s)\n")

Enum.each(images, fn path ->
  name = Path.basename(path)
  IO.puts("Loading: #{name}")
  {:ok, buffer} = Papyrus.Bitmap.from_image(path, spec)
  IO.puts("  Buffer: #{byte_size(buffer)} bytes")

  # For :three_color displays, from_image/2 returns a single-plane B&W buffer.
  # Duplicate it as both black and red planes.
  display_buffer =
    case spec.color_mode do
      :three_color -> buffer <> buffer
      _ -> buffer
    end

  :ok = Papyrus.Display.display(display, display_buffer)
  IO.puts("  Displayed. Waiting #{div(delay_ms, 1000)}s...")
  Process.sleep(delay_ms)
end)

IO.puts("\nSleeping display...")
:ok = Papyrus.Display.sleep(display)
IO.puts("Done.")
