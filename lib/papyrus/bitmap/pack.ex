defmodule Papyrus.Bitmap.Pack do
  @moduledoc "Grayscale to 1-bit conversion: threshold, Floyd-Steinberg dithering, MSB-first bit packing."

  @doc """
  Convert grayscale pixel data to a packed 1-bit buffer.

  - pixels: binary of width*height grayscale bytes (row-major, left-to-right, top-to-bottom)
  - width: pixel width of image
  - bit_order: :white_high (luminance > 128 -> 1 bit) or :white_low (luminance > 128 -> 0 bit)
  - opts: [dither: true] for Floyd-Steinberg error diffusion

  Returns a binary of ceil(width/8) * height bytes.
  """
  @spec to_buffer(binary(), pos_integer(), Papyrus.DisplaySpec.bit_order(), keyword()) :: binary()
  def to_buffer(pixels, width, bit_order, opts \\ [])

  def to_buffer(pixels, width, bit_order, dither: true) do
    pixel_list = for <<b <- pixels>>, do: b
    _height = div(byte_size(pixels), width)
    dithered = floyd_steinberg(pixel_list, width)
    pack_bits(dithered, width, bit_order)
  end

  def to_buffer(pixels, width, bit_order, _opts) do
    pixel_list = for <<b <- pixels>>, do: b
    pack_bits(pixel_list, width, bit_order)
  end

  # MSB-first bit packing: chunk pixels into rows, then into groups of 8
  defp pack_bits(pixels, width, bit_order) do
    white_bit = if bit_order == :white_high, do: 1, else: 0
    row_bytes = div(width + 7, 8)

    pixels
    |> Enum.chunk_every(width)
    |> Enum.flat_map(fn row ->
      # Pad row to multiple of 8 with white pixels (255)
      padded = pad_row(row, row_bytes * 8, 255)
      # Pack each group of 8 pixels into a byte, MSB-first
      padded
      |> Enum.chunk_every(8)
      |> Enum.map(fn group ->
        [p0, p1, p2, p3, p4, p5, p6, p7] = group
        b0 = pixel_bit(p0, white_bit)
        b1 = pixel_bit(p1, white_bit)
        b2 = pixel_bit(p2, white_bit)
        b3 = pixel_bit(p3, white_bit)
        b4 = pixel_bit(p4, white_bit)
        b5 = pixel_bit(p5, white_bit)
        b6 = pixel_bit(p6, white_bit)
        b7 = pixel_bit(p7, white_bit)
        <<b0::1, b1::1, b2::1, b3::1, b4::1, b5::1, b6::1, b7::1>>
      end)
    end)
    |> IO.iodata_to_binary()
  end

  defp pixel_bit(value, white_bit) when value > 128, do: white_bit
  defp pixel_bit(_value, white_bit), do: 1 - white_bit

  defp pad_row(row, target_length, pad_value) do
    deficit = target_length - length(row)

    if deficit > 0 do
      row ++ List.duplicate(pad_value, deficit)
    else
      row
    end
  end

  # Floyd-Steinberg error diffusion dithering
  # Processes row by row, carrying error accumulators as state
  defp floyd_steinberg(pixels, width) do
    rows = Enum.chunk_every(pixels, width)

    {dithered_rows, _} =
      Enum.map_reduce(rows, List.duplicate(0, width + 2), fn row, next_row_errors ->
        # Process the current row, accumulating errors into next row
        {dithered_row, new_next_errors} =
          Enum.reduce(
            Enum.with_index(row),
            {[], next_row_errors},
            fn {pixel, col_idx}, {acc_row, next_errs} ->
              # col_idx is 0-based; next_errs has extra padding (+2) for safe x-1 and x+1 access
              err_idx = col_idx + 1

              old_val = clamp(pixel + Enum.at(next_errs, err_idx, 0), 0, 255)
              new_val = if old_val > 128, do: 255, else: 0
              quant_err = old_val - new_val

              # Distribute error using Floyd-Steinberg coefficients 7, 3, 5, 1 (out of 16)
              # Right neighbor (same row — immediate, handled via acc_row carry)
              # But since we are reducing left-to-right and can't update future pixels in acc_row,
              # we need to pass the right-neighbor error forward via the accumulator.
              # We handle this by carrying right_error through the reduce.
              updated_next_errs =
                next_errs
                |> update_error(err_idx - 1, div(quant_err * 3, 16))
                |> update_error(err_idx, div(quant_err * 5, 16))
                |> update_error(err_idx + 1, div(quant_err * 1, 16))

              {acc_row ++ [{new_val, div(quant_err * 7, 16)}], updated_next_errs}
            end
          )

        # Now apply right-neighbor errors (7/16) from each pixel to the next pixel in this row
        final_dithered_row = apply_right_errors(dithered_row)

        {final_dithered_row, new_next_errors}
      end)

    List.flatten(dithered_rows)
  end

  # Apply right-neighbor (7/16) errors: each pixel's error propagates to the next
  defp apply_right_errors(row_with_errors) do
    {result, _carry} =
      Enum.reduce(row_with_errors, {[], 0}, fn {pixel, right_err}, {acc, carry} ->
        # The carry is the right-neighbor error from the previous pixel
        final_val = if pixel + carry > 128, do: 255, else: 0
        {acc ++ [final_val], right_err}
      end)

    result
  end

  defp update_error(list, idx, delta) when idx >= 0 and idx < length(list) do
    List.update_at(list, idx, &(&1 + delta))
  end

  defp update_error(list, _idx, _delta), do: list

  defp clamp(value, min_val, max_val) do
    value |> max(min_val) |> min(max_val)
  end
end
