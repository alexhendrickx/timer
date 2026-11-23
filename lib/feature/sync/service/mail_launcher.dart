import 'package:url_launcher/url_launcher.dart';

/// Opens the system Mail app. A seam so widget tests never touch
/// url_launcher's platform channel.
class MailLauncher {
  const MailLauncher();

  static final Uri _mail = Uri.parse('message://');

  /// False when Mail cannot be opened, or when asking fails.
  Future<bool> canOpen() async {
    try {
      return await canLaunchUrl(_mail);
    } catch (_) {
      return false;
    }
  }

  Future<void> open() async {
    try {
      await launchUrl(_mail);
    } catch (_) {}
  }
}
