#!/bin/sh
exec elixir "$(dirname "$0")/mock_port_script.exs" "$@"
