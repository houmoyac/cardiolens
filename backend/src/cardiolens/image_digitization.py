from __future__ import annotations

import cv2
import numpy as np
import pytesseract
from numpy.typing import NDArray
from PIL import Image
from scipy.ndimage import uniform_filter1d
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

    Real ECG images can contain other dark features besides the trace — a
    bold grid line or a panel border, for instance (found empirically: a
    persistent dark row at a fixed height was pulling the recovered trace
    toward it in every column, since a naive "mean of all dark pixels"
    doesn't distinguish a stationary decoy from the moving trace). Rows
    that are dark in almost every column are excluded before picking each
    column's trace position — the trace moves, a border/grid line doesn't.

    KNOWN PARTIALLY-ADDRESSED ISSUE (see ARCHITECTURE.md): a lead label
    printed inside the panel ("aVR", "V2", ...) can corrupt the trace near
    where it sits. A connected-component filter meant to drop small
    label-sized blobs was tried first and reverted — real (if
    low-quality/compressed) images fragment the genuine trace into pieces
    similar in size to label text, so shape alone couldn't tell them
    apart. `mask_text_regions` takes a different approach (OCR: is this
    actually text) and is a real improvement on synthetic tests, but call
    it explicitly before this function if wanted — it is NOT applied
    automatically here, and has not yet been validated on a real, noisy
    phone photo.
    """
    if image.ndim == 3:
        gray = np.asarray(Image.fromarray(image).convert("L"), dtype=np.float64)
    else:
        gray = image.astype(np.float64)

    is_dark = gray < dark_threshold
    persistent_rows = np.where(is_dark.mean(axis=1) > 0.85)[0]

    width = gray.shape[1]
    ys = np.full(width, np.nan)

    for x in range(width):
        clusters = [
            c
            for c in _find_dark_clusters(is_dark[:, x])
            if not _near_any_row(c[0], persistent_rows)
        ]
        if not clusters:
            continue
        # The largest remaining cluster — more likely the genuine stroke
        # than a thin antialiasing sliver.
        ys[x] = max(clusters, key=lambda c: c[1])[0]

    return ys


def _find_dark_clusters(is_dark_col: NDArray[np.bool_]) -> list[tuple[float, int]]:
    """Contiguous runs of True in a 1D boolean array, as (centroid, size)."""
    clusters: list[tuple[float, int]] = []
    start: int | None = None
    for i, dark in enumerate(is_dark_col):
        if dark and start is None:
            start = i
        elif not dark and start is not None:
            clusters.append(((start + i - 1) / 2.0, i - start))
            start = None
    if start is not None:
        clusters.append(((start + len(is_dark_col) - 1) / 2.0, len(is_dark_col) - start))
    return clusters


def _near_any_row(row: float, rows: NDArray[np.intp], tolerance_px: float = 2.0) -> bool:
    return bool(rows.size) and bool(np.any(np.abs(rows - row) <= tolerance_px))


def mask_text_regions(
    image: NDArray[np.uint8], min_confidence: int = 40, padding_px: int = 3
) -> NDArray[np.uint8]:
    """Paint over OCR-detected text (lead labels like "aVR", "V2") with the
    background color, so `extract_trace_from_image` never sees it.

    Why OCR, after a size/shape-based filter was tried and reverted (see
    ARCHITECTURE.md and `extract_trace_from_image`'s docstring): the
    earlier attempt tried to distinguish label text from trace by how the
    dark pixels were *shaped* (component size, then width+height) — and
    failed, because a real trace fragments (JPEG compression, thin
    strokes) into pieces the same size as label characters. OCR instead
    asks "is this actually text", which is the real distinguishing
    question a shape heuristic could only approximate. Still not
    guaranteed on a real, noisy phone photo — never claimed to be a full
    fix, just the more targeted approach — so this stays a separate,
    optional preprocessing step rather than being folded silently into
    `extract_trace_from_image`, and every masked case should still be
    checked against a real image before being trusted.

    A SPECIFIC FAILURE MODE FOUND WHILE TESTING THIS, not a hypothetical:
    when a label's glyphs visually cross the trace stroke itself (as
    opposed to just sitting in the same column range), tesseract's own
    character recognition gets confused by the curve line cutting through
    the letters and can fail to detect the text at all — meaning masking
    silently does nothing in exactly that case. Confirmed with the same
    "aVR" string, same font/size: read correctly (confidence ~87) in
    isolation or placed a few pixels away from the stroke, but returned
    empty when the stroke crossed through a letter. This is arguably the
    worst case to miss (a label overlapping a QRS complex), not a rare
    corner case — see the regression test in test_image_digitization.py
    for the exact placement that does and doesn't work.

    Never mutates the input; returns a copy.
    """
    gray = np.asarray(Image.fromarray(image).convert("L")) if image.ndim == 3 else image
    # Same background estimate as detect_grid_color: paper is the brightest
    # population by far, so a high percentile is a safe "blend in" fill.
    background_level = int(np.percentile(gray, 90))

    result = image.copy()
    fill = (background_level,) * 3 if image.ndim == 3 else background_level

    ocr_data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT)
    height, width = gray.shape[:2]
    for i, text in enumerate(ocr_data["text"]):
        if not text.strip():
            continue
        confidence = int(ocr_data["conf"][i])
        if confidence < min_confidence:
            continue

        x, y, w, h = (
            ocr_data["left"][i],
            ocr_data["top"][i],
            ocr_data["width"][i],
            ocr_data["height"][i],
        )
        x0 = max(0, x - padding_px)
        y0 = max(0, y - padding_px)
        x1 = min(width, x + w + padding_px)
        y1 = min(height, y + h + padding_px)
        result[y0:y1, x0:x1] = fill

    return result


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


def detect_grid_color(
    image: NDArray[np.uint8],
) -> tuple[tuple[int, int, int], int]:
    """Estimate the grid's color and a matching tolerance, instead of
    assuming a fixed one — found necessary in practice: a real ECG image
    tested against this pipeline turned out to use a gray grid, not the
    red/pink assumed by default (see ARCHITECTURE.md).

    Approach: background (paper) is the most common — brightest — color by
    far; ink (the trace) is a small population of the darkest pixels. The
    grid is whatever mid-tone color remains once both are excluded — not
    the background's peak brightness, not among the darkest few percent.
    Returns the median color of that remaining population, and a tolerance
    sized to its spread (so a fainter or heavier-printed grid still
    matches consistently on the next call to `detect_grid_spacing_px`).
    """
    gray = (
        np.asarray(Image.fromarray(image).convert("L"), dtype=np.float64)
        if image.ndim == 3
        else image.astype(np.float64)
    )
    rgb = image if image.ndim == 3 else np.stack([image] * 3, axis=-1)

    background_level = float(np.percentile(gray, 90))
    # The true minimum, not a low percentile: the trace can be a thin
    # enough stroke (well under 1% of pixels) that a percentile-based
    # threshold lands inside the grid's own population instead of black
    # ink — found by an actual test failure, not a hypothetical.
    ink_level = float(gray.min())
    mid_tone = (gray > ink_level + 10) & (gray < background_level - 5)

    if not np.any(mid_tone):
        raise GridDetectionError(
            "Aucune couleur intermédiaire (ni fond, ni encre) trouvée dans "
            "l'image — impossible d'estimer la couleur de la grille."
        )

    candidates = rgb[mid_tone].astype(np.float64)
    median_color = tuple(int(round(v)) for v in np.median(candidates, axis=0))
    spread = float(np.median(np.abs(candidates - np.median(candidates, axis=0))))
    tolerance = max(20, int(round(spread * 3)))

    return median_color, tolerance  # type: ignore[return-value]


def detect_grid_spacing_px(
    image: NDArray[np.uint8],
    grid_rgb: tuple[int, int, int] | None = None,
    tolerance: int | None = None,
) -> float:
    """Estimate the pixel spacing between regular grid lines.

    If `grid_rgb`/`tolerance` aren't given, both are estimated first via
    `detect_grid_color` — pass them explicitly only when the color is
    already known (e.g. re-checking a specific hypothesis, or in a test).

    Assumes a square grid (equal horizontal/vertical spacing in real mm) —
    true for standard ECG paper — and estimates spacing from the more
    reliably visible axis via autocorrelation of the grid-colored pixel
    count per column. Only the horizontal (time) axis is used here since a
    typical strip is much wider than tall, giving more periods to lock
    onto; assuming a square grid, the same spacing applies vertically.
    """
    if grid_rgb is None or tolerance is None:
        detected_rgb, detected_tolerance = detect_grid_color(image)
        grid_rgb = grid_rgb if grid_rgb is not None else detected_rgb
        tolerance = tolerance if tolerance is not None else detected_tolerance

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


def segment_grid_panels(
    image: NDArray[np.uint8],
    rows: int,
    cols: int,
    search_margin_frac: float = 0.15,
) -> list[list[NDArray[np.uint8]]]:
    """Split a full ECG page into `rows` x `cols` single-lead panels.

    Assumes the standard clinical layout — leads arranged in a regular
    grid (typically 6x2: I/II/III/aVR/aVL/aVF | V1-V6). Naive equal
    division would misalign panels whose margins aren't pixel-identical,
    so each boundary is refined by searching, within a margin around its
    naive position, for the row/column with the least ink — the real gap
    between panels. Still assumes a clean, axis-aligned page: no
    perspective correction happens here.

    The "least ink" search is high-pass filtered first (see
    `_refine_grid_boundaries`) — found necessary on a real wrinkled
    photo, where a wrinkle's shadow (a slow, broad gradient) pulled the
    naive raw-ink search toward itself instead of the real gap. Verified
    to shift the boundary in the right direction on that real image
    (see ARCHITECTURE.md for the before/after numbers) and to not
    regress any existing test, including on a clean multi-panel page.
    **Not a full fix**, stated plainly: on that same real image, the
    corrected boundary still didn't fully realign the panel, because
    real full-page scans commonly include a header/patient-info margin
    that "naive equal division into rows" doesn't account for at all —
    a distinct, deeper issue than the shadow this change addresses.
    """
    if image.ndim == 3:
        gray = np.asarray(Image.fromarray(image).convert("L"), dtype=np.float64)
    else:
        gray = image.astype(np.float64)
    ink = 255.0 - gray  # higher value = more ink (trace or grid) at that pixel

    row_bounds = _refine_grid_boundaries(ink.sum(axis=1), rows, search_margin_frac)
    col_bounds = _refine_grid_boundaries(ink.sum(axis=0), cols, search_margin_frac)

    return [
        [
            image[row_bounds[r] : row_bounds[r + 1], col_bounds[c] : col_bounds[c + 1]]
            for c in range(cols)
        ]
        for r in range(rows)
    ]


def _refine_grid_boundaries(
    profile: NDArray[np.float64], count: int, search_margin_frac: float
) -> list[int]:
    n = len(profile)
    naive = [round(i * n / count) for i in range(count + 1)]

    # High-pass the ink profile before searching for the least-inked line:
    # a real panel gap is a SHARP, narrow dip, but a photographed page's
    # wrinkle/lighting gradients are slow, wide swings that can otherwise
    # dominate the raw ink sum and pull the "least ink" search toward a
    # shadow instead of the real gap (found on a real wrinkled photo, not
    # hypothetical — see ARCHITECTURE.md). Subtracting a heavily smoothed
    # copy of the profile removes slow gradients while leaving sharp
    # local dips (and the true trace/grid content) intact.
    margin = max(1, int(n / count * search_margin_frac))
    # Sized relative to the search margin, not the panel size: too small
    # and the smoothed baseline still tracks the sharp dip we want to
    # keep (no effective high-pass at all); too large (tried n // count
    # first) and it tracks the whole search window just as closely,
    # which is equally a no-op — found empirically, not assumed, by
    # sweeping window sizes against the real wrinkled test image in
    # ARCHITECTURE.md.
    smoothed = uniform_filter1d(profile, size=max(3, margin * 2), mode="nearest")
    highpassed = profile - smoothed

    refined = [naive[0]]
    for i in range(1, count):
        lo, hi = max(0, naive[i] - margin), min(n, naive[i] + margin)
        window = highpassed[lo:hi]
        refined.append(lo + int(np.argmin(window)))
    refined.append(naive[-1])

    return refined


class PerspectiveCorrectionError(RuntimeError):
    """Raised when no plausible document quadrilateral can be found — never
    guess corners, since a wrong perspective transform distorts the whole
    page's geometry (and therefore every calibration built on it) in a way
    that looks like a normal photo, not an obvious failure."""


def find_document_corners(image: NDArray[np.uint8]) -> NDArray[np.float64]:
    """Locate the four corners of the (roughly rectangular) document in a
    photo, assuming it stands out against its background — the strongest
    edge contour in the image. Returns corners ordered
    [top-left, top-right, bottom-right, bottom-left].
    """
    gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY) if image.ndim == 3 else image
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    edges = cv2.Canny(blurred, 50, 150)
    edges = cv2.dilate(edges, np.ones((5, 5), np.uint8), iterations=1)

    contours, _ = cv2.findContours(edges, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        raise PerspectiveCorrectionError(
            "Aucun contour de document détecté dans l'image."
        )

    largest = max(contours, key=cv2.contourArea)
    perimeter = cv2.arcLength(largest, True)
    approx = cv2.approxPolyDP(largest, 0.02 * perimeter, True)

    if len(approx) != 4:
        raise PerspectiveCorrectionError(
            f"Le plus grand contour a {len(approx)} coins, pas 4 — le "
            "document n'est probablement pas clairement isolé du fond."
        )
    if not cv2.isContourConvex(approx):
        raise PerspectiveCorrectionError(
            "Le contour détecté n'est pas convexe — probablement du bruit, "
            "pas un vrai contour de document."
        )

    # A genuine document edge is close to its own bounding rectangle; a
    # jagged blob from image noise generally isn't, even if it happens to
    # approximate to 4 points. Rejects exactly the noise-image false
    # positive this check exists for.
    _, _, bbox_w, bbox_h = cv2.boundingRect(approx)
    extent = cv2.contourArea(approx) / (bbox_w * bbox_h)
    if extent < 0.7:
        raise PerspectiveCorrectionError(
            f"Le contour détecté ne remplit que {extent:.0%} de son "
            "rectangle englobant — pas assez rectangulaire pour être un "
            "document."
        )

    # A contour spanning almost the entire frame is usually a sign nothing
    # real was isolated (dense edge noise merges into one blob touching
    # every border) rather than a genuine photographed document, which
    # normally leaves some background margin visible.
    image_area = gray.shape[0] * gray.shape[1]
    if (bbox_w * bbox_h) > 0.95 * image_area:
        raise PerspectiveCorrectionError(
            "Le contour détecté couvre la quasi-totalité de l'image — "
            "probablement pas un document isolé de son fond."
        )

    return _order_corners(approx.reshape(4, 2).astype(np.float64))


def _order_corners(corners: NDArray[np.float64]) -> NDArray[np.float64]:
    """Order 4 arbitrary corner points as
    [top-left, top-right, bottom-right, bottom-left].

    The standard sum/difference trick (not angle sorting, which is easy to
    get backwards in image coordinates where y grows downward): the
    top-left point has the smallest x+y, bottom-right the largest; the
    top-right point has the smallest y-x, bottom-left the largest.
    """
    s = corners.sum(axis=1)
    diff = corners[:, 1] - corners[:, 0]

    top_left = corners[np.argmin(s)]
    bottom_right = corners[np.argmax(s)]
    top_right = corners[np.argmin(diff)]
    bottom_left = corners[np.argmax(diff)]

    return np.array([top_left, top_right, bottom_right, bottom_left])


def correct_perspective(
    image: NDArray[np.uint8],
    corners: NDArray[np.float64],
    output_size: tuple[int, int],
) -> NDArray[np.uint8]:
    """Warp the document defined by `corners` (ordered as returned by
    `find_document_corners`) to a flat, axis-aligned `output_size`
    (width, height) image."""
    width, height = output_size
    destination = np.array(
        [[0, 0], [width - 1, 0], [width - 1, height - 1], [0, height - 1]],
        dtype=np.float64,
    )
    transform = cv2.getPerspectiveTransform(
        corners.astype(np.float32), destination.astype(np.float32)
    )
    warped = cv2.warpPerspective(image, transform, (width, height))
    return warped.astype(np.uint8)
