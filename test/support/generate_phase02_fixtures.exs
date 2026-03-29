# Script to generate test fixtures for Plan 02 (Resize and Pack tests)
# Run with: mix run test/support/generate_phase02_fixtures.exs

fixtures_dir = Path.join(__DIR__, "fixtures")
File.mkdir_p!(fixtures_dir)

# gradient_4x8.png — 4x8 horizontal gradient: left column = 0, right column = 255
# Shape: {height=8, width=4, channels=1}
# Row i: [0, 85, 170, 255] — linear gradient left to right
gradient_row = <<0, 85, 170, 255>>
gradient_data = for _ <- 1..8, into: <<>>, do: gradient_row
gradient_img = StbImage.new(gradient_data, {8, 4, 1})
StbImage.write_file!(gradient_img, Path.join(fixtures_dir, "gradient_4x8.png"))
IO.puts("Created gradient_4x8.png (4x8 horizontal gradient)")

# tall_2x8.png — 2x8 all-white PNG (tall/narrow for letterbox aspect ratio testing)
# Shape: {height=8, width=2, channels=1}
tall_data = :binary.copy(<<255>>, 2 * 8)
tall_img = StbImage.new(tall_data, {8, 2, 1})
StbImage.write_file!(tall_img, Path.join(fixtures_dir, "tall_2x8.png"))
IO.puts("Created tall_2x8.png (2x8 all-white, narrow/tall for letterbox testing)")
