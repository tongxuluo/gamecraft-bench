"""Allow `python -m gamecraft_bench.verifier` to invoke the CLI."""

from .cli import main

if __name__ == "__main__":
    raise SystemExit(main())
