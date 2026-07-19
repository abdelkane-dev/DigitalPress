enum PaymentMethod { orangeMoney, wave, moovMoney, malitelMoney }

enum PaymentStatus { pending, processing, completed, failed, cancelled }

class Payment {
  final String id;
  final String userId;
  final String journalId;
  final double amount;
  final PaymentMethod method;
  final PaymentStatus status;
  final String? phoneNumber;
  final String? transactionId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? errorMessage;

  Payment({
    required this.id,
    required this.userId,
    required this.journalId,
    required this.amount,
    required this.method,
    required this.status,
    this.phoneNumber,
    this.transactionId,
    required this.createdAt,
    this.completedAt,
    this.errorMessage,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      journalId: json['journal_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      method: _getMethodFromString(json['method'] as String),
      status: _getStatusFromString(json['status'] as String),
      phoneNumber: json['phone_number'] as String?,
      transactionId: json['transaction_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      errorMessage: json['error_message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'journal_id': journalId,
      'amount': amount,
      'method': _getMethodString(method),
      'status': _getStatusString(status),
      'phone_number': phoneNumber,
      'transaction_id': transactionId,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'error_message': errorMessage,
    };
  }

  static PaymentMethod _getMethodFromString(String method) {
    switch (method.toLowerCase()) {
      case 'orange_money':
        return PaymentMethod.orangeMoney;
      case 'wave':
        return PaymentMethod.wave;
      case 'moov_money':
        return PaymentMethod.moovMoney;
      case 'malitel_money':
        return PaymentMethod.malitelMoney;
      default:
        return PaymentMethod.orangeMoney;
    }
  }

  static String _getMethodString(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.orangeMoney:
        return 'orange_money';
      case PaymentMethod.wave:
        return 'wave';
      case PaymentMethod.moovMoney:
        return 'moov_money';
      case PaymentMethod.malitelMoney:
        return 'malitel_money';
    }
  }

  static PaymentStatus _getStatusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return PaymentStatus.pending;
      case 'processing':
        return PaymentStatus.processing;
      case 'completed':
        return PaymentStatus.completed;
      case 'failed':
        return PaymentStatus.failed;
      case 'cancelled':
        return PaymentStatus.cancelled;
      default:
        return PaymentStatus.pending;
    }
  }

  static String _getStatusString(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return 'pending';
      case PaymentStatus.processing:
        return 'processing';
      case PaymentStatus.completed:
        return 'completed';
      case PaymentStatus.failed:
        return 'failed';
      case PaymentStatus.cancelled:
        return 'cancelled';
    }
  }

  Payment copyWith({
    String? id,
    String? userId,
    String? journalId,
    double? amount,
    PaymentMethod? method,
    PaymentStatus? status,
    String? phoneNumber,
    String? transactionId,
    DateTime? createdAt,
    DateTime? completedAt,
    String? errorMessage,
  }) {
    return Payment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      journalId: journalId ?? this.journalId,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
