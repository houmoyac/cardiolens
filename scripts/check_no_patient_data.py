#!/usr/bin/env python3
"""Pre-commit guard: refuse to commit anything that looks like real patient
ECG data. The .gitignore already excludes these paths, but that only helps
until someone runs `git add -f` — this is the defense-in-depth backstop.

Blocked, unconditionally:
  - any WFDB signal/header pair (*.dat, *.hea) — the raw ECG waveform format
  - any SQLite database file (*.db) — real account data once auth exists,
    never meant to be committed (dev DBs are gitignored, this is the
    git-add-f backstop)
  - anything under a data/patients/ or */patients/ directory
  - anything under sample_ecgs/ that is NOT already tracked (new bundled
    "sample" files must be reviewed — they're the one place raw signal data
    is meant to live, but only for public/anonymized demo cases)
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

FORBIDDEN_DIR_MARKERS = ("patients/",)


def is_forbidden(path: str) -> str | None:
    suffix = Path(path).suffix.lower()
    if suffix in {".dat", ".hea"}:
        return f"fichier de signal ECG brut (WFDB) : {path}"
    if suffix == ".db":
        return f"base de données SQLite (données de comptes réelles) : {path}"
    if any(marker in path.replace("\\", "/") for marker in FORBIDDEN_DIR_MARKERS):
        return f"chemin réservé aux données patient : {path}"
    return None


def staged_new_files() -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--cached", "--name-only", "--diff-filter=ACR"],
        capture_output=True,
        text=True,
        check=True,
    )
    return [line for line in result.stdout.splitlines() if line]


def main() -> int:
    violations = [
        msg for path in staged_new_files() if (msg := is_forbidden(path)) is not None
    ]
    if violations:
        print("Commit bloqué — ces fichiers ressemblent à des données patient réelles :\n")
        for v in violations:
            print(f"  - {v}")
        print(
            "\nSi ce sont de vraies données ECG, elles ne doivent PAS être commitées ici, "
            "même anonymisées, sans passer par une revue explicite.\n"
            "Si c'est un faux positif (ex. un nouvel échantillon public légitime dans "
            "sample_ecgs/), retire ce garde-fou temporairement en connaissance de cause."
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
