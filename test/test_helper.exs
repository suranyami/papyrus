# Exclude hardware-required tests by default.
# Run hardware tests explicitly: mix test test/hardware/ --include hardware
ExUnit.start(exclude: [:hardware])
