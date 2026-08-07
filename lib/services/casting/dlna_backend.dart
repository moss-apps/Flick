import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'cast_device.dart';

// ponytail: pure-Dart DLNA/UPnP via RawDatagramSocket (SSDP) + AVTransport SOAP.
// No new dep; reuses http + xml like UpnpService. Covers DLNA + UPnP renderers
// (same AVTransport:1 protocol). Local files need an embedded HTTP server — deferred.

class DlnaBackend {
  static const _ssdpAddress = '239.255.255.250';
  static const _ssdpPort = 1900;
  static const _st = 'urn:schemas-upnp-org:device:MediaRenderer:1';
  static const _serviceType = 'urn:schemas-upnp-org:service:AVTransport:1';

  DlnaBackend();

  Future<List<CastDevice>> discover({Duration timeout = const Duration(seconds: 4)}) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _ssdpPort, reuseAddress: true);
    final locations = <String>{};
    try {
      socket.multicastLoopback = false;
      try {
        socket.joinMulticast(InternetAddress(_ssdpAddress));
      } catch (_) {}
      final req = 'M-SEARCH * HTTP/1.1\r\n'
          'HOST: $_ssdpAddress:$_ssdpPort\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 2\r\n'
          'ST: $_st\r\n\r\n';
      socket.send(req.codeUnits, InternetAddress(_ssdpAddress), _ssdpPort);
      final done = Completer<void>();
      Timer(timeout, () {
        if (!done.isCompleted) done.complete();
      });
      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram == null) return;
          final msg = String.fromCharCodes(datagram.data);
          final m = RegExp(r'LOCATION: (.+)', caseSensitive: false).firstMatch(msg);
          if (m != null) locations.add(m.group(1)!.trim());
        }
      });
      await done.future;
    } finally {
      try {
        socket.leaveMulticast(InternetAddress(_ssdpAddress));
      } catch (_) {}
      socket.close();
    }

    final devices = <CastDevice>[];
    await Future.wait(locations.map((loc) async {
      final dev = await _resolve(loc);
      if (dev != null) devices.add(dev);
    }));
    return devices;
  }

  Future<CastDevice?> _resolve(String locationUrl) async {
    try {
      final res = await http.get(Uri.parse(locationUrl)).timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) return null;
      final doc = xml.XmlDocument.parse(res.body);
      final friendlyName = doc.findAllElements('friendlyName', namespace: '*').firstOrNull?.innerText ?? 'Unknown';
      final udn = doc.findAllElements('UDN', namespace: '*').firstOrNull?.innerText ?? locationUrl;
      String? controlUrl = _findAvTransportControlUrl(doc, locationUrl);
      if (controlUrl == null) return null;
      return CastDevice(
        id: udn,
        name: friendlyName,
        backend: CastBackend.dlna,
        locationUrl: locationUrl,
        iconUrl: controlUrl, // ponytail: reuse iconUrl slot for controlURL; renderer session resolves fresh
      );
    } catch (_) {
      return null;
    }
  }

  String? _findAvTransportControlUrl(xml.XmlDocument doc, String locationUrl) {
    for (final svc in doc.findAllElements('service', namespace: '*')) {
      final st = svc.findElements('serviceType', namespace: '*').firstOrNull?.innerText ?? '';
      if (!st.contains('AVTransport')) continue;
      final cu = svc.findElements('controlURL', namespace: '*').firstOrNull?.innerText;
      if (cu == null) continue;
      return Uri.parse(locationUrl).resolve(cu).toString();
    }
    return null;
  }

  Future<void> setUri(String controlUrl, String mediaUrl, {String? title}) async {
    final current = title != null ? '<dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">${_esc(title)}</dc:title>' : '';
    final meta = '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<item id="1" parentID="0" restricted="1">'
        '<res protocolInfo="http-get:*:audio/*:*">${_esc(mediaUrl)}</res>'
        '$current</item></DIDL-Lite>';
    await _soap(controlUrl, 'SetAVTransportURI',
        '<InstanceID>0</InstanceID><CurrentURI>${_esc(mediaUrl)}</CurrentURI><CurrentURIMetaData>$meta</CurrentURIMetaData>');
  }

  Future<void> play(String controlUrl) => _soap(controlUrl, 'Play', '<InstanceID>0</InstanceID><Speed>1</Speed>');
  Future<void> pause(String controlUrl) => _soap(controlUrl, 'Pause', '<InstanceID>0</InstanceID>');
  Future<void> stop(String controlUrl) => _soap(controlUrl, 'Stop', '<InstanceID>0</InstanceID>');

  Future<void> seek(String controlUrl, Duration position) =>
      _soap(controlUrl, 'Seek', '<InstanceID>0</InstanceID><Unit>REL_TIME</Unit><Target>${_fmtTime(position)}</Target>');

  Future<void> setVolume(String controlUrl, int volume) =>
      _soap(controlUrl, 'SetVolume', '<InstanceID>0</InstanceID><Channel>Master</Channel><DesiredVolume>$volume</DesiredVolume>');

  Future<({Duration position, Duration duration, bool playing})?> getPosition(String controlUrl) async {
    try {
      final res = await _soap(controlUrl, 'GetPositionInfo', '<InstanceID>0</InstanceID>');
      final doc = xml.XmlDocument.parse(res);
      final posStr = doc.findAllElements('RelTime', namespace: '*').firstOrNull?.innerText;
      final durStr = doc.findAllElements('TrackDuration', namespace: '*').firstOrNull?.innerText;
      final tiRes = await _soap(controlUrl, 'GetTransportInfo', '<InstanceID>0</InstanceID>');
      final tiDoc = xml.XmlDocument.parse(tiRes);
      final state = tiDoc.findAllElements('CurrentTransportState', namespace: '*').firstOrNull?.innerText ?? '';
      return (
        position: _parseTime(posStr) ?? Duration.zero,
        duration: _parseTime(durStr) ?? Duration.zero,
        playing: state == 'PLAYING',
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> _soap(String controlUrl, String action, String args) async {
    final body = '<?xml version="1.0" encoding="utf-8"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body><u:$action xmlns:u="$_serviceType">$args</u:$action></s:Body></s:Envelope>';
    final res = await http.post(
      Uri.parse(controlUrl),
      headers: {
        'Content-Type': 'text/xml; charset="utf-8"',
        'SOAPAction': '"$_serviceType#$action"',
      },
      body: body,
    ).timeout(const Duration(seconds: 5));
    return res.body;
  }

  String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  String _fmtTime(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Duration? _parseTime(String? s) {
    if (s == null || s == 'NOT_IMPLEMENTED' || s == '0:00:00') return s == '0:00:00' ? Duration.zero : null;
    final m = RegExp(r'(\d+):(\d+):(\d+)').firstMatch(s);
    if (m == null) return null;
    return Duration(hours: int.parse(m.group(1)!), minutes: int.parse(m.group(2)!), seconds: int.parse(m.group(3)!));
  }
}
