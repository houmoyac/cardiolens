from __future__ import annotations

import io

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pytest
from PIL import Image

from cardiolens.image_digitization import (
    TraceExtractionError,
    extract_trace_from_image,
    trace_to_signal,
)


def _render_curve_as_image(
    y_values: np.ndarray, width_px: int = 400, height_px: int = 200
) -> np.ndarray:
    fig, ax = plt.subplots(figsize=(width_px / 100, height_px / 100), dpi=100)
    ax.plot(y_values, color="black", linewidth=2)
    ax.set_xlim(0, len(y_values))
    ax.axis("off")
    fig.subplots_adjust(left=0, right=1, top=1, bottom=0)
    buf = io.BytesIO()
    fig.savefig(buf, format="png", facecolor="white")
    plt.close(fig)
    buf.seek(0)
    return np.asarray(Image.open(buf).convert("RGB"))


def test_extract_trace_recovers_known_curve_shape() -> None:
    x = np.linspace(0, 4 * np.pi, 400)
    known_shape = np.sin(x)
    image = _render_curve_as_image(known_shape)

    pixel_trace = extract_trace_from_image(image)
    recovered = trace_to_signal(pixel_trace)

    # Compare shapes, not absolute scale/offset — pixels and the original
    # data live in different units. A correlation near 1 means the
    # recovered curve has the same shape as what was drawn.
    normalized_recovered = (recovered - recovered.mean()) / recovered.std()
    normalized_known = (known_shape - known_shape.mean()) / known_shape.std()
    resampled_known = np.interp(
        np.linspace(0, 1, len(normalized_recovered)),
        np.linspace(0, 1, len(normalized_known)),
        normalized_known,
    )

    correlation = np.corrcoef(normalized_recovered, resampled_known)[0, 1]
    assert correlation > 0.9


def test_extract_trace_returns_nan_on_blank_columns() -> None:
    blank = np.full((100, 100, 3), 255, dtype=np.uint8)
    pixel_trace = extract_trace_from_image(blank)
    assert np.all(np.isnan(pixel_trace))


def test_trace_to_signal_rejects_mostly_empty_trace() -> None:
    mostly_nan = np.full(100, np.nan)
    mostly_nan[:10] = 50.0  # only 10% of columns have a detected trace

    with pytest.raises(TraceExtractionError):
        trace_to_signal(mostly_nan)


def test_trace_to_signal_fills_small_gaps() -> None:
    pixel_trace = np.array([10.0, 20.0, np.nan, 40.0, 50.0])
    signal = trace_to_signal(pixel_trace)
    assert not np.any(np.isnan(signal))
    assert len(signal) == 5
