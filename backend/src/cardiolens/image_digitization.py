from __future__ import annotations

import numpy as np
from numpy.typing import NDArray
from PIL import Image
from scipy.signal import find_peaks

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


class GridDetectionError(RuntimeError):
    """Raised when no plausible regular grid spacing can be found — never
    guess a calibration, since a wrong one silently corrupts every
    downstream measurement (ms/mV) without looking wrong."""


def detect_grid_spacing_px(
    image: NDArray[np.uint8],
    grid_rgb: tuple[int, int, int] = (255, 150, 150),
    tolerance: int = 60,
) -> float:
    """Estimate the pixel spacing between regular grid lines of a given
    color (standard ECG paper prints a light red/pink mm-grid).

    Assumes a square grid (equal horizontal/vertical spacing in real mm) —
    true for standard ECG paper — and estimates spacing from the more
    reliably visible axis via autocorrelation of the grid-colored pixel
    count per column. Only the horizontal (time) axis is used here since a
    typical strip is much wider than tall, giving more periods to lock
    onto; assuming a square grid, the same spacing applies vertically.
    """
    diff = np.abs(image.astype(int) - np.array(grid_rgb)).sum(axis=-1)
    mask = diff < tolerance

    column_profile = mask.sum(axis=0).astype(np.float64)
    return _estimate_periodicity_px(column_profile)


def _estimate_periodicity_px(profile: NDArray[np.float64]) -> float:
    centered = profile - profile.mean()
    if not np.any(centered):
        raise GridDetectionError(
            "Aucune couleur de grille détectée dans l'image — impossible "
            "d'estimer l'espacement du quadrillage."
        )

    autocorr = np.correlate(centered, centered, mode="full")
    autocorr = autocorr[len(autocorr) // 2 :]  # keep lags >= 0

    peaks, _ = find_peaks(autocorr, height=autocorr[0] * 0.3)
    peaks = peaks[peaks > 2]  # discard the trivial lag-0 peak and its shoulder
    if peaks.size == 0:
        raise GridDetectionError(
            "Aucune périodicité régulière détectée — le quadrillage n'est "
            "peut-être pas visible ou pas de la couleur attendue."
        )

    return float(peaks[0])


def calibrate_trace(
    pixel_trace: NDArray[np.float64],
    grid_spacing_px: float,
    mm_per_grid_line: float = 5.0,
    mm_per_second: float = 25.0,
    mm_per_mv: float = 10.0,
) -> tuple[NDArray[np.float64], float]:
    """Convert a pixel-unit trace to a real signal in mV, plus its
    effective sampling rate — using the detected grid spacing and the
    standard ECG paper speed/gain (25 mm/s, 10 mm/mV; both configurable
    for the rarer non-standard case, but never silently assumed different
    from standard without the caller saying so).
    """
    if grid_spacing_px <= 0:
        raise GridDetectionError("Espacement de grille invalide (<= 0 px).")

    px_per_mm = grid_spacing_px / mm_per_grid_line
    px_per_second = px_per_mm * mm_per_second
    sampling_rate_hz = px_per_second  # one column == one time sample

    signal_mv = pixel_trace / px_per_mm / mm_per_mv
    return signal_mv, sampling_rate_hz
