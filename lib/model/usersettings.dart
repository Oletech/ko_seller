class UserSettings {
  final String? language;
  final String? currency;
  final bool? appNotifications;
  final bool? darkModeTheme;

  const UserSettings({
    this.language = 'English',
    this.currency = 'TZS',
    this.appNotifications = true,
    this.darkModeTheme = false,
  });

  UserSettings copy({
    String? lang,
    String? currency,
    bool? notification,
    bool? display,
  }) =>
      UserSettings(
        language: lang ?? this.language,
        currency: currency ?? this.currency,
        appNotifications: notification ?? this.appNotifications,
        darkModeTheme: display ?? this.darkModeTheme,
      );

  static UserSettings fromJson(Map<String, dynamic> json) => UserSettings(
        language: json['language'],
        currency: json['currency'],
        appNotifications: json['appNotifications'],
        darkModeTheme: json['darkModeTheme'],
      );

  Map<String, dynamic> toJson() => {
        'language': language,
        'currency': currency,
        'appNotifications': appNotifications,
        'darkModeTheme': darkModeTheme,
      };
}
