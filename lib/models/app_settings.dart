class AppSettings {
  final bool clearPathOnMaxRetry;
  final bool mapShowRepeaters;
  final bool mapShowChatNodes;
  final bool mapShowOtherNodes;
  final double mapTimeFilterHours; // 0 = all time
  final bool mapKeyPrefixEnabled;
  final String mapKeyPrefix;
  final bool mapShowMarkers;
  final bool notificationsEnabled;
  final bool notifyOnNewMessage;
  final bool notifyOnNewAdvert;
  final bool autoRouteRotationEnabled;
  final String themeMode;
  final Map<String, String> batteryChemistryByDeviceId;

  AppSettings({
    this.clearPathOnMaxRetry = false,
    this.mapShowRepeaters = true,
    this.mapShowChatNodes = true,
    this.mapShowOtherNodes = true,
    this.mapTimeFilterHours = 0, // Default to all time
    this.mapKeyPrefixEnabled = false,
    this.mapKeyPrefix = '',
    this.mapShowMarkers = true,
    this.notificationsEnabled = true,
    this.notifyOnNewMessage = true,
    this.notifyOnNewAdvert = true,
    this.autoRouteRotationEnabled = false,
    this.themeMode = 'system',
    Map<String, String>? batteryChemistryByDeviceId,
  }) : batteryChemistryByDeviceId = batteryChemistryByDeviceId ?? {};

  Map<String, dynamic> toJson() {
    return {
      'clear_path_on_max_retry': clearPathOnMaxRetry,
      'map_show_repeaters': mapShowRepeaters,
      'map_show_chat_nodes': mapShowChatNodes,
      'map_show_other_nodes': mapShowOtherNodes,
      'map_time_filter_hours': mapTimeFilterHours,
      'map_key_prefix_enabled': mapKeyPrefixEnabled,
      'map_key_prefix': mapKeyPrefix,
      'map_show_markers': mapShowMarkers,
      'notifications_enabled': notificationsEnabled,
      'notify_on_new_message': notifyOnNewMessage,
      'notify_on_new_advert': notifyOnNewAdvert,
      'auto_route_rotation_enabled': autoRouteRotationEnabled,
      'theme_mode': themeMode,
      'battery_chemistry_by_device_id': batteryChemistryByDeviceId,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      clearPathOnMaxRetry: json['clear_path_on_max_retry'] as bool? ?? false,
      mapShowRepeaters: json['map_show_repeaters'] as bool? ?? true,
      mapShowChatNodes: json['map_show_chat_nodes'] as bool? ?? true,
      mapShowOtherNodes: json['map_show_other_nodes'] as bool? ?? true,
      mapTimeFilterHours: (json['map_time_filter_hours'] as num?)?.toDouble() ?? 0,
      mapKeyPrefixEnabled: json['map_key_prefix_enabled'] as bool? ?? false,
      mapKeyPrefix: json['map_key_prefix'] as String? ?? '',
      mapShowMarkers: json['map_show_markers'] as bool? ?? true,
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      notifyOnNewMessage: json['notify_on_new_message'] as bool? ?? true,
      notifyOnNewAdvert: json['notify_on_new_advert'] as bool? ?? true,
      autoRouteRotationEnabled: json['auto_route_rotation_enabled'] as bool? ?? false,
      themeMode: json['theme_mode'] as String? ?? 'system',
      batteryChemistryByDeviceId: (json['battery_chemistry_by_device_id'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          {},
    );
  }

  AppSettings copyWith({
    bool? clearPathOnMaxRetry,
    bool? mapShowRepeaters,
    bool? mapShowChatNodes,
    bool? mapShowOtherNodes,
    double? mapTimeFilterHours,
    bool? mapKeyPrefixEnabled,
    String? mapKeyPrefix,
    bool? mapShowMarkers,
    bool? notificationsEnabled,
    bool? notifyOnNewMessage,
    bool? notifyOnNewAdvert,
    bool? autoRouteRotationEnabled,
    String? themeMode,
    Map<String, String>? batteryChemistryByDeviceId,
  }) {
    return AppSettings(
      clearPathOnMaxRetry: clearPathOnMaxRetry ?? this.clearPathOnMaxRetry,
      mapShowRepeaters: mapShowRepeaters ?? this.mapShowRepeaters,
      mapShowChatNodes: mapShowChatNodes ?? this.mapShowChatNodes,
      mapShowOtherNodes: mapShowOtherNodes ?? this.mapShowOtherNodes,
      mapTimeFilterHours: mapTimeFilterHours ?? this.mapTimeFilterHours,
      mapKeyPrefixEnabled: mapKeyPrefixEnabled ?? this.mapKeyPrefixEnabled,
      mapKeyPrefix: mapKeyPrefix ?? this.mapKeyPrefix,
      mapShowMarkers: mapShowMarkers ?? this.mapShowMarkers,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notifyOnNewMessage: notifyOnNewMessage ?? this.notifyOnNewMessage,
      notifyOnNewAdvert: notifyOnNewAdvert ?? this.notifyOnNewAdvert,
      autoRouteRotationEnabled: autoRouteRotationEnabled ?? this.autoRouteRotationEnabled,
      themeMode: themeMode ?? this.themeMode,
      batteryChemistryByDeviceId: batteryChemistryByDeviceId ?? this.batteryChemistryByDeviceId,
    );
  }
}
