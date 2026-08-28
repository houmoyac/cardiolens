from __future__ import annotations

import numpy as np
from numpy.typing import NDArray
from PIL import Image

# First increment of ECG image digitization — see ARCHITECTURE.md. This
# module only follows a dark trace on a light background, column by column.
# It deliberately does NOT yet handle: mm-grid removal/calibration,
# perspective correction, 12-lead segmentation, or real-photo noise. Those
# are separate, harder increments to build (and validate) once this core
# trace-following step is proven correct on clean images.


class TraceExtractionError(RuntimeError):
    """Raised when too few columns contain a plausible trace. Never return
    a partially-fabricated trace — a gap-filled guess presented as signal
    is exactly the kind of silent-wrong-data risk this project avoids
    elsewhere (see the ECGProcessingError philosophy in signal_processing.py)."""


def extract_trace_from_image(
    image: NDArray[np.uint8], dark_threshold: int = 128
) -> NDArray[np.float64]:
    """Follow a dark trace on a light background, column by column.

    Returns one y pixel-position per column (the trace's vertical position
    in that column), NaN where no dark pixel was found. Units are pixels,
    not mV/ms — calibration is a separate, not-yet-built step.
    """
    if image.ndim == 3:
        gray = np.asarray(Image.fromarray(image).convert("L"), dtype=np.float64)
    else:
        gray = image.astype(np.float64)

    height, width = gray.shape
    ys = np.full(width, np.nan)

    for x in range(width):
        dark_rows = np.where(gray[:, x] < dark_threshold)[0]
        if dark_rows.size == 0:
            continue
        # Centroid of dark pixels in this column — robust to a stroke a few
        # pixels wide and to antialiasing at the trace's edges.
        ys[x] = float(np.mean(dark_rows))

    return ys


def trace_to_signal(pixel_trace: NDArray[np.float64]) -> NDArray[np.float64]:
    """Convert a pixel-row trace to a signal-shaped array: flips the
    vertical axis (image rows grow downward; ECG amplitude grows upward)
    and linearly interpolates through small gaps. Still in arbitrary pixel
    units — real mV/ms calibration from the printed grid is not built yet.
    """
    valid = ~np.isnan(pixel_trace)
    if valid.sum() < len(pixel_trace) * 0.5:
        raise TraceExtractionError(
            "Moins de la moitié des colonnes de l'image contiennent un tracé "
            "détectable — image trop bruitée, mal cadrée, ou sans tracé net."
        )

    x = np.arange(len(pixel_trace))
    interpolated = np.interp(x, x[valid], pixel_trace[valid])
    return -interpolated
