defmodule Papyrus.Bitmap do
  @moduledoc """
  Converts images to packed 1-bit binary buffers for ePaper displays, and exports buffers to PNG/BMP.

  ## Examples

      # Load image to packed buffer
      {:ok, buffer} = Papyrus.Bitmap.from_image("input.png", spec)

      # Export packed buffer to PNG file
      :ok = Papyrus.Bitmap.to_file(buffer, "output.png", spec)

      # Export to PNG binary
      {:ok, png_binary} = Papyrus.Bitmap.to_binary(buffer, spec)

  """

  alias Papyrus.DisplaySpec
  import Bitwise

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

  @doc """
  Convert a PNG binary to a packed 1-bit ePaper binary buffer.

  Accepts raw PNG binary data (e.g., from wkhtmltoimage or resvg output) and
  converts it to a 1-bit packed buffer suitable for ePaper displays.

  ## Parameters

  - `png_binary` — Raw PNG binary data
  - `spec` — The display specification struct
  - `opts` — Optional keyword list passed to the loader

  ## Returns

  - `{:ok, binary}` — Packed 1-bit buffer on success
  - `{:error, reason}` — Error tuple on failure

  ## Examples

      {:ok, png_binary} = File.read("image.png")
      {:ok, buffer} = Papyrus.Bitmap.from_binary(png_binary, spec)

  """
  @spec from_binary(binary(), DisplaySpec.t(), keyword()) :: {:ok, binary()} | {:error, any()}
  def from_binary(png_binary, %DisplaySpec{} = spec, opts \\ []) do
    # Write to temp file, then use from_image/2
    temp_path = System.tmp_dir!() |> Path.join("bitmap_#{System.unique_integer()}.png")

    try do
      File.write!(temp_path, png_binary)
      from_image(temp_path, spec, opts)
    after
      File.rm(temp_path)
    end
  end

  @doc """
  Export a packed 1-bit ePaper buffer to a PNG file.

  Expands the 1-bit packed buffer to grayscale (0/255 values) and writes to disk
  as a PNG file for visual verification or archival.

  ## Parameters

  - `buffer` — Packed 1-bit ePaper buffer
  - `path` — Output file path (extension determines format: .png, .bmp, .jpg)
  - `spec` — Display specification with width/height

  ## Returns

  - `:ok` on success
  - `{:error, reason}` on failure

  ## Examples

      {:ok, buffer} = Papyrus.Bitmap.from_image("input.png", spec)
      :ok = Papyrus.Bitmap.to_file(buffer, "output.png", spec)
      :ok = Papyrus.Bitmap.to_file(buffer, "output.bmp", spec)

  @since "0.2.0"
  """
  @spec to_file(binary(), String.t(), DisplaySpec.t()) :: :ok | {:error, any()}
  def to_file(buffer, path, %DisplaySpec{} = spec) do
    grayscale = expand_to_grayscale(buffer, spec.width, spec.bit_order)
    img = StbImage.new(grayscale, {spec.height, spec.width, 1})

    case StbImage.write_file(img, path, format: :png) do
      :ok -> :ok
      {:error, reason} -> {:error, "failed to write image: #{reason}"}
    end
  end

  @doc """
  Convert a packed 1-bit ePaper buffer to PNG binary.

  Expands the 1-bit packed buffer to grayscale and encodes as PNG,
  suitable for returning from a render function or sending over network.

  ## Parameters

  - `buffer` — Packed 1-bit ePaper buffer
  - `spec` — Display specification with width/height

  ## Returns

  - `{:ok, png_binary}` — PNG-encoded grayscale image
  - `{:error, reason}` on failure

  ## Examples

      {:ok, buffer} = Papyrus.Renderer.Headless.render_html(html, spec)
      {:ok, png_binary} = Papyrus.Bitmap.to_binary(buffer, spec)
      File.write!("rendered.png", png_binary)

  @since "0.2.0"
  """
  @spec to_binary(binary(), DisplaySpec.t()) :: {:ok, binary()} | {:error, any()}
  def to_binary(buffer, %DisplaySpec{} = spec) do
    grayscale = expand_to_grayscale(buffer, spec.width, spec.bit_order)
    img = StbImage.new(grayscale, {spec.height, spec.width, 1})

    try do
      png_binary = StbImage.to_binary(img, :png)
      {:ok, png_binary}
    rescue
      e -> {:error, "failed to encode PNG: #{inspect(e)}"}
    end
  end

  # Expand 1-bit packed buffer to grayscale (0/255 values)
  defp expand_to_grayscale(buffer, _width, bit_order) do
    white_value = if bit_order == :white_high, do: 255, else: 0
    black_value = 255 - white_value

    # Unpack bits from bytes
    buffer
    |> :binary.bin_to_list()
    |> Enum.flat_map(&unpack_byte/1)
    |> Enum.map(fn bit ->
      if bit == 1, do: white_value, else: black_value
    end)
    |> :binary.list_to_bin()
  end

  defp unpack_byte(byte) do
    [
      Bitwise.band(byte, 0x80) >>> 7,
      Bitwise.band(byte, 0x40) >>> 6,
      Bitwise.band(byte, 0x20) >>> 5,
      Bitwise.band(byte, 0x10) >>> 4,
      Bitwise.band(byte, 0x08) >>> 3,
      Bitwise.band(byte, 0x04) >>> 2,
      Bitwise.band(byte, 0x02) >>> 1,
      Bitwise.band(byte, 0x01)
    ]
  end

  defp loader do
    Application.get_env(:papyrus, :bitmap_loader, Papyrus.Bitmap.StbLoader)
  end
end
