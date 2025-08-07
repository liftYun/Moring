// class Notifi {
//   final int    id;
//   final String notificationDetail;
//   final DateTime createdAt;
//   final String message;
//   final bool readFlag;
//
//   Notifi(
//       this.id,
//       required  this.notificationDetail,
//       required this.createdAt,
//       required this.message,
//       required this.readFlag,
//   );
//
//   factory Notifi.fromJson(Map<String, dynamic> json) => Notifi(
//     id:                   json['id'] as int,
//     notificationDetail:   json['notificationDetail'] as String,
//     createdAt:            DateTime.parse(json['createdAt'] as String),  // ← 여기!
//     message:              json['message'] as String,
//     readFlag:             json['readFalg'] as bool,
//   );
// }

class UnreadNotification {
  final int    id;
  final String notificationDetail;
  final DateTime createdAt;
  final String message;

  UnreadNotification({
    required this.id,
    required this.notificationDetail,
    required this.createdAt,
    required this.message,
  });

  factory UnreadNotification.fromJson(Map<String, dynamic> json) => UnreadNotification(
    id:                   json['id'] as int,
    notificationDetail:   json['notificationDetail'] as String,
    createdAt:            DateTime.parse(json['createdAt'] as String),  // ← 여기!
    message:              json['message'] as String,
  );
}
