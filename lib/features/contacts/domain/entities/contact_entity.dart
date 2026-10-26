/// A person the user can start a chat with.
class ContactEntity {
  const ContactEntity({
    required this.id,
    required this.displayName,
    this.phoneE164,
    this.ethioId,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String? phoneE164;
  final String? ethioId;
  final String? avatarUrl;

  String get initial =>
      displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();
}
