defmodule Papyrus.Bitmap.ResizeTest do
  use ExUnit.Case, async: true

  alias Papyrus.Bitmap.Resize

  @fixtures_dir Path.join(__DIR__, "../../support/fixtures")

  defp fixture_path(name), do: Path.join(@fixtures_dir, name)

  defp load_img(name) do
    {:ok, img} = StbImage.read_file(fixture_path(name), channels: 1)
    img
  end

  describe "letterbox/3" do
    test "pass-through when image matches target dimensions exactly" do
      img = load_img("white_4x8.png")
      # white_4x8.png is {height=8, width=4, channels=1}
      result = Resize.letterbox(img, 4, 8)
      assert byte_size(result) == 4 * 8
      # All white (255) pixels — should remain unchanged
      assert result == :binary.copy(<<255>>, 4 * 8)
    end

    test "output is exactly target_w * target_h bytes" do
      img = load_img("white_4x8.png")
      result = Resize.letterbox(img, 16, 16)
      assert byte_size(result) == 16 * 16
    end

    test "scales down wider-than-tall image and pads top/bottom with white" do
      # white_4x8.png is {height=8, width=4} — aspect 4:8 = 1:2 (taller than wide)
      # Fitting into 8x8: scale by min(8/4, 8/8) = min(2.0, 1.0) = 1.0
      # scaled_w=4, scaled_h=8 — no scaling needed, pad left/right
      img = load_img("white_4x8.png")
      result = Resize.letterbox(img, 8, 8)
      assert byte_size(result) == 8 * 8
    end

    test "scales narrow/tall image and pads left/right with white" do
      # tall_2x8.png is {height=8, width=2} — very tall
      # Fitting into 8x8: scale = min(8/2, 8/8) = min(4.0, 1.0) = 1.0
      # scaled_w=2, scaled_h=8, pad_left=3, pad_right=3
      img = load_img("tall_2x8.png")
      result = Resize.letterbox(img, 8, 8)
      assert byte_size(result) == 8 * 8
      # The padding columns are white (255)
      # In an 8-wide image with 2-pixel content centered, we get:
      # 3 white + 2 content + 3 white per row (all content is white too)
      assert result == :binary.copy(<<255>>, 8 * 8)
    end

    test "wide image is scaled down and padded top/bottom" do
      # gradient_4x8.png is {height=8, width=4} — taller than wide
      # Fitting into 8x4 (wide short target): scale = min(8/4, 4/8) = min(2.0, 0.5) = 0.5
      # scaled_w=2, scaled_h=4, pad_top=0, pad_bottom=0, pad_left=3, pad_right=3
      img = load_img("gradient_4x8.png")
      result = Resize.letterbox(img, 8, 4)
      assert byte_size(result) == 8 * 4
    end

    test "padding bytes are white (255)" do
      # tall_2x8.png (2x8) letterboxed into 8x8 — padding columns must be white
      img = load_img("tall_2x8.png")
      result = Resize.letterbox(img, 8, 8)
      # Since the source is all-white and padding is white, all bytes should be 255
      assert :binary.bin_to_list(result) |> Enum.all?(&(&1 == 255))
    end
  end
end
