# Script to generate CC0 sample PNG images for Papyrus examples.
# These are original works (procedurally generated high-contrast patterns)
# released under CC0 / public domain.
#
# Run with: mix run examples/images/generate_samples.exs
#
# Generates:
#   examples/images/botanical_illustration.png — organic radial pattern (landscape 4:3)
#   examples/images/mechanical_drawing.png     — geometric grid pattern (portrait 3:4)

images_dir = __DIR__
File.mkdir_p!(images_dir)

# botanical_illustration.png
# 400x300 landscape (4:3 aspect ratio)
# Simulates a botanical/organic radial pattern: concentric circles + radiating lines
# High contrast, bold edges — thresholds cleanly at 128

width = 400
height = 300
cx = div(width, 2)
cy = div(height, 2)

botanical_data =
  for y <- 0..(height - 1), x <- 0..(width - 1) do
    dx = x - cx
    dy = y - cy
    dist = :math.sqrt(dx * dx + dy * dy)
    angle = :math.atan2(dy, dx)

    # Concentric rings (period ~30px) + 12 radiating spokes
    ring_val = :math.cos(dist * :math.pi() / 15)
    spoke_val = :math.cos(angle * 6)

    combined = ring_val * 0.5 + spoke_val * 0.5

    if combined > 0.0, do: 255, else: 0
  end
  |> :erlang.list_to_binary()

botanical_img = StbImage.new(botanical_data, {height, width, 1})
path = Path.join(images_dir, "botanical_illustration.png")
:ok = StbImage.write_file!(botanical_img, path)
size = File.stat!(path).size
IO.puts("Created botanical_illustration.png (#{width}x#{height}, #{size} bytes)")

# mechanical_drawing.png
# 300x400 portrait (3:4 aspect ratio)
# Simulates a mechanical/engineering drawing: grid with concentric squares + diagonal hatching
# Different aspect ratio from botanical to demonstrate letterbox resize

width2 = 300
height2 = 400
cx2 = div(width2, 2)
cy2 = div(height2, 2)

mechanical_data =
  for y <- 0..(height2 - 1), x <- 0..(width2 - 1) do
    # Crosshatch grid lines (every 20px)
    on_grid_x = rem(x, 20) < 2
    on_grid_y = rem(y, 20) < 2

    # Concentric squares (chebyshev distance)
    dist = max(abs(x - cx2), abs(y - cy2))
    on_square = rem(dist, 30) < 3

    # Diagonal lines (period ~14px)
    on_diagonal = rem(x + y, 14) < 2

    if on_grid_x or on_grid_y or on_square or on_diagonal, do: 0, else: 255
  end
  |> :erlang.list_to_binary()

mechanical_img = StbImage.new(mechanical_data, {height2, width2, 1})
path2 = Path.join(images_dir, "mechanical_drawing.png")
:ok = StbImage.write_file!(mechanical_img, path2)
size2 = File.stat!(path2).size
IO.puts("Created mechanical_drawing.png (#{width2}x#{height2}, #{size2} bytes)")
