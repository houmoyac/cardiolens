from __future__ import annotations

import io

import numpy as np
import pytest

from cardiolens.io_utils import load_signal_from_csv


def test_load_single_column_no_header() -> None:
    signal = load_signal_from_csv("0.1\n0.2\n0.3\n")
    np.testing.assert_allclose(signal, [0.1, 0.2, 0.3])


def test_load_two_columns_with_header() -> None:
    """The exact shape that broke the tool in practice: a "time_seconds,
    lead_II_mV" header followed by (time, amplitude) rows."""
    csv_text = (
        "time_seconds,lead_II_mV\n"
        "0.0,0.002438\n"
        "0.002,-0.008237\n"
        "0.004,0.006169\n"
    )
    signal = load_signal_from_csv(csv_text)
    np.testing.assert_allclose(signal, [0.002438, -0.008237, 0.006169])


def test_load_from_file_like_bytes() -> None:
    file = io.BytesIO(b"1.0\n2.0\n3.0\n")
    signal = load_signal_from_csv(file)
    np.testing.assert_allclose(signal, [1.0, 2.0, 3.0])


def test_load_rejects_empty_or_non_numeric_content() -> None:
    with pytest.raises(ValueError):
        load_signal_from_csv("only,text,here\nno,numbers,at,all\n")
