from __future__ import annotations

from typing import IO

import numpy as np
from numpy.typing import NDArray


def load_signal_from_csv(file: IO[bytes] | IO[str] | str) -> NDArray[np.float64]:
    """Parse a CSV containing an ECG signal, tolerating the shapes people
    actually export: a header row (skipped — anything that isn't fully
    numeric is not data), a single column of raw values, or a two-column
    "time, amplitude" layout (the last column is taken as the signal;
    time/index columns are assumed to lead, never trail, real amplitude
    data). Never guesses when nothing numeric is found — raises instead.
    """
    if isinstance(file, str):
        text = file
    else:
        raw = file.read()
        text = raw.decode("utf-8") if isinstance(raw, bytes) else raw

    rows: list[list[float]] = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            values = [float(part) for part in line.split(",")]
        except ValueError:
            continue  # header or other non-numeric row — skip, don't fail
        rows.append(values)

    if not rows:
        raise ValueError("Aucune donnée numérique trouvée dans le fichier CSV.")

    width = len(rows[0])
    rows = [r for r in rows if len(r) == width]  # drop any ragged trailing row
    array = np.asarray(rows, dtype=np.float64)

    if array.ndim == 2 and array.shape[1] > 1:
        array = array[:, -1]  # last column = amplitude in a time,amplitude layout

    return array.ravel()
