# examples/hello_papyrus.exs
#
# Demonstrates the Papyrus init -> display -> clear -> sleep lifecycle.
# Run on a Raspberry Pi with a connected Waveshare ePaper display:
#
#   mix run examples/hello_papyrus.exs
#
# Override display model:
#   mix run examples/hello_papyrus.exs --model Papyrus.Displays.MyDisplay

{opts, _, _} = OptionParser.parse(System.argv(), strict: [model: :string])

display_module =
  case opts[:model] do
    nil -> Papyrus.Displays.Waveshare12in48
    name -> String.to_existing_atom("Elixir.#{name}")
  end

IO.puts("Starting display: #{inspect(display_module)}")
{:ok, display} = Papyrus.Display.start_link(display_module: display_module)

spec = Papyrus.Display.spec(display)
IO.puts("Display: #{spec.width}x#{spec.height}, #{spec.buffer_size} bytes/frame")

IO.puts("Displaying checkerboard test pattern...")
pattern = Papyrus.TestPattern.checkerboard(spec)

# Waveshare12in48 is a :three_color display — Display.display/2 expects
# 2 * buffer_size bytes (black plane + red plane concatenated).
# Since we only have a B&W pattern, duplicate it for both planes.
buffer =
  case spec.color_mode do
    :three_color -> pattern <> pattern
    _ -> pattern
  end

:ok = Papyrus.Display.display(display, buffer)

IO.puts("Waiting 3 seconds...")
Process.sleep(3_000)

IO.puts("Clearing to white...")
white = Papyrus.TestPattern.full_white(spec)

clear_buffer =
  case spec.color_mode do
    :three_color -> white <> white
    _ -> white
  end

:ok = Papyrus.Display.display(display, clear_buffer)

IO.puts("Sleeping display...")
:ok = Papyrus.Display.sleep(display)

IO.puts("Done.")
