from __future__ import annotations

import neurokit2 as nk
import numpy as np
import streamlit as st

from cardiolens.models import AlertSeverity, AlertSource
from cardiolens.rules import ESC_DEFAULT, evaluate_rules
from cardiolens.signal_processing import ECGProcessingError, measure_ecg

st.set_page_config(page_title="CardioLens — outil de test interne", page_icon="🫀")

st.warning(
    "Outil de test interne, réservé à la validation clinique du concept. "
    "Ne pas utiliser pour une décision médicale réelle.",
    icon="⚠️",
)
st.title("CardioLens — test du moteur de mesures et de règles")

SAMPLE_CASES = {
    "Rythme normal (~75 bpm)": {"heart_rate": 75, "random_state": 1},
    "Bradycardie (~45 bpm)": {"heart_rate": 45, "random_state": 2},
    "Tachycardie (~130 bpm)": {"heart_rate": 130, "random_state": 3},
}

st.subheader("1. Choisir un ECG à analyser")
source = st.radio(
    "Source du signal",
    ["Cas simulé (démo)", "Importer un CSV (une colonne de valeurs)"],
    horizontal=True,
)

signal: np.ndarray | None = None
sampling_rate = 500

if source == "Cas simulé (démo)":
    case_name = st.selectbox("Cas de démonstration", list(SAMPLE_CASES))
    params = SAMPLE_CASES[case_name]
    signal = np.asarray(
        nk.ecg_simulate(
            duration=10,
            sampling_rate=sampling_rate,
            heart_rate=params["heart_rate"],
            method="ecgsyn",
            random_state=params["random_state"],
        )
    )
    st.caption(
        "Signal synthétique généré pour la démo — pas un vrai patient. "
        "Sert uniquement à vérifier que le moteur détecte le bon ordre de grandeur."
    )
else:
    sampling_rate = st.number_input("Fréquence d'échantillonnage (Hz)", value=500, min_value=50)
    uploaded = st.file_uploader("Fichier CSV (une valeur de signal par ligne)")
    if uploaded is not None:
        signal = np.loadtxt(uploaded, delimiter=",").ravel()

sex = st.radio("Sexe (pour le seuil QTc)", ["M", "F"], horizontal=True)

st.subheader("2. Résultat")

if signal is None:
    st.info("Choisis un cas de démo ou importe un fichier pour lancer l'analyse.")
else:
    if st.button("Analyser", type="primary"):
        try:
            measurements = measure_ecg(signal, sampling_rate=int(sampling_rate))
        except ECGProcessingError as exc:
            st.error(f"Analyse impossible : {exc}")
        else:
            cols = st.columns(4)
            cols[0].metric("FC", f"{measurements.heart_rate_bpm:.0f} bpm")
            cols[1].metric("PR", f"{measurements.pr_interval_ms:.0f} ms")
            cols[2].metric("QRS", f"{measurements.qrs_duration_ms:.0f} ms")
            cols[3].metric("QTc", f"{measurements.qtc_ms:.0f} ms")

            alerts = evaluate_rules(measurements, ESC_DEFAULT, sex=sex)

            st.markdown("**Alertes cliniques (mesures directes — RÈGLE)**")
            for alert in alerts:
                if alert.source != AlertSource.RULE:
                    continue
                if alert.severity == AlertSeverity.WARNING:
                    st.error(alert.message)
                else:
                    st.success(alert.message)

            st.caption(
                "Aucune détection IA pour l'instant — uniquement des mesures directes "
                "et des règles à seuils publiés (voir README)."
            )
