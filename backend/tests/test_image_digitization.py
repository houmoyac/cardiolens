from __future__ import annotations

import io

import matplotlib

matplotlib.use("Agg")
import cv2
import matplotlib.pyplot as plt
import numpy as np
import pytest
from PIL import Image

from cardiolens.image_digitization import (
    GridDetectionError,
    PerspectiveCorrectionError,
    TraceExtractionError,
    calibrate_trace,
    correct_perspective,
    detect_grid_color,
    detect_grid_spacing_px,
    extract_trace_from_image,
    find_document_corners,
    segment_grid_panels,
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


def test_extract_trace_ignores_persistent_decoy_line() -> None:
    """Regression test for a real bug found on a real (non-synthetic) ECG
    image: a bold horizontal line/border at a fixed row was pulling the
    recovered trace toward it in every column. A decoy line here plays
    that same role — the trace, which moves, must still be recovered
    correctly despite a stationary dark row cutting across the whole
    image."""
    x = np.linspace(0, 4 * np.pi, 400)
    known_shape = np.sin(x)
    image = _render_curve_as_image(known_shape).copy()

    decoy_row = 20
    image[decoy_row, :] = (0, 0, 0)

    pixel_trace = extract_trace_from_image(image)
    recovered = trace_to_signal(pixel_trace)

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


def _render_grid_image(
    spacing_px: int = 20,
    width_px: int = 400,
    height_px: int = 300,
    grid_color: tuple[int, int, int] = (255, 150, 150),
    with_trace: bool = False,
) -> np.ndarray:
    image = np.full((height_px, width_px, 3), 255, dtype=np.uint8)
    for x in range(0, width_px, spacing_px):
        image[:, x] = grid_color
    for y in range(0, height_px, spacing_px):
        image[y, :] = grid_color
    if with_trace:
        # A real ECG image always has dark trace ink alongside the grid —
        # detect_grid_color relies on that contrast (background vs. ink)
        # to isolate the grid as the mid-tone left over; a bare grid with
        # no ink at all isn't a realistic case to test it against.
        x = np.linspace(0, 4 * np.pi, width_px)
        y = (height_px / 2 + np.sin(x) * height_px * 0.2).astype(int)
        for col, row in enumerate(y):
            image[max(0, row - 1) : row + 2, col] = (0, 0, 0)
    return image


def test_detect_grid_spacing_recovers_known_value() -> None:
    known_spacing = 20
    image = _render_grid_image(spacing_px=known_spacing, with_trace=True)

    detected = detect_grid_spacing_px(image)

    assert abs(detected - known_spacing) <= 1


def test_detect_grid_color_finds_pink_grid() -> None:
    image = _render_grid_image(grid_color=(255, 150, 150), with_trace=True)
    color, tolerance = detect_grid_color(image)
    assert all(abs(a - b) <= 15 for a, b in zip(color, (255, 150, 150), strict=True))
    assert tolerance > 0


def test_detect_grid_color_finds_gray_grid() -> None:
    """The exact case that broke on a real, non-synthetic ECG image: a
    gray grid, not the red/pink previously assumed by default."""
    image = _render_grid_image(grid_color=(240, 240, 240), with_trace=True)
    color, tolerance = detect_grid_color(image)
    assert all(abs(a - b) <= 15 for a, b in zip(color, (240, 240, 240), strict=True))
    assert tolerance > 0


def test_detect_grid_spacing_auto_detects_gray_grid_color() -> None:
    known_spacing = 20
    image = _render_grid_image(
        spacing_px=known_spacing, grid_color=(240, 240, 240), with_trace=True
    )

    detected = detect_grid_spacing_px(image)  # no grid_rgb given — must auto-detect

    assert abs(detected - known_spacing) <= 1


def test_detect_grid_spacing_raises_when_no_grid_color_present() -> None:
    blank = np.full((100, 100, 3), 255, dtype=np.uint8)
    with pytest.raises(GridDetectionError):
        detect_grid_spacing_px(blank)


def test_calibrate_trace_produces_plausible_ecg_units() -> None:
    # A synthetic trace spanning ~30px peak-to-peak, on a 20px grid spacing
    # standing in for 5mm — roughly a 1.5mV swing, physiologically
    # plausible for a QRS complex.
    pixel_trace = np.array([0.0, 10.0, -30.0, 10.0, 0.0] * 20)

    signal_mv, sampling_rate_hz = calibrate_trace(pixel_trace, grid_spacing_px=20.0)

    assert 0.1 <= np.ptp(signal_mv) <= 5.0
    # 20px per 5mm at 25mm/s -> 100px/s sampling rate.
    assert sampling_rate_hz == pytest.approx(100.0)


def test_calibrate_trace_rejects_non_positive_spacing() -> None:
    with pytest.raises(GridDetectionError):
        calibrate_trace(np.array([1.0, 2.0]), grid_spacing_px=0.0)


def _render_page_with_labeled_panels(
    rows: int, cols: int, panel_w: int = 200, panel_h: int = 100
) -> tuple[np.ndarray, dict[tuple[int, int], np.ndarray]]:
    """A synthetic full page: rows x cols panels, each with a distinct
    sine curve (same gentle frequency, different phase — the extraction
    algorithm only follows single-valued-per-column curves reliably, so
    frequency stays representative of an ECG trace, not stressed to its
    aliasing limit) so a panel's extracted content can be matched back to
    the curve it was supposed to contain."""
    page = np.full((rows * panel_h, cols * panel_w, 3), 255, dtype=np.uint8)
    expected: dict[tuple[int, int], np.ndarray] = {}
    panel_index = 0

    for r in range(rows):
        for c in range(cols):
            phase = panel_index * 0.7  # distinct shape per panel, same frequency
            x = np.linspace(0, 2 * np.pi, panel_w)
            curve = np.sin(2 * x + phase) * (panel_h * 0.3)
            baseline = panel_h / 2
            fig, ax = plt.subplots(
                figsize=(panel_w / 100, panel_h / 100), dpi=100
            )
            ax.plot(curve, color="black", linewidth=2)
            ax.set_xlim(0, panel_w)
            ax.set_ylim(-panel_h / 2, panel_h / 2)
            ax.axis("off")
            fig.subplots_adjust(left=0, right=1, top=1, bottom=0)
            buf = io.BytesIO()
            fig.savefig(buf, format="png", facecolor="white")
            plt.close(fig)
            buf.seek(0)
            panel_img = np.asarray(
                Image.open(buf).convert("RGB").resize((panel_w, panel_h))
            )
            page[r * panel_h : (r + 1) * panel_h, c * panel_w : (c + 1) * panel_w] = (
                panel_img
            )
            expected[(r, c)] = curve + baseline
            panel_index += 1

    return page, expected


def test_segment_grid_panels_isolates_the_right_curve_per_cell() -> None:
    rows, cols = 3, 2
    page, expected = _render_page_with_labeled_panels(rows, cols)

    panels = segment_grid_panels(page, rows=rows, cols=cols)

    assert len(panels) == rows
    assert all(len(row) == cols for row in panels)

    for r in range(rows):
        for c in range(cols):
            pixel_trace = extract_trace_from_image(panels[r][c])
            recovered = trace_to_signal(pixel_trace)

            expected_curve = expected[(r, c)]
            normalized_recovered = (recovered - recovered.mean()) / recovered.std()
            normalized_expected = (
                expected_curve - expected_curve.mean()
            ) / expected_curve.std()
            resampled_expected = np.interp(
                np.linspace(0, 1, len(normalized_recovered)),
                np.linspace(0, 1, len(normalized_expected)),
                normalized_expected,
            )

            correlation = np.corrcoef(normalized_recovered, resampled_expected)[0, 1]
            assert correlation > 0.85, f"panel ({r},{c}) correlation={correlation}"


def _make_straight_page_with_grid(
    page_w: int = 300, page_h: int = 200, spacing_px: int = 20, border_px: int = 6
) -> np.ndarray:
    page = np.full((page_h, page_w, 3), 255, dtype=np.uint8)
    grid_color = (255, 150, 150)
    for x in range(0, page_w, spacing_px):
        page[:, x] = grid_color
    for y in range(0, page_h, spacing_px):
        page[y, :] = grid_color
    # A solid dark border makes the document's edges detectable by Canny —
    # a real printed ECG report typically has a similarly clear frame/edge
    # against whatever background the photo was taken on.
    page[:border_px, :] = (20, 20, 20)
    page[-border_px:, :] = (20, 20, 20)
    page[:, :border_px] = (20, 20, 20)
    page[:, -border_px:] = (20, 20, 20)
    return page


def _warp_onto_skewed_canvas(
    page: np.ndarray, canvas_size: tuple[int, int], skewed_corners: np.ndarray
) -> np.ndarray:
    """Simulate a photo taken at an angle: project a straight page onto a
    larger canvas at the given (already-skewed) corner positions."""
    page_h, page_w = page.shape[:2]
    src = np.array(
        [[0, 0], [page_w - 1, 0], [page_w - 1, page_h - 1], [0, page_h - 1]],
        dtype=np.float32,
    )
    transform = cv2.getPerspectiveTransform(src, skewed_corners.astype(np.float32))
    return cv2.warpPerspective(
        page, transform, canvas_size, borderValue=(120, 120, 120)
    )


def test_find_and_correct_perspective_recovers_known_grid_spacing() -> None:
    known_spacing = 20
    page = _make_straight_page_with_grid(spacing_px=known_spacing)
    page_h, page_w = page.shape[:2]

    # A plausible "photographed at an angle" skew: corners pushed inward by
    # different amounts, well within a larger canvas.
    skewed_corners = np.array(
        [[40, 30], [page_w + 15, 10], [page_w - 10, page_h + 20], [20, page_h - 5]],
        dtype=np.float64,
    )
    canvas = _warp_onto_skewed_canvas(
        page, (page_w + 80, page_h + 80), skewed_corners
    )

    detected_corners = find_document_corners(canvas)
    # Corners should be close to where we actually placed them (order may
    # start from a different point, so compare as sets via nearest-match).
    for corner in skewed_corners:
        nearest_dist = np.min(
            np.linalg.norm(detected_corners - corner, axis=1)
        )
        assert nearest_dist < 15, f"corner {corner} not matched, dist={nearest_dist}"

    corrected = correct_perspective(canvas, detected_corners, (page_w, page_h))
    recovered_spacing = detect_grid_spacing_px(corrected)

    assert abs(recovered_spacing - known_spacing) <= 2


def test_find_document_corners_rejects_image_with_no_clear_document() -> None:
    noise = np.random.default_rng(0).integers(0, 255, (200, 200, 3), dtype=np.uint8)
    with pytest.raises(PerspectiveCorrectionError):
        find_document_corners(noise)
