class Conversation {
  final String id;
  final String title;
  final String fileId;
  final DateTime createdAt;
  final int size;
  final bool isVideo;
  String? summary;
  String? responsibilities;
  String? transcript;

  Conversation({
    required this.id,
    required this.title,
    required this.fileId,
    required this.createdAt,
    required this.size,
    required this.isVideo,
    this.summary,
    this.responsibilities,
    this.transcript,
  });

  String get videoUrl => 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media';
  String get audioUrl => 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media';

  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'fileId': fileId,
      'createdAt': createdAt.toIso8601String(),
      'size': size,
      'isVideo': isVideo,
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
      size: json['size'] as int,
      isVideo: json['isVideo'] as bool,
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
    int? size,
    bool? isVideo,
    String? summary,
    String? responsibilities,
    String? transcript,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      fileId: fileId ?? this.fileId,
      createdAt: createdAt ?? this.createdAt,
      size: size ?? this.size,
      isVideo: isVideo ?? this.isVideo,
      summary: summary ?? this.summary,
      responsibilities: responsibilities ?? this.responsibilities,
      transcript: transcript ?? this.transcript,
    );
  }
} 