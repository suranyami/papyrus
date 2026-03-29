defmodule Papyrus.Bitmap do
  @moduledoc "Converts images to packed 1-bit binary buffers for ePaper displays."

  alias Papyrus.DisplaySpec

  @doc "Return an all-white buffer of the correct size for the given display spec."
  @spec blank(DisplaySpec.t()) :: binary()
  def blank(%DisplaySpec{bit_order: :white_high, buffer_size: size}),
    do: :binary.copy(<<0xFF>>, size)

  def blank(%DisplaySpec{bit_order: :white_low, buffer_size: size}),
    do: :binary.copy(<<0x00>>, size)

  @doc "Convert an image file to a packed 1-bit ePaper binary buffer."
  @spec from_image(String.t(), DisplaySpec.t()) :: {:ok, binary()} | {:error, atom()}
  def from_image(path, spec), do: from_image(path, spec, [])

  @doc "Convert an image file to a packed 1-bit ePaper binary buffer with options."
  @spec from_image(String.t(), DisplaySpec.t(), keyword()) :: {:ok, binary()} | {:error, atom()}
  def from_image(path, %DisplaySpec{} = spec, opts) do
    with {:ok, img} <- loader().load(path) do
      pixels = Papyrus.Bitmap.Resize.letterbox(img, spec.width, spec.height)
      buffer = Papyrus.Bitmap.Pack.to_buffer(pixels, spec.width, spec.bit_order, opts)
      {:ok, buffer}
    end
  end

  defp loader do
    Application.get_env(:papyrus, :bitmap_loader, Papyrus.Bitmap.StbLoader)
  end
end
