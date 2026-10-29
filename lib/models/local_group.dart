import 'dart:convert';
import 'dart:typed_data';

enum GroupRole { owner, admin, member }

class GroupMember {
  GroupMember({
    required this.id,
    required this.name,
    this.role = GroupRole.member,
  });
  final String id;
  final String name;
  GroupRole role;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role.name};
  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
    id: json['id'] as String,
    name: json['name'] as String,
    role: GroupRole.values.byName(json['role'] as String),
  );
}

enum GroupMediaKind { photo, video, voice, file }

class GroupMedia {
  const GroupMedia({
    required this.name,
    required this.path,
    required this.size,
    required this.kind,
  });
  final String name;
  final String path;
  final int size;
  final GroupMediaKind kind;
  String get sizeLabel => size < 1024 * 1024
      ? '${(size / 1024).toStringAsFixed(1)} KB'
      : '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'size': size,
    'kind': kind.name,
  };
  factory GroupMedia.fromJson(Map<String, dynamic> json) => GroupMedia(
    name: json['name'] as String,
    path: json['path'] as String,
    size: json['size'] as int,
    kind: GroupMediaKind.values.byName(json['kind'] as String),
  );
}

class GroupMessage {
  GroupMessage({
    required this.id,
    required this.text,
    required this.sentAt,
    this.media = const [],
    this.replyPreview,
    this.edited = false,
    this.reaction,
  });
  final String id;
  String text;
  final DateTime sentAt;
  final List<GroupMedia> media;
  final String? replyPreview;
  bool edited;
  String? reaction;
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'sentAt': sentAt.toIso8601String(),
    'media': media.map((m) => m.toJson()).toList(),
    'replyPreview': replyPreview,
    'edited': edited,
    'reaction': reaction,
  };
  factory GroupMessage.fromJson(Map<String, dynamic> json) => GroupMessage(
    id: json['id'] as String,
    text: json['text'] as String,
    sentAt: DateTime.parse(json['sentAt'] as String),
    replyPreview: json['replyPreview'] as String?,
    edited: json['edited'] as bool? ?? false,
    reaction: json['reaction'] as String?,
    media: (json['media'] as List)
        .map((m) => GroupMedia.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList(),
  );
}

class LocalGroup {
  LocalGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.members,
    this.photo,
    List<GroupMessage>? messages,
    this.isChannel = false,
    this.publicLink,
  }) : messages = messages ?? [];
  final String id;
  String name;
  final bool isChannel;
  final String? publicLink;
  String description;
  Uint8List? photo;
  final List<GroupMember> members;
  final List<GroupMessage> messages;
  GroupRole? roleOf(String userId) {
    for (final member in members) {
      if (member.id == userId) return member.role;
    }
    return null;
  }

  bool canManage(String userId) =>
      [GroupRole.owner, GroupRole.admin].contains(roleOf(userId));
  Iterable<GroupMedia> get media => messages.expand((message) => message.media);
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'isChannel': isChannel,
    'publicLink': publicLink,
    'photo': photo == null ? null : base64Encode(photo!),
    'members': members.map((m) => m.toJson()).toList(),
    'messages': messages.map((m) => m.toJson()).toList(),
  };
  factory LocalGroup.fromJson(Map<String, dynamic> json) => LocalGroup(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    isChannel: json['isChannel'] as bool? ?? false,
    publicLink: json['publicLink'] as String?,
    photo: json['photo'] == null ? null : base64Decode(json['photo'] as String),
    members: (json['members'] as List)
        .map((m) => GroupMember.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList(),
    messages: (json['messages'] as List)
        .map((m) => GroupMessage.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList(),
  );
}
