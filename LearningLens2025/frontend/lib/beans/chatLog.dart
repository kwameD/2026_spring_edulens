// Represents permanent tokens for a chat session
class PermTokens {
  final String core; // permanent system instructions
  final List<String> modules; // optional extra system snippets

  PermTokens({
    String? core,
    List<String> modules = const [],
  })  : core = (core == null || core.trim().isEmpty)
            ? 'You are LearningLens, an AI assistant designed to help Students and teachers learn and understand complex topics. You provide clear, concise, and accurate information in a friendly and approachable manner. Always aim to enhance the user\'s learning or teaching experience.'
            : core,
        modules = modules;
}

// Represents a single turn in a chat conversation
class ChatTurn {
  final String role; // 'user' | 'assistant' | 'system'
  final String? content;
  final DateTime? timestamp;
  final int? roundNumber;

  const ChatTurn(
      {required this.role,
      required this.content,
      this.timestamp,
      this.roundNumber});

  ChatTurn copyWith(
          {String? role,
          String? content,
          DateTime? timestamp,
          int? roundNumber}) =>
      ChatTurn(
        role: role ?? this.role,
        content: content ?? this.content,
        timestamp: timestamp ?? this.timestamp,
        roundNumber: roundNumber ?? this.roundNumber,
      );

  // JSON should use Map<String, dynamic>
  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp?.toUtc().toIso8601String(),
        'roundNumber': roundNumber,
      };

  // Defensive factory: tolerate missing/typed values
  factory ChatTurn.fromJson(Map<String, dynamic> json) {
    final rawRole = (json['role'] as String?)?.trim().toLowerCase() ?? 'user';
    final allowed = {'user', 'assistant', 'system'};
    final role = allowed.contains(rawRole) ? rawRole : 'user';

    final val = json['content'];
    // ensure content is a String
    final content = val is String ? val : (val == null ? '' : val.toString());

    final timestamp = json['timestamp'] is String
        ? DateTime.tryParse(json['timestamp'])
        : null;

    final roundNumber = json['roundNumber'] is int ? json['roundNumber'] : null;

    return ChatTurn(
      role: role,
      content: content,
      timestamp: timestamp,
      roundNumber: roundNumber,
    );
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isSystem => role == 'system';
}
