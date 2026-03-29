defmodule Papyrus.Bitmap.Resize do
  @moduledoc "Letterbox resize: scale to fit display dimensions, pad with white."

  @doc """
  Resize an StbImage to fit within target_w x target_h using letterbox strategy.
  Uses StbImage.resize/3 for the scaling (Mitchell/Catmull-Rom quality).
  Pads remaining space with white (255) pixels.
  Returns a flat binary of exactly target_w * target_h grayscale bytes.
  """
  @spec letterbox(StbImage.t(), pos_integer(), pos_integer()) :: binary()
  def letterbox(%StbImage{shape: {img_h, img_w, 1}} = img, target_w, target_h) do
    if img_w == target_w and img_h == target_h do
      img.data
    else
      scale = min(target_w / img_w, target_h / img_h)
      scaled_w = max(1, trunc(img_w * scale))
      scaled_h = max(1, trunc(img_h * scale))

      resized = StbImage.resize(img, scaled_h, scaled_w)

      pad_top = div(target_h - scaled_h, 2)
      pad_bottom = target_h - scaled_h - pad_top
      pad_left = div(target_w - scaled_w, 2)
      pad_right = target_w - scaled_w - pad_left

      white_row = :binary.copy(<<255>>, target_w)
      top_padding = :binary.copy(white_row, pad_top)
      bottom_padding = :binary.copy(white_row, pad_bottom)

      white_left = :binary.copy(<<255>>, pad_left)
      white_right = :binary.copy(<<255>>, pad_right)

      middle_rows =
        for row_idx <- 0..(scaled_h - 1), into: <<>> do
          row_data = binary_part(resized.data, row_idx * scaled_w, scaled_w)
          <<white_left::binary, row_data::binary, white_right::binary>>
        end

      result = <<top_padding::binary, middle_rows::binary, bottom_padding::binary>>
      expected_size = target_w * target_h
      ^expected_size = byte_size(result)
      result
    end
  end
end
