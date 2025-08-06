class MoringNotification {
  final DateTime created_at;
  final String message;
  final String notification_detail;
  final String notification_type;
  final bool read_flag;

  MoringNotification({
    required this.created_at,
    required this.message,
    required this.notification_detail,
    required this.notification_type,
    required this.read_flag,
  });

  factory MoringNotification.fromJson(Map<String, dynamic> json) {
    return MoringNotification(
        created_at: json['created_at'],
        message: json['message'],
        notification_detail: json['notification_detail'],
        notification_type: json['notification_type'],
        read_flag: json['read_flag']);
  }
}