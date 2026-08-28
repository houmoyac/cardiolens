from __future__ import annotations

from pathlib import Path

import numpy as np
import streamlit as st

from cardiolens.models import AlertSeverity, AlertSource
from cardiolens.rules import ESC_DEFAULT, evaluate_rules
from cardiolens.signal_processing import ECGProcessingError, measure_ecg

SAMPLE_DIR = Path(__file__).parent / "sample_ecgs"
SAMPLE_SAMPLING_RATE = 500

SAMPLE_CASES = {
    "ECG normal (PTB-XL #1)": SAMPLE_DIR / "sample_normal_ecg.csv",
    "Bradycardie sinusale (PTB-XL #2)": SAMPLE_DIR / "sample_bradycardia_ecg.csv",
    "Bloc AV 1er degré confirmé (PTB-XL #3017)": SAMPLE_DIR / "sample_pr_long_ecg.csv",
}

st.set_page_config(
    page_title="CardioLens — outil de test interne", page_icon="🫀", layout="centered"
)

st.markdown(
    """
    <style>
    .stApp { background-color: #F5F7FA; }
    .cl-banner {
        background: #FDECEA; border: 1px solid #F3C6BC; border-left: 4px solid #B23B22;
        border-radius: 8px; padding: 12px 16px; margin-bottom: 22px; color: #8A2A17;
        font-size: 13.5px;
    }
    .cl-header { display: flex; align-items: center; gap: 10px; margin-bottom: 2px; }
    .cl-title { font-size: 26px; font-weight: 700; color: #12203A; letter-spacing: -0.3px; }
    .cl-subtitle { color: #6B7686; font-size: 14px; margin-bottom: 28px; }
    .cl-chips {
        display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; margin: 18px 0;
    }
    .cl-chip {
        background: #FFFFFF; border: 1px solid #DCE2EA; border-radius: 10px; padding: 12px 14px;
    }
    .cl-chip.warn { background: #FDECEA; border-color: #F3C6BC; }
    .cl-chip-label { font-size: 11px; color: #8891A0; font-weight: 600; letter-spacing: 0.3px; }
    .cl-chip.warn .cl-chip-label { color: #B23B22; }
    .cl-chip-value {
        font-family: ui-monospace, 'SF Mono', monospace; font-size: 20px; font-weight: 600;
        color: #12203A;
    }
    .cl-chip.warn .cl-chip-value { color: #B23B22; }
    .cl-section-label {
        display: flex; align-items: center; gap: 8px; margin: 22px 0 10px 0;
    }
    .cl-badge {
        font-size: 10.5px; font-weight: 700; letter-spacing: 0.4px; color: #FFFFFF;
        padding: 3px 8px; border-radius: 5px;
    }
    .cl-badge.rule { background: #3B4A63; }
    .cl-badge.ai { background: #5B3E96; }
    .cl-section-title { font-size: 14px; font-weight: 600; color: #12203A; }
    .cl-alert {
        border-radius: 8px; padding: 12px 14px; margin-bottom: 8px; font-size: 13.5px;
        line-height: 1.5;
    }
    .cl-alert.warning {
        background: #FDECEA; border: 1px solid #F3C6BC; border-left: 3px solid #B23B22;
        color: #8A2A17;
    }
    .cl-alert.info {
        background: #F0F3F1; border: 1px solid #DDE6E1; border-left: 3px solid #6B8E7C;
        color: #3A5647;
    }
    </style>
    """,
    unsafe_allow_html=True,
)

st.markdown(
    """
    <div class="cl-banner">⚠️ Outil de test interne, réservé à la validation clinique du concept.
    Ne pas utiliser pour une décision médicale réelle.</div>
    <div class="cl-header">
        <div class="cl-title">🫀 CardioLens</div>
    </div>
    <div class="cl-subtitle">Test du moteur de mesures et de règles cliniques</div>
    """,
    unsafe_allow_html=True,
)

