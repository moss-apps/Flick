// Technical checks do not certify the Spanish wording or native-speaker review.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/l10n/generated/app_localizations.dart';

Map<String, dynamic> _loadArb(String locale) =>
    json.decode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final en = _loadArb('en');
  final es = _loadArb('es');
  final messageKeys = en.keys.where((key) => !key.startsWith('@')).toSet();
  final spanish = lookupAppLocalizations(const Locale('es'));

  test('Spanish has every current message and no obsolete keys', () {
    expect(es['@@locale'], 'es');
    expect(es.keys.where((key) => !key.startsWith('@')).toSet(), messageKeys);
    for (final key in messageKeys) {
      expect(es[key], isA<String>(), reason: key);
      expect((es[key] as String).trim(), isNotEmpty, reason: key);
    }
  });

  test('Spanish preserves source metadata and every declared argument', () {
    Set<String> metadataKeys(Map<String, dynamic> arb) => arb.keys
        .where((key) => key.startsWith('@') && !key.startsWith('@@'))
        .toSet();

    expect(metadataKeys(es), metadataKeys(en));
    for (final key in messageKeys) {
      expect(es['@$key'], en['@$key'], reason: key);
      final metadata = en['@$key'] as Map<String, dynamic>?;
      final placeholders = metadata?['placeholders'] as Map<String, dynamic>?;
      for (final name in placeholders?.keys ?? <String>[]) {
        final argument = RegExp(r'\{' + RegExp.escape(name) + r'\s*[,}]');
        expect(
          argument.hasMatch(es[key] as String),
          isTrue,
          reason: '$key lost the {$name} argument',
        );
      }
    }
  });

  test('new tutorial and artist information strings are translated', () {
    final newKeys = <String>{
      ...messageKeys.where((key) => key.startsWith('tour')),
      'onlineArtistAlbumInformation',
      'showAppleMusicBiographiesRecommendationsAnd',
    };
    for (final key in newKeys) {
      expect(es[key], isNot(en[key]), reason: key);
    }
    expect(spanish.tourStart, 'Iniciar recorrido');
    expect(spanish.tourOutputBody, contains('no activa ningún modo'));
    expect(
      spanish.tourOutputBody,
      contains('ni garantiza una salida bit-perfect'),
    );
    expect(spanish.tourDspBody, contains('modifica la señal'));
    expect(spanish.tourDspBody, contains('sin activar nada'));
  });

  test('Spanish remains visibly marked as awaiting native-speaker review', () {
    expect(spanish.spanishDraftDescription, contains('Traducción preliminar'));
    expect(
      spanish.spanishDraftDescription,
      contains('pendiente de revisión por hablantes nativos'),
    );
  });

  test('audio terms and action labels retain their meaning', () {
    expect(
      spanish.addSongsToPlaylist(2),
      'Agregar 2 canciones a la lista de reproducción',
    );
    expect(spanish.pcmFrames, 'Tramas PCM');
    expect(spanish.release, 'Liberación');
    expect(
      spanish.experimentalDownTunePlaybackBy432,
      contains('por 432/440 para bajar la afinación de 440 a 432 Hz'),
    );
    expect(
      spanish.experimentalDownTunePlaybackBy432,
      contains('desactiva el paso directo bit-perfect y usa la ruta DSP'),
    );
    expect(
      spanish.matchByArtistAlbumAndTrack(1),
      'Identificar 1 archivo por artista, álbum y duración de la pista',
    );
    expect(
      spanish.matchByArtistAlbumAndTrack(2),
      'Identificar 2 archivos por artista, álbum y duración de la pista',
    );
  });

  test('identification agrees with zero, one and multiple songs', () {
    expect(spanish.identified(0, ''), 'Se identificaron 0 canciones.');
    expect(spanish.identified(1, ''), 'Se identificó 1 canción.');
    expect(spanish.identified(2, ''), 'Se identificaron 2 canciones.');
    expect(
      spanish.identified(1, ' · portada actualizada'),
      'Se identificó 1 canción · portada actualizada.',
    );
  });

  test('DAC messages agree with zero, one and multiple devices', () {
    expect(spanish.dacWillBeOfferedAgain(0), 'Se volverán a ofrecer 0 DAC.');
    expect(spanish.dacWillBeOfferedAgain(1), 'Se volverá a ofrecer 1 DAC.');
    expect(spanish.dacWillBeOfferedAgain(2), 'Se volverán a ofrecer 2 DAC.');
  });

  test('playlist sync and skipped entries agree and preserve spacing', () {
    expect(
      spanish.syncedPlaylistFromServers(0),
      'Se sincronizaron 0 listas de reproducción desde los servidores',
    );
    expect(
      spanish.syncedPlaylistFromServers(1),
      'Se sincronizó 1 lista de reproducción desde los servidores',
    );
    expect(
      spanish.syncedPlaylistFromServers(2),
      'Se sincronizaron 2 listas de reproducción desde los servidores',
    );
    expect(
      spanish.skippedUnmatchedEntr(0),
      ' Se omitieron 0 entradas sin coincidencia.',
    );
    expect(
      spanish.skippedUnmatchedEntr(1),
      ' Se omitió 1 entrada sin coincidencia.',
    );
    expect(
      spanish.skippedUnmatchedEntr(2),
      ' Se omitieron 2 entradas sin coincidencia.',
    );
  });

  test('queue selection avoids agreement on an Object placeholder', () {
    expect(spanish.selectedOfSong(0, 0), 'Selección: 0 de 0 canciones');
    expect(spanish.selectedOfSong(1, 1), 'Selección: 1 de 1 canción');
    expect(spanish.selectedOfSong(1, 2), 'Selección: 1 de 2 canciones');
    expect(spanish.selectedOfSong(2, 2), 'Selección: 2 de 2 canciones');
    expect(
      spanish.readyToRemoveSongKeepingIn(1, 1),
      'Todo listo para quitar 1 canción. Total a conservar: 1.',
    );
    expect(
      spanish.readyToRemoveSongKeepingIn(2, 2),
      'Todo listo para quitar 2 canciones. Total a conservar: 2.',
    );
  });

  test(
    'duplicate cleanup pluralizes both counts without promising deletion',
    () {
      for (final kept in [0, 1, 2]) {
        for (final removed in [0, 1, 2]) {
          final versions = kept == 1 ? 'versión' : 'versiones';
          final copies = removed == 1 ? 'copia restante' : 'copias restantes';
          expect(
            spanish.weLlKeepYourCheckedVersion(kept, removed),
            'Conservaremos $kept $versions que marcaste y quitaremos de la '
            'biblioteca $removed $copies. Los archivos de audio del disco no '
            'se eliminarán.',
          );
        }
      }
    },
  );
}
