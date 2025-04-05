class Conversation {
  final String id;
  final String title;
  final String fileId;
  final DateTime createdAt;
  String? summary;
  String? responsibilities;
  String? transcript;

  Conversation({
    required this.id,
    required this.title,
    required this.fileId,
    required this.createdAt,
    this.summary,
    this.responsibilities,
    this.transcript,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'fileId': fileId,
      'createdAt': createdAt.toIso8601String(),
      'summary': summary,
      'responsibilities': responsibilities,
      'transcript': transcript,
    };
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String,
      fileId: json['fileId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      summary: json['summary'] as String?,
      responsibilities: json['responsibilities'] as String?,
      transcript: json['transcript'] as String?,
    );
  }

  Conversation copyWith({
    String? id,
    String? title,
    String? fileId,
    DateTime? createdAt,
    String? summary,
    String? responsibilities,
    String? transcript,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      fileId: fileId ?? this.fileId,
      createdAt: createdAt ?? this.createdAt,
      summary: summary ?? this.summary,
      responsibilities: responsibilities ?? this.responsibilities,
      transcript: transcript ?? this.transcript,
    );
  }
} 