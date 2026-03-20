/// Data models for meeting polls (mirrors Web `types/poll.ts`).

enum PollType {
  singleChoice, // 0
  multipleChoice, // 1
}

enum PollStatus {
  active, // 0
  closed, // 1
}

class PollOptionDto {
  final String id;
  final String text;
  final int sortOrder;
  final int voteCount;

  const PollOptionDto({
    required this.id,
    required this.text,
    this.sortOrder = 0,
    this.voteCount = 0,
  });

  factory PollOptionDto.fromJson(Map<String, dynamic> json) {
    return PollOptionDto(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      sortOrder: json['sortOrder'] as int? ?? 0,
      voteCount: json['voteCount'] as int? ?? 0,
    );
  }
}

class MeetingPollDto {
  final String id;
  final String meetingId;
  final String question;
  final PollType pollType;
  final PollStatus pollStatus;
  final bool isAnonymous;
  final String creationTime;
  final List<PollOptionDto> options;
  final int totalVotes;
  final List<String> myVotedOptionIds;

  const MeetingPollDto({
    required this.id,
    required this.meetingId,
    required this.question,
    required this.pollType,
    required this.pollStatus,
    this.isAnonymous = false,
    required this.creationTime,
    this.options = const [],
    this.totalVotes = 0,
    this.myVotedOptionIds = const [],
  });

  bool get hasVoted => myVotedOptionIds.isNotEmpty;
  bool get isActive => pollStatus == PollStatus.active;

  factory MeetingPollDto.fromJson(Map<String, dynamic> json) {
    return MeetingPollDto(
      id: json['id'] as String? ?? '',
      meetingId: json['meetingId'] as String? ?? '',
      question: json['question'] as String? ?? '',
      pollType: PollType.values[(json['pollType'] as int?) ?? 0],
      pollStatus: PollStatus.values[(json['pollStatus'] as int?) ?? 0],
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      creationTime: json['creationTime'] as String? ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => PollOptionDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalVotes: json['totalVotes'] as int? ?? 0,
      myVotedOptionIds: (json['myVotedOptionIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class CreatePollDto {
  final String question;
  final PollType pollType;
  final bool isAnonymous;
  final List<String> options;

  const CreatePollDto({
    required this.question,
    required this.pollType,
    this.isAnonymous = false,
    required this.options,
  });

  Map<String, dynamic> toJson() => {
        'question': question,
        'pollType': pollType.index,
        'isAnonymous': isAnonymous,
        'options': options,
      };
}
