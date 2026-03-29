# Script to generate minimal PNG test fixtures for bitmap tests.
# Run with: mix run test/support/generate_fixtures.exs
#
# Generates:
#   test/support/fixtures/white_4x8.png — 4-wide, 8-tall all-white PNG (1 channel)
#   test/support/fixtures/black_4x8.png — 4-wide, 8-tall all-black PNG (1 channel)

fixtures_dir = Path.join(__DIR__, "fixtures")
File.mkdir_p!(fixtures_dir)

# white_4x8: 4 wide, 8 tall, 1 channel, all 255
white_data = :binary.copy(<<255>>, 4 * 8)
white_img = StbImage.new(white_data, {8, 4, 1})
:ok = StbImage.write_file!(white_img, Path.join(fixtures_dir, "white_4x8.png"))
IO.puts("Created test/support/fixtures/white_4x8.png")

# black_4x8: 4 wide, 8 tall, 1 channel, all 0
black_data = :binary.copy(<<0>>, 4 * 8)
black_img = StbImage.new(black_data, {8, 4, 1})
:ok = StbImage.write_file!(black_img, Path.join(fixtures_dir, "black_4x8.png"))
IO.puts("Created test/support/fixtures/black_4x8.png")
