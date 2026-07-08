class OnlineSongModel {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? thumbnail;
  final String source;
  final String streamReference;
  final String streamMechanism;
  final int duration; // in seconds
  final bool isStreamable;

  OnlineSongModel({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.thumbnail,
    required this.source,
    required this.streamReference,
    required this.streamMechanism,
    required this.duration,
    required this.isStreamable,
  });

  static String _decodeHtml(String text) {
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  factory OnlineSongModel.fromJson(Map<String, dynamic> json) {
    return OnlineSongModel(
      id: json['id'] as String,
      title: _decodeHtml(json['title'] as String? ?? 'Unknown'),
      artist: _decodeHtml(json['artist'] as String? ?? 'Unknown'),
      album: json['album'] as String?,
      thumbnail: json['thumbnail'] as String?,
      source: json['source'] as String,
      streamReference: json['stream_reference'] as String,
      streamMechanism: json['stream_mechanism'] as String,
      duration: json['duration'] as int? ?? 0,
      isStreamable: json['is_streamable'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'thumbnail': thumbnail,
      'source': source,
      'stream_reference': streamReference,
      'stream_mechanism': streamMechanism,
      'duration': duration,
      'is_streamable': isStreamable,
    };
  }
}
