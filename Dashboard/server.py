"""Genesis Dashboard thin entrypoint preserving compatibility with start.bat and uvicorn."""

import sys
from pathlib import Path

_DASHBOARD_DIR = str(Path(__file__).resolve().parent)
if _DASHBOARD_DIR not in sys.path:
    sys.path.insert(0, _DASHBOARD_DIR)

from backend.app import app, create_app, run  # noqa: E402

__all__ = ["app", "create_app", "run"]

if __name__ == "__main__":
    run()
