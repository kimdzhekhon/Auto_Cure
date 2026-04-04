/// Record of an automatic code fix applied by the self-healing agent.
class FixRecord {
  final String id;
  final String errorReportId;
  final String description;
  final String filePath;
  final int lineNumber;
  final String originalCode;
  final String fixedCode;
  final FixStatus status;
  final DateTime appliedAt;
  final DateTime? verifiedAt;
  final String? prUrl;
  final List<String> testsRun;
  final bool analysisPassed;
  final String? failureReason;

  FixRecord({
    required this.id,
    required this.errorReportId,
    required this.description,
    required this.filePath,
    required this.lineNumber,
    required this.originalCode,
    required this.fixedCode,
    required this.status,
    required this.appliedAt,
    this.verifiedAt,
    this.prUrl,
    this.testsRun = const [],
    this.analysisPassed = false,
    this.failureReason,
  });

  FixRecord copyWith({
    FixStatus? status,
    DateTime? verifiedAt,
    String? prUrl,
    List<String>? testsRun,
    bool? analysisPassed,
    String? failureReason,
  }) =>
      FixRecord(
        id: id,
        errorReportId: errorReportId,
        description: description,
        filePath: filePath,
        lineNumber: lineNumber,
        originalCode: originalCode,
        fixedCode: fixedCode,
        status: status ?? this.status,
        appliedAt: appliedAt,
        verifiedAt: verifiedAt ?? this.verifiedAt,
        prUrl: prUrl ?? this.prUrl,
        testsRun: testsRun ?? this.testsRun,
        analysisPassed: analysisPassed ?? this.analysisPassed,
        failureReason: failureReason ?? this.failureReason,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'errorReportId': errorReportId,
        'description': description,
        'filePath': filePath,
        'lineNumber': lineNumber,
        'originalCode': originalCode,
        'fixedCode': fixedCode,
        'status': status.name,
        'appliedAt': appliedAt.toIso8601String(),
        'verifiedAt': verifiedAt?.toIso8601String(),
        'prUrl': prUrl,
        'testsRun': testsRun,
        'analysisPassed': analysisPassed,
        'failureReason': failureReason,
      };

  factory FixRecord.fromJson(Map<String, dynamic> json) => FixRecord(
        id: json['id'] as String,
        errorReportId: json['errorReportId'] as String,
        description: json['description'] as String,
        filePath: json['filePath'] as String,
        lineNumber: json['lineNumber'] as int,
        originalCode: json['originalCode'] as String,
        fixedCode: json['fixedCode'] as String,
        status: FixStatus.values.byName(json['status'] as String),
        appliedAt: DateTime.parse(json['appliedAt'] as String),
        verifiedAt: json['verifiedAt'] != null
            ? DateTime.parse(json['verifiedAt'] as String)
            : null,
        prUrl: json['prUrl'] as String?,
        testsRun: List<String>.from(json['testsRun'] as List? ?? []),
        analysisPassed: json['analysisPassed'] as bool? ?? false,
        failureReason: json['failureReason'] as String?,
      );
}

enum FixStatus {
  pending,
  analyzing,
  fixing,
  verifying,
  verified,
  prCreated,
  merged,
  failed,
  rolledBack,
}
