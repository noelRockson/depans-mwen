class ExchangeRateService {
  const ExchangeRateService();

  /// Retourne le taux USD -> HTG courant.
  ///
  /// Implémentation actuelle : valeur mock conforme au fallback du workflow.
  /// À remplacer plus tard par un appel à l'API BRH ou Firestore.
  Future<double> getCurrentUsdToHtgRate() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return 150.0;
  }
}

