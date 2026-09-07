/// Configuration passed to [Openpanel.initialize].
///
/// Mirrors the options of the official OpenPanel mobile SDKs: cloud projects
/// work with just a [clientId], self-hosted instances additionally need an
/// [apiUrl].
class OpenpanelOptions {
  /// Creates OpenPanel configuration.
  const OpenpanelOptions({
    required this.clientId,
    this.clientSecret,
    this.apiUrl = defaultApiUrl,
    this.automaticTracking = true,
    this.disabled = false,
    this.verbose = false,
  });

  /// Default endpoint of the OpenPanel cloud API.
  static const String defaultApiUrl = 'https://api.openpanel.dev';

  /// The client ID of your OpenPanel project.
  ///
  /// Find it in your OpenPanel dashboard under Settings → General.
  final String clientId;

  /// The client secret of your OpenPanel project.
  ///
  /// Optional: the track endpoint works without it. A secret embedded in a
  /// mobile app is public anyway, so prefer leaving this empty.
  final String? clientSecret;

  /// Base URL of the OpenPanel API.
  ///
  /// Point this to your self-hosted instance (e.g.
  /// `https://openpanel.example.com`) when not using the OpenPanel cloud.
  final String apiUrl;

  /// Whether `app_opened` and `app_closed` events are tracked automatically
  /// on app lifecycle transitions.
  ///
  /// Defaults to `true`.
  final bool automaticTracking;

  /// Disables all collection. Events are dropped and nothing is sent.
  ///
  /// Useful for honoring user consent or debug builds. Defaults to `false`.
  final bool disabled;

  /// Enables verbose native logging of every queued and sent event.
  ///
  /// Defaults to `false`.
  final bool verbose;

  /// Serializes the options for the platform channel.
  Map<String, Object?> toMap() => <String, Object?>{
        'clientId': clientId,
        'clientSecret': clientSecret,
        'apiUrl': apiUrl,
        'automaticTracking': automaticTracking,
        'disabled': disabled,
        'verbose': verbose,
      };
}
