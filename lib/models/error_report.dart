/// Runtime error report captured from the Flutter VM service.
class ErrorReport {
  final String id;
  final String errorType;
  final String message;
  final String stackTrace;
  final String? widgetPath;
  final String? sourceFile;
  final int? sourceLine;
  final ErrorSeverity severity;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  ErrorReport({
    required this.id,
    required this.errorType,
    required this.message,
    required this.stackTrace,
    this.widgetPath,
    this.sourceFile,
    this.sourceLine,
    required this.severity,
    required this.timestamp,
    this.metadata = const {},
  });

  bool get isLayoutOverflow =>
      errorType.contains('RenderFlex') ||
      message.contains('overflowed') ||
      message.contains('RenderFlex');

  bool get isRenderError => errorType.startsWith('Render');

  Map<String, dynamic> toJson() => {
        'id': id,
        'errorType': errorType,
        'message': message,
        'stackTrace': stackTrace,
        'widgetPath': widgetPath,
        'sourceFile': sourceFile,
        'sourceLine': sourceLine,
        'severity': severity.name,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };

  factory ErrorReport.fromJson(Map<String, dynamic> json) => ErrorReport(
        id: json['id'] as String,
        errorType: json['errorType'] as String,
        message: json['message'] as String,
        stackTrace: json['stackTrace'] as String,
        widgetPath: json['widgetPath'] as String?,
        sourceFile: json['sourceFile'] as String?,
        sourceLine: json['sourceLine'] as int?,
        severity: ErrorSeverity.values.byName(json['severity'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
        metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      );
}

enum ErrorSeverity { low, medium, high, critical }
