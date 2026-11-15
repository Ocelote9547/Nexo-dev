import 'package:url_launcher/url_launcher.dart';

/// Service for quick actions on contacts (call, SMS, email, map, web, share).
class QuickActionsService {
  final Future<bool> Function(Uri)? _launcher;
  QuickActionsService({this._launcher});

  Future<bool> _launch(Uri uri) async {
    final launcher = _launcher ?? launchUrl;
    return launcher(uri);
  }

  Uri buildCallUri(String phoneNumber) => Uri(scheme: 'tel', path: phoneNumber);

  Uri buildSmsUri(String phoneNumber) => Uri(scheme: 'sms', path: phoneNumber);

  Uri buildEmailUri(String email, {String? subject, String? body}) {
    return Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': ?subject,
        'body': ?body,
      },
    );
  }

  Uri buildMapUri(String address) => Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
      );

  Uri buildUrlUri(String url) => Uri.parse(url);

  Uri buildWhatsAppUri(String phoneNumber) => Uri.parse('https://wa.me/$phoneNumber');

  Future<bool> call(String phoneNumber) async => _launch(buildCallUri(phoneNumber));

  Future<bool> sendSms(String phoneNumber) async => _launch(buildSmsUri(phoneNumber));

  Future<bool> sendEmail(String email, {String? subject, String? body}) async =>
      _launch(buildEmailUri(email, subject: subject, body: body));

  Future<bool> openMap(String address) async => _launch(buildMapUri(address));

  Future<bool> openUrl(String url) async => _launch(buildUrlUri(url));

  Future<bool> openWhatsApp(String phoneNumber) async => _launch(buildWhatsAppUri(phoneNumber));
}
