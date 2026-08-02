import 'package:flick/services/sources/upnp_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _didl = '<?xml version="1.0"?>'
    '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" '
    'xmlns:dc="http://purl.org/dc/elements/1.1/" '
    'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
    '<item id="i1" parentID="p1">'
    '<dc:title>Lullaby</dc:title>'
    '<upnp:class>object.item.audioItem.musicTrack</upnp:class>'
    '<upnp:artist>The Singers</upnp:artist>'
    '<upnp:album>Dreams</upnp:album>'
    '<upnp:originalTrackNumber>2</upnp:originalTrackNumber>'
    '<dc:date>2019-06-01</dc:date>'
    '<upnp:albumArtURI>http://host/cover.jpg</upnp:albumArtURI>'
    '<res protocolInfo="http-get:*:audio/mpeg:*" size="5000" '
    'duration="0:03:21.5">http://host/track.mp3</res>'
    '</item>'
    '<item id="i2" parentID="p1">'
    '<dc:title>booklet</dc:title>'
    '<upnp:class>object.item.imageItem.photo</upnp:class>'
    '<res protocolInfo="http-get:*:image/jpeg:*" size="100">'
    'http://host/booklet.jpg</res>'
    '</item>'
    '</DIDL-Lite>';

void main() {
  group('parse', () {
    test('DIDL-Lite maps audio fields and skips non-audio items', () {
      final items = UpnpService.parseDidlItemsForTest(_didl);

      expect(items, hasLength(1));
      final song = items.single;
      expect(song.title, 'Lullaby');
      expect(song.artist, 'The Singers');
      expect(song.album, 'Dreams');
      expect(song.trackNumber, 2);
      expect(song.year, 2019);
      expect(song.resUrl, 'http://host/track.mp3');
      expect(song.coverUrl, 'http://host/cover.jpg');
      // audio/mpeg -> mp3
      expect(song.fileType, 'mp3');
      // 0:03:21.5 -> 201500 ms
      expect(song.durationMs, 201500);
    });
  });
}
