# Changelog

All notable changes to Papyrus will be documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-03-10

### Added
- Initial release
- `Papyrus.Display` GenServer with port-based hardware communication
- `Papyrus.Displays.Waveshare12in48` support (1304×984, black/white)
- `Papyrus.Protocol` binary encode/decode for port messages
- `c_src/epd_port.c` port binary with init/display/clear/sleep commands
- `guides/getting_started.md` and `guides/hardware_setup.md`
- Example app `examples/hello_papyrus`
