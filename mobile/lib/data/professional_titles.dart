/// Presets for the "profession / titre" field on the login/register form
/// and the profile screen. Free text always wins over this list — "Autre"
/// lets a doctor type anything the list doesn't cover, and the backend
/// never validates against a closed set (see auth_models.User.
/// professional_title on the backend).
const List<String> professionalTitlePresets = [
  'Médecin stagiaire',
  'Interne',
  'Résident',
  'Assistant',
  'Maître assistant',
  'Professeur agrégé',
  'Professeur',
  'Médecin généraliste',
  'Médecin spécialiste',
];

const String professionalTitleOtherValue = '__other__';
