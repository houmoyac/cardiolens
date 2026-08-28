# CardioLens

Aide à l'interprétation ECG pour médecins. **Outil d'aide à la décision,
pas un dispositif de diagnostic autonome** — toute sortie doit être validée
par un médecin avant tout usage clinique.

## Statut

Preuve de concept. Moteur de mesures + règles cliniques uniquement pour
l'instant (pas de composant IA/ML — voir `backend/src/cardiolens/`).
Testé uniquement sur des ECG simulés/publics, jamais sur des données
patients réelles.

## Architecture

```
backend/   API Python (FastAPI) — traitement du signal, règles cliniques
```

Le moteur de règles utilise des seuils regroupés par "guideline"
(`GuidelineThresholds`), pensés pour être remplacés/étendus par région
plutôt que codés en dur — utile le jour où on veut suivre un autre
référentiel que l'ESC.

## Backend — démarrer en local

```bash
cd backend
uv sync --all-groups
uv run pytest
uv run uvicorn cardiolens.api:app --reload
```

`POST /analyze` prend un signal ECG mono-dérivation (liste de floats) et une
fréquence d'échantillonnage, renvoie les mesures (FC, PR, QRS, QTc) et les
alertes cliniques associées.

## Prochaines étapes

- Détection IA en complément sur les cas non couverts par les règles
  (fibrillation atriale, ischémie)
- Calcul de l'axe électrique (nécessite les dérivations I et aVF)
- App mobile Flutter (iOS/Android)
- Validation clinique par un médecin sur un jeu d'ECG variés avant tout
  usage réel