st.markdown("**1. Choisir un ECG à analyser**")
source = st.radio(
    "Source du signal",
    ["Cas réel (PTB-XL)", "Importer un CSV (une colonne de valeurs)"],
    horizontal=True,
    label_visibility="collapsed",
)

signal: np.ndarray | None = None
sampling_rate = SAMPLE_SAMPLING_RATE

if source == "Cas réel (PTB-XL)":
    case_name = st.selectbox("Cas de démonstration", list(SAMPLE_CASES))
    signal = np.loadtxt(SAMPLE_CASES[case_name], delimiter=",").ravel()
    st.caption(
        "Enregistrement réel, anonymisé, issu du dataset public PTB-XL — dérivation DII, 500 Hz. "
        "Aucune donnée patient de ton ami n'est utilisée ici."
    )
else:
    sampling_rate = st.number_input("Fréquence d'échantillonnage (Hz)", value=500, min_value=50)
    uploaded = st.file_uploader("Fichier CSV (une valeur de signal par ligne)")
    if uploaded is not None:
        signal = np.loadtxt(uploaded, delimiter=",").ravel()

sex = st.radio("Sexe (pour le seuil QTc)", ["M", "F"], horizontal=True)

st.markdown("**2. Résultat**")

if signal is None:
    st.info("Choisis un cas réel ou importe un fichier pour lancer l'analyse.")
else:
    if st.button("Analyser", type="primary"):
        try:
            measurements = measure_ecg(signal, sampling_rate=int(sampling_rate))
        except ECGProcessingError as exc:
            st.error(f"Analyse impossible : {exc}")
        else:
            alerts = evaluate_rules(measurements, ESC_DEFAULT, sex=sex)
            qtc_threshold = 460.0 if sex == "F" else 450.0
            qrs_warn = measurements.qrs_duration_ms > 120
            qtc_warn = measurements.qtc_ms > qtc_threshold

            chips_html = f"""
            <div class="cl-chips">
                <div class="cl-chip">
                    <div class="cl-chip-label">FC</div>
                    <div class="cl-chip-value">{measurements.heart_rate_bpm:.0f} bpm</div>
                </div>
                <div class="cl-chip">
                    <div class="cl-chip-label">PR</div>
                    <div class="cl-chip-value">{measurements.pr_interval_ms:.0f} ms</div>
                </div>
                <div class="cl-chip{" warn" if qrs_warn else ""}">
                    <div class="cl-chip-label">QRS</div>
                    <div class="cl-chip-value">{measurements.qrs_duration_ms:.0f} ms</div>
                </div>
                <div class="cl-chip{" warn" if qtc_warn else ""}">
                    <div class="cl-chip-label">QTC</div>
                    <div class="cl-chip-value">{measurements.qtc_ms:.0f} ms</div>
                </div>
            </div>
            """
            st.markdown(chips_html, unsafe_allow_html=True)

            st.markdown(
                '<div class="cl-section-label">'
                '<span class="cl-badge rule">RÈGLE</span>'
                '<span class="cl-section-title">Alertes cliniques — mesures directes</span>'
                "</div>",
                unsafe_allow_html=True,
            )
            for alert in alerts:
                if alert.source != AlertSource.RULE:
                    continue
                css_class = "warning" if alert.severity == AlertSeverity.WARNING else "info"
                st.markdown(
                    f'<div class="cl-alert {css_class}">{alert.message}</div>',
                    unsafe_allow_html=True,
                )

            st.markdown(
                '<div class="cl-section-label">'
                '<span class="cl-badge ai">IA</span>'
                '<span class="cl-section-title">Détection algorithmique</span>'
                "</div>",
                unsafe_allow_html=True,
            )
            st.caption(
                "Aucun modèle IA branché pour l'instant — cette section apparaîtra une fois "
                "le composant de détection (phase 2) ajouté."
            )
