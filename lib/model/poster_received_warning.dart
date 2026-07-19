class PosterReceivedWarning {
  final String id;
  final String reason;
  final DateTime date;
  final String issuedBy;

  const PosterReceivedWarning({
    required this.id,
    required this.reason,
    required this.date,
    required this.issuedBy,
  });
}