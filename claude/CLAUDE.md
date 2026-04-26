# Python

Use `uv` for all Python work. Never invoke `python`, `python3`, `pip`, or `pip3`
directly.

- Run scripts with `uv run <script>` (or `uv run python <script>` if you
  specifically need the interpreter).
- Add dependencies with `uv add <pkg>`; remove with `uv remove <pkg>`.
- Sync the environment with `uv sync`.
- Run one-off tools with `uvx <tool>` instead of `pipx` or a bare `pip install`.

If a project has no `pyproject.toml` yet, initialize one with `uv init` rather
than reaching for `pip` or `venv`.
