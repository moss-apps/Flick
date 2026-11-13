// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get lockScreenVisualizerTitle => 'Visualizador en pantalla de bloqueo';

  @override
  String get lockScreenVisualizerDescription =>
      'Muestra solo un visualizador fluido a pantalla completa sobre negro puro, encima del bloqueo. Estilo AOD, no AOD del sistema. El dispositivo sigue bloqueado. No se abre automáticamente.';

  @override
  String get lockScreenVisualizerOpen => 'Abrir pantalla del visualizador';

  @override
  String get lockScreenVisualizerInstructions =>
      'Ábrelo aquí, luego bloquea y activa la pantalla. Usa tu estilo, colores, frecuencia y movimiento. Toca o pulsa Atrás para cerrar. Se mantiene el apagado normal de pantalla; no hay animación en el AOD del sistema.';

  @override
  String get lockScreenVisualizerHint =>
      'Toca o pulsa Atrás para cerrar. El dispositivo sigue bloqueado. No se anima en el AOD del sistema.';

  @override
  String get lockScreenVisualizerNoTrack =>
      'Reproduce una canción en Flick para ver su espectro.';

  @override
  String get lockScreenVisualizerPaused => 'Reproducción en pausa';

  @override
  String get lockScreenVisualizerOpenFailed =>
      'No se pudo abrir. Mantén Flick desbloqueado, usa el motor Estándar o PCM de Alta calidad y permite el micrófono si se solicita.';

  @override
  String get lockScreenVisualizerSimulatedTitle =>
      'AOD simulado (experimental)';

  @override
  String get lockScreenVisualizerSimulatedDescription =>
      'Enciende la pantalla al bloquear el dispositivo mientras suena una canción y muestra el mismo visualizador. No es el AOD del sistema: la pantalla permanece encendida, consume más batería y requiere Mostrar sobre otras apps. Se detiene a los 30 minutos o con batería baja.';

  @override
  String get lockScreenVisualizerSimulatedPermission =>
      'Permite Mostrar sobre otras apps en los ajustes del sistema para usar el AOD simulado.';

  @override
  String get tourCore => 'Buscar y reproducir música';

  @override
  String get tourLibrary => 'Herramientas de biblioteca';

  @override
  String get tourPlayer => 'Reproductor y cola';

  @override
  String get tourAppearance => 'Personaliza Flick';

  @override
  String get tourAudio => 'Audio y salida';

  @override
  String get tourGuides => 'Explorar guías';

  @override
  String get tourPickerBody =>
      'Elige una guía breve. Prueba los controles reales o continúa a tu ritmo.';

  @override
  String get tourWelcomeTitle => 'Tu música, a un paso';

  @override
  String get tourWelcomeBody =>
      'Busca una canción, reprodúcela y conoce tu reproductor. Puedes usar los controles reales, continuar sin probarlos o salir en cualquier momento.';

  @override
  String get tourAddBody =>
      '¿Aún no tienes música? Abre los ajustes de biblioteca y elige Agregar carpeta de música. El escaneo puede tardar. Puedes cancelar, denegar el permiso o continuar sin agregar nada; podrás volver más tarde.';

  @override
  String get tourSearchBody =>
      'Escribe una canción o un artista en el campo de búsqueda resaltado. La búsqueda tiene su propia pestaña cuando la agregas a la navegación. Continúa si prefieres explorar.';

  @override
  String get tourPlayTitle => 'Elige qué escuchar';

  @override
  String get tourPlayBody =>
      'Toca una canción que quieras escuchar. La guía avanza cuando comienza la reproducción. Nada se reproduce automáticamente; si no hay música disponible o falla la reproducción, puedes continuar de todos modos.';

  @override
  String get tourMiniBody =>
      'El minirreproductor sigue tu música. Tócalo para abrir el reproductor completo o usa Abrir reproductor más abajo. Primero debe haber una canción cargada; puedes continuar sin ella.';

  @override
  String get tourFullBody =>
      'Usa el reproductor para pausar, cambiar de canción y desplazarte por la pista. La cola, las letras y las demás acciones dependen del diseño que elegiste. La guía no cambiará el volumen, la cola ni los ajustes de audio.';

  @override
  String get tourFinishTitle => 'Ahora sigue a tu ritmo';

  @override
  String get tourFinishBody =>
      'Listo cierra esta guía. Explora otra cuando quieras o vuelve a encontrarlas en Ajustes → Información de la app → Tutorial interactivo.';

  @override
  String get tourSortBody =>
      'Abre el control de orden resaltado para explorar las opciones de orden y los filtros. Basta con abrirlo para esta guía; no necesitas cambiar la vista de tu biblioteca.';

  @override
  String get tourActionsBody =>
      'Mantén presionada una canción para ver sus acciones, como Reproducir a continuación, agregar a la cola y ver la información de la canción. Abrir el menú no cambia la cola. Continúa si aún no hay canciones.';

  @override
  String get tourPlaylistsBody =>
      'Encuentra Listas de reproducción en el menú de biblioteca o en tu navegación personalizada. Usa las acciones de una canción para agregarla a una lista. Lee la guía de listas de reproducción para conocer el proceso completo.';

  @override
  String get tourQueueBody =>
      'Abre Cola desde el reproductor completo para ver las próximas canciones. Su botón depende del diseño. Puedes mirar sin reordenar ni quitar nada.';

  @override
  String get tourLyricsBody =>
      'Abre Letras en el reproductor completo si tu diseño incluye esta opción. No todas las canciones tienen letras disponibles. Continúa o lee el manual si no encuentras el control o las letras.';

  @override
  String get tourNavBody =>
      'Mantén presionada la barra de navegación para personalizarla o abre los ajustes de navegación más abajo. Elige tus pestañas y su orden; esta guía nunca los cambia por ti.';

  @override
  String get tourPlayerLayoutTitle => 'Un reproductor a tu medida';

  @override
  String get tourLayoutBody =>
      'Explora Diseño del reproductor para elegir su apariencia y las acciones que muestra. Los cambios son opcionales y tú decides cuáles hacer.';

  @override
  String get tourOutputTitle => 'Conoce tu salida de audio';

  @override
  String get tourOutputBody =>
      'Los ajustes de audio muestran las rutas de salida disponibles. La compatibilidad con DAC USB y audio de alta resolución del dispositivo depende del hardware conectado. Esta guía no activa ningún modo ni garantiza una salida bit-perfect; revisa el indicador de salida del reproductor.';

  @override
  String get tourDspTitle => 'Ajusta el sonido con intención';

  @override
  String get tourDspBody =>
      'El ecualizador y las demás herramientas DSP son opcionales. El procesamiento modifica la señal y puede impedir una salida bit-perfect. Explora los controles sin activar nada y consulta el manual antes de cambiar la ruta de audio.';

  @override
  String get tourNotNow => 'Ahora no';

  @override
  String get tourEnd => 'Terminar recorrido';

  @override
  String get tourStart => 'Iniciar recorrido';

  @override
  String get tourContinue => 'Continuar';

  @override
  String get tourUseCurrent => 'Usar la canción actual';

  @override
  String get tourReadMore => 'Leer esto en el manual';

  @override
  String get tourOpenNavigation => 'Abrir ajustes de navegación';

  @override
  String get tourOpenLayout => 'Abrir Diseño del reproductor';

  @override
  String get tourOpenAudio => 'Abrir ajustes de audio';

  @override
  String get tourActionConfirmed => 'Listo. Vamos al siguiente paso.';

  @override
  String get tourUnavailable =>
      '¿No ves el control? Puedes continuar o consultar el manual más abajo.';

  @override
  String get filipinoDonationNote => 'Gracias por apoyar a Flick.';

  @override
  String get playingLabel => 'Reproduciendo';

  @override
  String get aDraggableOverlayShowsWhileUsing =>
      'Una ventana flotante que puedes mover aparece mientras usas otras apps.';

  @override
  String get aLittleRecordOfWhatStayed =>
      'Un pequeño registro de lo que no dejaste de escuchar.';

  @override
  String get aNewerFlickBuildIsOn =>
      'Hay una versión más reciente de Flick en Play Store.';

  @override
  String get aPlaylistWithThisNameAlready =>
      'Ya existe una lista de reproducción con ese nombre';

  @override
  String get aPremiumMusicPlayerWithCustom =>
      'Reproductor de música prémium con UAC 2.0 personalizado, desarrollado con Rust para ofrecer la mejor experiencia de audio.';

  @override
  String get aSmoothContinuousWaveAcrossFrequencies =>
      'Una onda continua y fluida a través de las frecuencias';

  @override
  String get aSongWithALongTitle =>
      'Una canción con un título largo para la vista previa';

  @override
  String get aSwipeGestureWhenConfigured =>
      'Un gesto de deslizamiento (si está configurado) activa un visualizador integrado en el minirreproductor.';

  @override
  String get aTighterMixOfFavoritesAnd =>
      'Una mezcla más equilibrada de tus favoritos y de las canciones a las que siempre vuelves.';

  @override
  String get aWeekAndCountingYourDedication =>
      'Una semana y seguimos: se nota tu dedicación.';

  @override
  String get aaudio => 'AAudio';

  @override
  String get aaudioAndroid81 => 'AAudio (Android 8.1+)';

  @override
  String get aaudioWithOpenslEsFallbackDefault =>
      'AAudio con alternativa OpenSL ES (predeterminada)';

  @override
  String get about => 'Acerca de';

  @override
  String get aboutFlickPlayer => 'Acerca de Flick Player';

  @override
  String get aboutThisAlbum => 'Acerca de este álbum';

  @override
  String get aboutThem => 'Acerca del artista';

  @override
  String get absoluteVolumeSync => 'Sincronización del volumen absoluto';

  @override
  String get accentColor => 'Color de acento';

  @override
  String get accuraterip => 'AccurateRip';

  @override
  String achieved(Object arg1) {
    return 'Logrado: $arg1';
  }

  @override
  String get achievementUnlocked => 'LOGRO DESBLOQUEADO';

  @override
  String get activateFallback => 'Activar alternativa';

  @override
  String get active => 'Activo';

  @override
  String activeBands(Object activeCount) {
    return '$activeCount bandas activas';
  }

  @override
  String get activeDays => 'Días con actividad';

  @override
  String get activeQueue => 'Cola actual';

  @override
  String get adaptive => 'Adaptativo';

  @override
  String get add => 'Agregar';

  @override
  String get addAMusicFolderInSettings =>
      'Agrega una carpeta de música en Ajustes';

  @override
  String get addANextTrackButton => 'Agrega un botón de siguiente pista';

  @override
  String get addAPreviousTrackButton => 'Agrega un botón de pista anterior';

  @override
  String get addAtLeastOneLyricLine =>
      'Primero, agrega al menos una línea de letra.';

  @override
  String get addDescription => 'Agregar descripción';

  @override
  String get addDescription2 => 'Agregar descripción';

  @override
  String get addMusicFolder => 'Agregar carpeta de música';

  @override
  String get addMusicFoldersInSettings =>
      'Agrega carpetas de música en Ajustes';

  @override
  String get addMusicWithAlbumTagsTo =>
      'Agrega música con etiquetas de álbum para ver los álbumes aquí';

  @override
  String get addMusicWithArtistTagsTo =>
      'Agrega música con etiquetas de artista para verlos aquí';

  @override
  String get addServer => 'Agregar servidor';

  @override
  String get addSongsFromThePlayerMenu =>
      'Agrega canciones desde el menú del reproductor';

  @override
  String get addSongsFromThePlayerOr =>
      'Agrega canciones desde el menú del reproductor o desde el menú de acciones de una canción.';

  @override
  String addSongsToPlaylist(Object arg1) {
    return 'Agregar $arg1 canciones a la lista de reproducción';
  }

  @override
  String addSongsToPlaylist2(Object arg1) {
    return 'Agregar $arg1 canciones a la lista de reproducción';
  }

  @override
  String get addTheSearchTabVia =>
      'Agrega la pestaña Buscar desde Ajustes de la barra inferior: mantén presionada la barra de navegación.';

  @override
  String get addToFavorites => 'Agregar a favoritos';

  @override
  String get addToFavorites2 => 'Agregar a favoritos';

  @override
  String get addToPlaylist => 'Agregar a la lista de reproducción';

  @override
  String get addToPlaylist2 => 'Agregar a la lista de reproducción';

  @override
  String get addToQueue => 'Agregar a la cola';

  @override
  String get addToQueue2 => 'Agregar a la cola';

  @override
  String addedSongsTo(Object arg1, Object arg2) {
    return 'Se agregaron $arg1 canciones a «$arg2»';
  }

  @override
  String addedSongsTo2(Object arg1, Object playlistName) {
    return 'Se agregaron $arg1 canciones a $playlistName';
  }

  @override
  String addedSongsToFavorites(Object arg1) {
    return 'Se agregaron $arg1 canciones a favoritos';
  }

  @override
  String addedSongsToFavorites3(Object arg1) {
    return 'Se agregaron $arg1 canciones a favoritos';
  }

  @override
  String addedTo(Object arg1) {
    return 'Se agregó a $arg1';
  }

  @override
  String addedTo2(Object arg1) {
    return 'Se agregó a «$arg1»';
  }

  @override
  String get addedToFavorites => 'Se agregó a favoritos';

  @override
  String addedToFavorites2(Object arg1) {
    return 'Se agregó «$arg1» a favoritos';
  }

  @override
  String get addingFavorites => 'Agregando a favoritos';

  @override
  String get addingTheWidget => 'Agregando el widget';

  @override
  String get addsPreDriveAndCatchesPeaks =>
      'Añade ganancia previa y controla los picos para respetar un límite máximo de salida.';

  @override
  String get adjustAudioFrequencies => 'Ajustar las frecuencias de audio';

  @override
  String get adjustMetadataTextSizeInArtwork =>
      'Ajusta el tamaño del texto de los metadatos en el modo de tarjeta con ilustración';

  @override
  String get adjustMetadataTextSizeInImmersive =>
      'Ajusta el tamaño del texto de los metadatos en el modo inmersivo';

  @override
  String get adjustPlaybackSpeed05x =>
      'Ajusta la velocidad de reproducción (0.5x–2x) desde el control de velocidad. Se conserva el tono.';

  @override
  String get adjustSpacingBetweenButtons =>
      'Ajustar el espacio entre los botones';

  @override
  String get adjustTheMiniPlayerSurface =>
      'Ajustar la superficie del minirreproductor';

  @override
  String get adjustTheSizeOfTheBottom =>
      'Ajustar el tamaño de la barra inferior';

  @override
  String get adjustTheSizeOfTheIcons => 'Ajustar el tamaño de los íconos';

  @override
  String get adjustTheWidthOfTheBottom =>
      'Ajusta el ancho de la barra hacia adentro desde los márgenes laterales habituales';

  @override
  String get advanceToARandomCategory => 'Avanzar a una categoría aleatoria';

  @override
  String get advanceToTheNextCategoryAlphabetically =>
      'Avanzar a la siguiente categoría en orden alfabético';

  @override
  String get advanceToTheNextMostRecently =>
      'Avanzar a la categoría agregada más recientemente';

  @override
  String get advanced => 'Avanzado';

  @override
  String get advancedMode => 'Modo avanzado';

  @override
  String get afterHours => 'A altas horas';

  @override
  String get afterScanningMatchFilesWithMissing =>
      'Después de escanear, busca en Apple Music coincidencias para los archivos sin etiquetas. Solo las coincidencias seguras se aplican automáticamente.';

  @override
  String get air => 'Aire';

  @override
  String get alacAudio => 'Audio ALAC';

  @override
  String alacBit(Object arg1) {
    return 'ALAC de $arg1 bits';
  }

  @override
  String get album => 'Álbum';

  @override
  String get albumArt => 'Portada del álbum';

  @override
  String get albumArt2 => 'Portada del álbum';

  @override
  String get albumArtImport => 'Importar portada del álbum';

  @override
  String get albumArtist => 'Artista del álbum';

  @override
  String get albumArtists => 'Artistas del álbum';

  @override
  String get albumArtwork => 'Portada del álbum';

  @override
  String get albumColors => 'Colores del álbum';

  @override
  String get albumComplete => 'Álbum completo (según las etiquetas)';

  @override
  String get albumCompleteExplanation =>
      'Según las etiquetas integradas, tu biblioteca incluye todas las pistas y discos esperados.';

  @override
  String get albumCompleteShort => 'Completo';

  @override
  String get albumCompleteTitle => 'Álbum completo';

  @override
  String get albumCompleteVerificationNote =>
      'Verificado con las etiquetas de los archivos, no con una lista de canciones en línea.';

  @override
  String get albumCompletenessUnknown =>
      'No se puede verificar si el álbum está completo con las etiquetas de las pistas.';

  @override
  String get albumCount => 'Cantidad de álbumes';

  @override
  String get albumDetail => 'Detalles del álbum';

  @override
  String get albumIncompleteShort => 'Incompleto';

  @override
  String get albumLimit => 'LÍMITE DE ÁLBUMES';

  @override
  String albumMissingDiscNumbers(String numbers) {
    return 'Números de disco faltantes: $numbers';
  }

  @override
  String albumMissingDiscs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltan $count discos',
      one: 'Falta 1 disco',
    );
    return '$_temp0';
  }

  @override
  String albumMissingPositions(String positions) {
    return 'Posiciones faltantes (disco:pista): $positions';
  }

  @override
  String albumMissingTrackNumbers(String numbers) {
    return 'Números de pista faltantes: $numbers';
  }

  @override
  String albumMissingTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltan $count pistas',
      one: 'Falta 1 pista',
    );
    return '$_temp0';
  }

  @override
  String get albumName => 'Nombre del álbum';

  @override
  String get albumOptions => 'Opciones del álbum';

  @override
  String get albums => 'Álbumes';

  @override
  String albums2(Object arg1) {
    return '$arg1 álbumes';
  }

  @override
  String albums3(Object _totalAlbums) {
    return '$_totalAlbums álbumes';
  }

  @override
  String get albumsAppearAsAGrid =>
      'Los álbumes aparecen en una cuadrícula con sus portadas. Toca cualquiera para abrir sus detalles y ver la lista completa de canciones.';

  @override
  String get albumsShownPerPage => 'Álbumes por página';

  @override
  String albumsSongs(Object arg1, Object arg2) {
    return '$arg1 álbumes • $arg2 canciones';
  }

  @override
  String get alignLyricTextToTheCenter => 'Centrar el texto de las letras';

  @override
  String get alignLyricTextToTheLeft =>
      'Alinear el texto de las letras a la izquierda';

  @override
  String get alignLyricTextToTheRight =>
      'Alinear el texto de las letras a la derecha';

  @override
  String get all => 'Todo';

  @override
  String get allArtists => 'Todos los artistas';

  @override
  String get allClearNoDuplicates =>
      'Todo en orden: no se encontraron duplicados.';

  @override
  String get allDataIsStoredLocallyOn =>
      'Todos los datos se guardan únicamente en tu dispositivo: metadatos de la biblioteca de música, historial de reproducción, listas, preajustes del ecualizador y preferencias de la app. Las credenciales de Last.fm se guardan de forma segura en el dispositivo. Estos datos nunca salen de tu dispositivo, salvo que uses una integración de forma explícita.';

  @override
  String get allFavoritedTracksInOne =>
      'Todas tus canciones favoritas en un solo lugar. Reprodúcelas, mézclalas o adminístralas desde aquí.';

  @override
  String get allFolders => 'Todas las carpetas';

  @override
  String get allFormats => 'Todos los formatos';

  @override
  String get allFrequenciesEqually => 'Todas las frecuencias por igual';

  @override
  String get allPass => 'Pasa todo';

  @override
  String get allResultsAreHiddenByActive =>
      'Los filtros activos ocultan todos los resultados.';

  @override
  String get allSongs => 'Todas las canciones';

  @override
  String get allWordsStamped => 'Todas las palabras sincronizadas';

  @override
  String get allowFlickToRunWithoutAggressive =>
      'Permite que Flick se ejecute sin restricciones agresivas en segundo plano para que sigan funcionando los nuevos escaneos y las funciones en segundo plano';

  @override
  String get allowed => 'Permitido';

  @override
  String get alphabetical => 'Alfabético';

  @override
  String get alphabeticalIndexRailOnTheSongs =>
      'Índice alfabético en la pantalla de canciones';

  @override
  String get alsoRespectsYourSystemTextSize =>
      'También respeta el tamaño de texto del sistema';

  @override
  String alt(Object arg1) {
    return 'Alt $arg1';
  }

  @override
  String get amber => 'Ámbar';

  @override
  String get analyzeLoudnessAndWriteReplaygainTags =>
      'Analizar el volumen y escribir etiquetas ReplayGain en todas las canciones';

  @override
  String get analyzingAudio => 'Analizando el audio';

  @override
  String get analyzingLoudness => 'Analizando el volumen';

  @override
  String get andArtwork => ' y la portada';

  @override
  String andMoreInRotation(Object arg1) {
    return '$arg1 y más en rotación';
  }

  @override
  String get android => 'Android';

  @override
  String get androidAudioApi => 'API de audio de Android';

  @override
  String get androidBlockedWritingToThisFile =>
      'Android bloqueó la escritura en este archivo. Quita la carpeta desde Ajustes y vuelve a agregarla para conceder acceso de edición; luego inténtalo de nuevo.';

  @override
  String get androidDeveloperOptionsTheReliableWay =>
      'Opciones para desarrolladores de Android: la forma confiable de cambiar el códec (forzarlo desde la app usa una API del sistema oculta que Android estándar bloquea)';

  @override
  String get androidDidNotReturnGalleryPath =>
      'Android no devolvió la ruta de la galería para la imagen guardada.';

  @override
  String get androidDockRoute => 'Ruta de audio de la base de Android';

  @override
  String get androidManagedRustPlaybackPathUsing =>
      'Ruta de reproducción administrada por Android con el motor Rust nativo Oboe.';

  @override
  String get androidUsbRoute => 'Ruta de audio USB de Android';

  @override
  String get animatedAlbumArt => 'Portada animada del álbum';

  @override
  String get animationStyle => 'Estilo de animación';

  @override
  String get animationStyleAndFrequencyFocus =>
      'Estilo de animación y enfoque de frecuencias';

  @override
  String get animations => 'Animaciones';

  @override
  String get animationsAndHapticFeedback => 'Animaciones y respuesta háptica';

  @override
  String get animationsAndHapticFeedbackToggles =>
      'Activar o desactivar las animaciones y la respuesta háptica.';

  @override
  String get apiKey => 'Clave de API';

  @override
  String get appInfo => 'Información de la app';

  @override
  String get appTitle => 'Flick Player';

  @override
  String get appearance => 'Apariencia';

  @override
  String get appearsInTheOverflowMenu => 'Aparece en el menú Más opciones';

  @override
  String get appleMusicDataUnavailable => 'Datos de Apple Music no disponibles';

  @override
  String get appleMusicDataUpdated => 'Datos de Apple Music actualizados';

  @override
  String get appleMusicLookupFailedCheckYour =>
      'No se pudo buscar en Apple Music. Comprueba tu conexión.';

  @override
  String get appleMusicMotionArtOnAlbums =>
      'Portadas animadas de Apple Music en los álbumes, además de desplazamiento y zoom, brillo ambiental y transiciones suaves en las imágenes destacadas';

  @override
  String appliedAutoeqFor(Object arg1) {
    return 'Se aplicó AutoEQ para $arg1';
  }

  @override
  String get apply => 'Aplicar';

  @override
  String apply2(Object arg1) {
    return 'Aplicar $arg1';
  }

  @override
  String get applySelected => 'Aplicar selección';

  @override
  String applyTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '$count canción',
    );
    return 'Aplicar a $_temp0';
  }

  @override
  String get applyingNewAudioEngine => 'Aplicando el nuevo motor de audio…';

  @override
  String get apr => 'abr';

  @override
  String get aptxAdaptive => 'aptX Adaptive';

  @override
  String get aptxHd => 'aptX HD';

  @override
  String get areYouSureYouWantTo =>
      '¿Seguro que quieres eliminar esta lista de reproducción?';

  @override
  String get areYouSureYouWantTo2 =>
      '¿Seguro que quieres borrar todo el historial de escucha? Esta acción no se puede deshacer.';

  @override
  String get areYouSureYouWantTo3 =>
      '¿Seguro que quieres restablecer todas las preferencias de UAC2? Esta acción no se puede deshacer.';

  @override
  String get artResolution => 'Resolución de la portada';

  @override
  String get artist => 'Artista';

  @override
  String get artistDetail => 'Detalles del artista';

  @override
  String get artistIsNotAvailableForThis =>
      'Este artista no está disponible para esta canción';

  @override
  String get artistList => 'Lista de artistas';

  @override
  String get artistName => 'Nombre del artista';

  @override
  String artistUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'artistas',
      one: 'artista',
    );
    return '$_temp0';
  }

  @override
  String get artists => 'Artistas';

  @override
  String artists2(Object arg1) {
    return '$arg1 artistas';
  }

  @override
  String get artistsInRotation => 'Artistas en rotación';

  @override
  String get artwork => 'Ilustración';

  @override
  String get artworkCacheCleared => 'Se vació la caché de portadas';

  @override
  String get artworkCard => 'Tarjeta con portada';

  @override
  String artworkLookupFailed(int status) {
    return 'No se pudo obtener la portada (HTTP $status).';
  }

  @override
  String get artworkLookupInvalidData =>
      'La búsqueda de portada devolvió datos no válidos.';

  @override
  String get artworkLookupTemporarilyUnavailable =>
      'La búsqueda de portada no está disponible temporalmente.';

  @override
  String get artworkPlacement => 'Ubicación de la portada';

  @override
  String get artworkPlacement2 => 'Ubicación de la portada';

  @override
  String get artworkSize => 'Tamaño de la portada';

  @override
  String get artworkSize2 => 'Tamaño de la portada';

  @override
  String get asmrDreams => 'ASMR Dreams';

  @override
  String atKhzBit(Object arg1, Object arg2) {
    return ' a $arg1 kHz/$arg2 bits';
  }

  @override
  String get atLeastOneVersionMustStay => 'Debe quedar al menos una versión.';

  @override
  String get attack => 'Ataque';

  @override
  String get audio => 'Audio';

  @override
  String get audioFocus => 'Enfoque de audio';

  @override
  String get audioFormat => 'Formato de audio';

  @override
  String get audioFormatIsDisabled => 'El formato de audio está desactivado';

  @override
  String get audioSignalPath => 'Ruta de señal de audio';

  @override
  String get audioTestingEquipment => 'Equipo de pruebas de audio';

  @override
  String get aug => 'ago';

  @override
  String get auroraSounds => 'Aurora Sounds';

  @override
  String get authenticationResponseMissingToken =>
      'Falta el token en la respuesta de autenticación';

  @override
  String get auto => 'Automático';

  @override
  String get autoAdvance => 'Avance automático';

  @override
  String get autoBeMsbDefaultOnlyChange =>
      'Automático: BE-MSB predeterminado; cámbialo solo si el DSD nativo produce un siseo';

  @override
  String get autoBitPerfectForUsbDacs => 'Bit perfecto automático para DAC USB';

  @override
  String get autoCollapse => 'Contraer automáticamente';

  @override
  String get autoFill => 'Completar automáticamente';

  @override
  String get autoFocusSearch => 'Enfocar automáticamente la búsqueda';

  @override
  String get autoFullView => 'Vista completa automática';

  @override
  String get autoHideTimeout => 'Tiempo antes de ocultarse automáticamente';

  @override
  String get autoIdentifyUntaggedAlbums =>
      'Identificar automáticamente álbumes sin etiquetas';

  @override
  String get autoNativeDsdOnDapsDop =>
      'Automático: DSD nativo en reproductores de audio digital (DAP), DoP para DAC USB y PCM en los demás casos';

  @override
  String get autoReconnect => 'Reconexión automática';

  @override
  String get autoShowFullViewAfterInactivity =>
      'Mostrar automáticamente la vista completa tras un periodo de inactividad';

  @override
  String get autoShowTheSpotifyStyleImmersive =>
      'Mostrar automáticamente la vista completa inmersiva estilo Spotify tras un periodo de inactividad';

  @override
  String get autoU8ByteInterleavedRecommended =>
      'Automático: U8 intercalado por bytes (recomendado)';

  @override
  String get autoeqHeadphones => 'Audífonos AutoEQ';

  @override
  String get autoeqHeadphones2 => 'Audífonos AutoEQ';

  @override
  String get automatic => 'Automático';

  @override
  String get automaticUpdateChecks => 'Buscar actualizaciones automáticamente';

  @override
  String get automaticallyOpenKeyboardWhenSwitchingTo =>
      'Abrir automáticamente el teclado al cambiar a la búsqueda';

  @override
  String get autoplayOnQueueEnd =>
      'Reproducción automática al final de la cola';

  @override
  String get availableDevices => 'Dispositivos disponibles';

  @override
  String b(Object arg1) {
    return 'B$arg1';
  }

  @override
  String get back => 'Atrás';

  @override
  String get backOnline => 'De nuevo en línea';

  @override
  String get backToLocker => 'Volver a Locker';

  @override
  String get backToReplay => 'Volver a Replay';

  @override
  String get backend => 'Motor';

  @override
  String get background => 'Fondo';

  @override
  String get blurGradient => 'Degradado difuminado';

  @override
  String get blurGradientHint =>
      'La portada difuminada se funde hacia los detalles de la canción.';

  @override
  String get blackGradient => 'Degradado negro';

  @override
  String get blackGradientHint =>
      'Un velo negro profundo mantiene el aspecto clásico.';

  @override
  String get albumArtColorGradient => 'Color de la portada';

  @override
  String get albumArtColorGradientHint =>
      'Tiñe la tarjeta con colores tomados de la portada.';

  @override
  String get cardBackground => 'Fondo de la tarjeta';

  @override
  String get colorGradient => 'Degradado de color';

  @override
  String get backgroundOpacity => 'Opacidad del fondo';

  @override
  String get backgroundPlaybackAnchor =>
      'Anclaje de reproducción en segundo plano';

  @override
  String get balance => 'Balance';

  @override
  String balance2(Object arg1) {
    return 'Balance $arg1';
  }

  @override
  String get balanceTempoDampFilterDelaysSize =>
      'Controles de balance, tempo, amortiguación, filtro, retardo, tamaño, mezcla y expansión adicional.';

  @override
  String get balancedQualityAndStability =>
      'Equilibrio entre calidad y estabilidad';

  @override
  String get band => 'Banda';

  @override
  String get bandControls => 'Controles de banda';

  @override
  String get bandEditors => 'Editores de banda';

  @override
  String get bandPass => 'Filtro pasa banda';

  @override
  String bandU2022(Object arg1, Object arg2) {
    return 'Banda $arg1  •  $arg2';
  }

  @override
  String bands(Object arg1) {
    return '$arg1/31 bandas';
  }

  @override
  String bandsActive(Object activeCount, Object arg1) {
    return '$activeCount/$arg1 bandas activas';
  }

  @override
  String bandsAdjusted(Object adjustedBands) {
    return '$adjustedBands bandas ajustadas';
  }

  @override
  String bandsAdjusted2(Object adjustedCount, Object arg1) {
    return '$adjustedCount/$arg1 bandas ajustadas';
  }

  @override
  String bandsPreampDb(Object arg1, Object arg2, Object arg3) {
    return '$arg1 bandas · preamplificación $arg2 dB · $arg3';
  }

  @override
  String get barHeight => 'Altura de la barra';

  @override
  String get bars => 'Barras';

  @override
  String get baseAlbumArtSizeForEach =>
      'Tamaño base de la portada para cada tarjeta de canción';

  @override
  String get bass => 'Graves';

  @override
  String get bassMidTreble => 'Graves, medios y agudos';

  @override
  String get bassTreble => 'Graves + agudos';

  @override
  String battery(Object battery) {
    return '$battery% de batería';
  }

  @override
  String get baybayinHeadings => 'Etiquetas en baybayin';

  @override
  String get baybayinHeadingsDescription =>
      'Experimental: encabezados seleccionados, accesos directos para explorar y etiquetas de navegación. Las etiquetas de accesibilidad se mantienen en alfabeto latino.';

  @override
  String get baybayinPilotDescription =>
      'Mezcla de tagalo e inglés. Texto preliminar para revisión.';

  @override
  String get beLsbBigEndianSubslotLsb =>
      'BE-LSB: subranura en orden big-endian, primero el bit menos significativo';

  @override
  String get beMsbBigEndianSubslotMsb =>
      'BE-MSB: subranura en orden big-endian, primero el bit más significativo (predeterminado)';

  @override
  String get beMsbPackingTheDefaultWire =>
      'Empaquetado BE-MSB: convención predeterminada de transmisión';

  @override
  String get besideTheSong => 'Junto a la canción';

  @override
  String get bigEndian32BitSubslotMsb =>
      'Subranura de 32 bits en orden big-endian, primero el bit más significativo';

  @override
  String get bigEndianSubslotLsbFirstBit =>
      'Subranura en orden big-endian, primero el bit menos significativo (bits invertidos)';

  @override
  String bit(Object depth) {
    return '$depth bits';
  }

  @override
  String get bitDepth => 'Profundidad de bits';

  @override
  String get bitDepth2 => 'Profundidad de bits';

  @override
  String get bitDepths => 'Profundidades de bits';

  @override
  String get bitPerfect => 'BIT PERFECTO';

  @override
  String get bitPerfect2 => 'Bit perfecto';

  @override
  String get bitPerfectCapsule => 'Cápsula de bit perfecto';

  @override
  String get bitPerfectDapInternal => 'Bit perfecto (interno del DAP)';

  @override
  String get bitPerfectDapInternalDisabledSoftware =>
      'Bit perfecto (interno del DAP) desactivado: hay efectos de software activos.';

  @override
  String get bitPerfectDapInternalEnabledAll =>
      'Bit perfecto (interno del DAP) activado: se omitieron todos los procesos DSP.';

  @override
  String get bitPerfectEnabledParametricEqIs =>
      'Bit perfecto activado: el ecualizador paramétrico se omite en la conexión USB directa. Reinicia la app para aplicar los cambios de reproducción.';

  @override
  String get bitPerfectUsbDac => 'Bit perfecto (DAC USB)';

  @override
  String get bitPerfectUsbDacCouldNot =>
      'No se pudo activar el modo bit perfecto (DAC USB). Consulta los diagnósticos USB para conocer el motivo.';

  @override
  String bitPerfectUsbDacCouldNot2(Object arg1) {
    return 'No se pudo activar el modo bit perfecto (DAC USB) para $arg1. Consulta los diagnósticos USB.';
  }

  @override
  String bitPerfectUsbDacEnabledFor(Object arg1) {
    return 'Se activó el modo bit perfecto (DAC USB) para $arg1.';
  }

  @override
  String get bitPerfectVerified => 'Bit perfecto verificado';

  @override
  String get bitSubslotsLlRrPer => 'Subranuras de 16 bits: LL|RR por trama';

  @override
  String get bitSubslotsLlllRrrrPer =>
      'Subranuras de 32 bits: LLLL|RRRR por trama (heredado)';

  @override
  String get bitrateAdjustsToSignalQuality =>
      'La tasa de bits se ajusta a la calidad de la señal';

  @override
  String get blocked => 'Bloqueado';

  @override
  String get blue => 'Azul';

  @override
  String get bluetooth => 'Bluetooth';

  @override
  String get bluetoothCodecInfo => 'Información del códec Bluetooth';

  @override
  String get bluetoothOutput => 'Salida Bluetooth';

  @override
  String get boldSaturatedColorsFromAlbumArt =>
      'Colores intensos y saturados de la portada del álbum.';

  @override
  String get boostBeyond100UpTo200 =>
      'Aumentar por encima del 100 % (hasta el 200 %)';

  @override
  String get border => 'Borde';

  @override
  String get bothBitPerfectOptionsAreOff =>
      'Las dos opciones de bit perfecto están desactivadas en este DAP, así que el motor estándar no está disponible. Aún puedes usar Rust con Oboe o USB isócrono.';

  @override
  String get bottom => 'Abajo';

  @override
  String get bottomBar => 'Barra inferior';

  @override
  String get bottomBarAlwaysVisible => 'Barra inferior siempre visible';

  @override
  String get bottomBarWidth => 'Ancho de la barra inferior';

  @override
  String get bouncy => 'Elástico';

  @override
  String get browseAllArtistsInYour =>
      'Explora todos los artistas de tu biblioteca. Toca un artista para ver sus álbumes y canciones.';

  @override
  String get browseByArtworkOpenAnyAlbum =>
      'Explora las portadas, abre cualquier álbum y ve directamente a la lista de canciones.';

  @override
  String get browseByFolder => 'Explorar por carpeta';

  @override
  String get browseMore => 'Explorar más';

  @override
  String get browseTheFullControlsGuide =>
      'Consulta la guía completa de controles';

  @override
  String get browseYourArtistLibrary => 'Explora la biblioteca de artistas';

  @override
  String get browseYourArtistsExploreTheirDiscographies =>
      'Explora tus artistas, descubre su discografía y reproduce sus canciones.';

  @override
  String get browsingYourLibrary => 'Explorando tu biblioteca';

  @override
  String get buffer => 'Búfer';

  @override
  String build(Object kAppVersion, Object kAppBuild) {
    return '$kAppVersion (compilación $kAppBuild)';
  }

  @override
  String get buildFlavor => 'Variante de compilación';

  @override
  String get buildFlavorFull => 'full: versión para descarga directa';

  @override
  String get buildFlavorPlay => 'play: versión de Google Play';

  @override
  String get buildingYourMusicHome => 'Preparando tu espacio musical';

  @override
  String get builtIn => 'Integrado';

  @override
  String get buttonSpacing => 'Espacio entre botones';

  @override
  String get buttons => 'Botones';

  @override
  String get buyMeACoffee => 'Cómprame un café';

  @override
  String by(Object arg1, Object arg2) {
    return '«$arg1» de $arg2';
  }

  @override
  String get bypassAllDspEqDynamicsCrossfade =>
      'Omitir todo el procesamiento DSP (ecualizador, dinámica, fundido cruzado y velocidad) en la ruta interna de alta resolución del DAP nativo. Desactívalo para usar efectos de software. Esto también se desactiva al apagar Bit perfecto (DAC USB).';

  @override
  String get byteInterleavedLrlrStream => 'Intercalado por bytes: flujo LRLR';

  @override
  String get cacheWaveformsAndLoudnessForAll =>
      'Guardar en caché las formas de onda y el volumen de todas las canciones';

  @override
  String cachedAlbumArtWillBeRemoved(Object arg1) {
    return 'Se eliminarán las portadas en caché ($arg1). Se volverán a cargar automáticamente mientras exploras.';
  }

  @override
  String cachedWavConversionsWillBeRemoved(Object size) {
    return 'Se eliminarán las conversiones WAV en caché ($size). Los archivos volverán a convertirse la próxima vez que se reproduzcan.';
  }

  @override
  String get calculatingSize => 'Calculando el tamaño…';

  @override
  String get calmFrequencies => 'Frecuencias suaves';

  @override
  String get camera => 'Cámara';

  @override
  String get cameraAccessIsNeededYouCan =>
      'Se necesita acceso a la cámara. Puedes activarlo en los ajustes de Android.';

  @override
  String get cameraAndPhotoLibraryAccessIs =>
      'El acceso a la cámara y a la biblioteca de fotos se usa únicamente para la función Flick Replay, que permite crear fondos personalizados para los pósteres del resumen de escucha. Las fotos solo se usan cuando lo solicitas y permanecen en tu dispositivo. No se suben ni se transmiten imágenes.';

  @override
  String get cameraAndPhotos => 'Cámara y fotos';

  @override
  String get cancel => 'Cancelar';

  @override
  String get capAt60hzBalancedSmoothnessAnd =>
      'Limitar a 60 Hz: equilibrio entre fluidez y batería';

  @override
  String capMs(Object arg1) {
    return 'límite $arg1 ms';
  }

  @override
  String get capabilities => 'Capacidades';

  @override
  String get capabilitiesNotAvailable => 'Capacidades no disponibles';

  @override
  String get capabilityState => 'Estado de las capacidades';

  @override
  String get cardSize => 'Tamaño de tarjeta';

  @override
  String get cardWidth => 'Ancho de tarjeta';

  @override
  String get cast => 'Transmitir';

  @override
  String get casting => 'Transmitiendo';

  @override
  String get castingTapToManage => 'Transmitiendo: toca para administrar';

  @override
  String castingTo(Object deviceName) {
    return 'Transmitiendo a $deviceName';
  }

  @override
  String castingTo2(Object arg1) {
    return 'Transmitiendo a $arg1';
  }

  @override
  String get categories => 'Categorías';

  @override
  String get ceiling => 'Límite máximo';

  @override
  String get center => 'Centro';

  @override
  String get centerTheTitleAndInfoIn =>
      'Centrar el título y la información en el encabezado de detalles';

  @override
  String get centeredHeaderTitle => 'Título centrado en el encabezado';

  @override
  String get centeredWidensToFitYourControls =>
      'Centrado; se amplía para dar cabida a los controles';

  @override
  String get centralTransportControlsPreviousRestarts =>
      'Controles de reproducción centrales. El botón Anterior reinicia la pista si ya pasaron más de 3 segundos.';

  @override
  String ch(Object channels) {
    return '$channels canales';
  }

  @override
  String ch2(Object ch) {
    return '$ch canales';
  }

  @override
  String ch3(Object arg1, Object arg2) {
    return '$arg1 / $arg2 canales';
  }

  @override
  String get changeCover => 'Cambiar portada';

  @override
  String get changingSampleRateBitDepthOr =>
      'Cambiar la frecuencia de muestreo, la profundidad de bits o el manejo de canales puede remuestrear las canciones y afectar la calidad de reproducción, el tono, la velocidad o la estabilidad en algunos dispositivos.';

  @override
  String get channels => 'Canales';

  @override
  String channels2(Object arg1) {
    return '$arg1 canales';
  }

  @override
  String channels3(Object ch) {
    return '$ch canales';
  }

  @override
  String get checkAgain => 'Volver a comprobar';

  @override
  String get checkTheVersionsYouWantTo =>
      'Marca las versiones que quieres conservar; las que no marques se eliminarán de tu biblioteca. Debe quedar al menos una.';

  @override
  String get checkVersionsToKeepUncheckedWill =>
      'Marca las versiones que quieres conservar; las demás se eliminarán';

  @override
  String get checking => 'Comprobando…';

  @override
  String get checkingForUpdates => 'Buscando actualizaciones';

  @override
  String get checkingForUpdates2 => 'Buscando actualizaciones…';

  @override
  String get childrenSPrivacy => 'Privacidad de los menores';

  @override
  String get chooseAction => 'Elegir acción';

  @override
  String get chooseAudioEngine => 'Elegir motor de audio';

  @override
  String get chooseFromBuiltInPresets =>
      'Elige entre los preajustes integrados (Normal, refuerzo de graves, refuerzo de agudos, voz, etc.) o guarda uno propio.';

  @override
  String get chooseLocationU2026 => 'Elegir ubicación…';

  @override
  String get chooseWhichToKeep => 'Elegir cuáles conservar';

  @override
  String get chromecast => 'Chromecast';

  @override
  String get circularDotsRadiusFollowsAmplitude =>
      'Puntos circulares: el radio sigue la amplitud';

  @override
  String get cityBeats => 'City Beats';

  @override
  String get claimedByFlick => 'Reclamado por Flick';

  @override
  String get cleanStraightLineWithPrecisionScrubbing =>
      'Línea recta y limpia con desplazamiento preciso.';

  @override
  String get clear => 'Borrar';

  @override
  String get clearAll => 'Borrar todo';

  @override
  String get clearAllUac2Settings => 'Borrar todos los ajustes de UAC2';

  @override
  String get clearArtworkCache => '¿Borrar la caché de portadas?';

  @override
  String get clearArtworkCache2 => 'Borrar la caché de portadas';

  @override
  String get clearConvertedAudio => 'Borrar el audio convertido';

  @override
  String get clearConvertedAudioCache =>
      '¿Borrar la caché de audio convertido?';

  @override
  String get clearFilters => 'Borrar filtros';

  @override
  String get clearHistory => 'Borrar historial';

  @override
  String get clearLogs => '¿Borrar los registros?';

  @override
  String get clearTheCounterAndAnyUnlocked =>
      'Borrar el contador y los hitos de racha que ya se desbloquearon';

  @override
  String get clearWord => 'Borrar palabra';

  @override
  String get clearWords => 'Borrar palabras';

  @override
  String get clearing => 'Borrando…';

  @override
  String get close => 'Cerrar';

  @override
  String get closePreview => 'Cerrar vista previa';

  @override
  String codecApplied(Object arg1) {
    return 'Códec aplicado: $arg1';
  }

  @override
  String get codecControl => 'Control del códec';

  @override
  String get codecForcingUnavailableOnThisDevice =>
      'No se puede forzar el códec en este dispositivo. Cámbialo en Opciones para desarrolladores → Códec de audio Bluetooth.';

  @override
  String get codecInfo => 'Información del códec';

  @override
  String get codecU0026Audio => 'Códec y audio';

  @override
  String get collapseAfter => 'Contraer después de';

  @override
  String get collapsed => 'Contraído';

  @override
  String get collection => 'Colección';

  @override
  String get color => 'Color';

  @override
  String get comingSoon => 'Muy pronto';

  @override
  String get comment => 'Comentario';

  @override
  String get compatibility => 'Compatibilidad';

  @override
  String get compatibleWithPowerampEq => 'Compatible con Poweramp EQ';

  @override
  String get completelyHiddenFromTheBottomBar =>
      'Completamente oculta en la barra inferior';

  @override
  String get compressor => 'Compresor';

  @override
  String get compressorOff => 'Compresor desactivado';

  @override
  String get compressorOn => 'Compresor activado';

  @override
  String get configureDefaultStyleAndSensitivity =>
      'Configura el estilo predeterminado y la sensibilidad en Ajustes → Visualizador.';

  @override
  String get configureLyricsSavingAndFetching =>
      'Configura cómo se guardan y buscan las letras.';

  @override
  String get configureSwipeBehaviorInSettings =>
      'Configura el gesto de deslizamiento en Ajustes → Diseño del reproductor → Deslizamiento del minirreproductor.';

  @override
  String get configureUsbDacAmpDevices =>
      'Configurar dispositivos DAC/amplificadores USB';

  @override
  String get configureWidgetAppearanceAndShown =>
      'Configura la apariencia del widget y los controles visibles en Ajustes → Widgets.';

  @override
  String get configureYourMusicExperience => 'Configura tu experiencia musical';

  @override
  String get connect => 'Conectar';

  @override
  String get connectAMusicServer => 'Conectar un servidor de música';

  @override
  String get connectASubsonicJellyfinWebdavUpnp =>
      'Conecta un servidor Subsonic, Jellyfin, WebDAV, UPnP o Tidal para transmitir desde tu biblioteca remota.';

  @override
  String get connectAUsbDacOrAudio =>
      'Conectar un DAC USB o una interfaz de audio';

  @override
  String get connectListenbrainz => 'Conectar a ListenBrainz';

  @override
  String get connectToScrobbleYourListeningHistory =>
      'Conéctate para registrar tu historial de escucha';

  @override
  String get connectToScrobbleYourMusic =>
      'Conéctate para registrar lo que escuchas';

  @override
  String get connectToSubmitYourListeningHistory =>
      'Conéctate para enviar tu historial de escucha';

  @override
  String get connectToTheInternetToCheck =>
      'Conéctate a internet para buscar actualizaciones.';

  @override
  String get connected => 'Conectado';

  @override
  String get connectedAccount => 'Cuenta conectada';

  @override
  String connectedAs(Object username) {
    return 'Conectado como $username';
  }

  @override
  String get connecting => 'Conectando';

  @override
  String get connection => 'Conexión';

  @override
  String get connectionBehavior => 'Comportamiento de la conexión';

  @override
  String get connectionFailedRetry => 'Falló la conexión: volver a intentar';

  @override
  String get connectionManagement => 'Administración de conexiones';

  @override
  String get connectionNotices => 'Avisos de conexión';

  @override
  String get connectionNoticesDescription =>
      'Mostrar avisos cuando no hay conexión y cuando vuelve';

  @override
  String get connectionOk => 'Conexión correcta';

  @override
  String get connectionStatus => 'Estado de la conexión';

  @override
  String containsValuesOutsideTheSupportedRanges(Object presetName) {
    return 'El preajuste «$presetName» contiene valores fuera de los límites permitidos; se ajustaron así:\n';
  }

  @override
  String get content => 'Contenido';

  @override
  String get contentControls => 'Contenido y controles';

  @override
  String get contentPlacement => 'Ubicación del contenido';

  @override
  String get contentPlacement2 => 'Ubicación del contenido';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get continueThroughTheSearchResults =>
      'Seguir recorriendo los resultados de búsqueda';

  @override
  String get continueThroughYourEntireLibrary =>
      'Seguir recorriendo toda tu biblioteca';

  @override
  String get controls => 'Controles';

  @override
  String conversionFailed(Object error) {
    return 'Error al convertir: $error';
  }

  @override
  String get convertedAudioCacheCleared =>
      'Se vació la caché de audio convertido';

  @override
  String convertedSuccessfully(Object fileName) {
    return '$fileName se convirtió correctamente';
  }

  @override
  String get convertingAudio => 'Convirtiendo audio…';

  @override
  String convertingToWav(Object fileName) {
    return 'Convirtiendo $fileName a WAV…';
  }

  @override
  String get convolverImpulseResponse => 'Convolución / respuesta al impulso';

  @override
  String copies(Object arg1, Object arg2) {
    return '$arg1 • $arg2 copias';
  }

  @override
  String get copy => 'Copiar';

  @override
  String get copyLink => 'Copiar enlace';

  @override
  String get copyYourUserTokenFromListenbrainz =>
      'Copia tu token de usuario desde los ajustes de ListenBrainz y pégalo abajo.';

  @override
  String get copyright => 'Derechos de autor';

  @override
  String get cornerRadius => 'Radio de las esquinas';

  @override
  String get cosmicOrchestra => 'Cosmic Orchestra';

  @override
  String get couldNotCheckForUpdates => 'No se pudieron buscar actualizaciones';

  @override
  String get couldNotConnectToLastFm =>
      'No se pudo conectar con Last.fm. Comprueba las credenciales de la API e inténtalo de nuevo.';

  @override
  String get couldNotConnectToListenbrainzCheck =>
      'No se pudo conectar con ListenBrainz. Comprueba el token e inténtalo de nuevo.';

  @override
  String get couldNotLoadAlbumSongs =>
      'No se pudieron cargar las canciones del álbum';

  @override
  String get couldNotCreateThePosterImage =>
      'No se pudo crear la imagen del póster.';

  @override
  String get couldNotLoadArtistSongs =>
      'No se pudieron cargar las canciones del artista';

  @override
  String couldNotLoadIr(Object e) {
    return 'No se pudo cargar la respuesta al impulso: $e';
  }

  @override
  String get couldNotLoadSession => 'No se pudo cargar la sesión';

  @override
  String get couldNotOpenBrowser => 'No se pudo abrir el navegador.';

  @override
  String get couldNotOpenKoFiPlease =>
      'No se pudo abrir Ko-fi. Inténtalo de nuevo.';

  @override
  String get couldNotOpenLink => 'No se pudo abrir el enlace';

  @override
  String couldNotOpenLink2(Object e) {
    return 'No se pudo abrir el enlace: $e';
  }

  @override
  String get couldNotOpenThatPhotoTry =>
      'No se pudo abrir esa foto. Prueba con otra imagen.';

  @override
  String get couldNotOpenTheLink => 'No se pudo abrir el enlace';

  @override
  String couldNotOpenTheLink2(Object e) {
    return 'No se pudo abrir el enlace: $e';
  }

  @override
  String get couldNotOpenThePlayStore => 'No se pudo abrir Play Store.';

  @override
  String couldNotOpenThePlayStore2(Object error) {
    return 'No se pudo abrir Play Store: $error';
  }

  @override
  String get couldNotOpenThePlayStore3 => 'No se pudo abrir Play Store';

  @override
  String couldNotPrepareTheEditedFile(String error) {
    return 'No se pudo preparar el archivo editado: $error';
  }

  @override
  String get couldNotReachTheServer =>
      'No se pudo acceder al servidor. Comprueba la URL y las credenciales e inténtalo de nuevo.';

  @override
  String get couldNotReadTheCoverColors =>
      'No se pudieron leer los colores de la portada. La señal sigue disponible.';

  @override
  String get couldNotReadTheSelectedImage =>
      'No se pudo leer la imagen seleccionada.';

  @override
  String get couldNotReadTheSelectedLyrics =>
      'No se pudo leer el archivo de letras seleccionado.';

  @override
  String get couldNotResolveTheAlbum =>
      'No se pudo identificar el álbum de esta canción.';

  @override
  String get couldNotRenamePlaylist =>
      'No se pudo cambiar el nombre de la lista de reproducción.';

  @override
  String get couldNotSaveTheLyricsFile =>
      'No se pudo guardar el archivo de letras.';

  @override
  String get couldNotSaveYourRecapPlease =>
      'No se pudo guardar el resumen. Inténtalo de nuevo.';

  @override
  String get couldNotUpdatePlaylistCover =>
      'No se pudo actualizar la portada de la lista. Prueba con otra imagen.';

  @override
  String get couldNotUseTheSelectedLyrics =>
      'No se pudo usar el archivo de letras seleccionado.';

  @override
  String get couldnTOpenTheBrowserAutomatically =>
      'No se pudo abrir el navegador automáticamente. Autoriza el acceso desde cualquier dispositivo con este enlace; completaremos el inicio de sesión cuando lo hagas:\n';

  @override
  String get countingFiles => 'Contando archivos…';

  @override
  String covers(Object done, Object total) {
    return '$done / $total portadas';
  }

  @override
  String get creatingPlaylists => 'Creando listas de reproducción';

  @override
  String get cropCoverHint => 'Pellizca para acercar y arrastra para reubicar';

  @override
  String get customActionButtons => 'Botones de acciones personalizados';

  @override
  String get customizeTheHomeScreenWidget =>
      'Personaliza la apariencia del widget de la pantalla de inicio.';

  @override
  String get customizing => 'Personalizando';

  @override
  String get dedicatedSearchTab => 'Pestaña de búsqueda exclusiva';

  @override
  String get drag => 'Arrastrar';

  @override
  String get dragAnywhereOnTheWaveform =>
      'Arrastra en cualquier punto de la forma de onda para recorrer la pista. La forma de onda representa el volumen del audio a lo largo del tiempo.';

  @override
  String get dragEachFrequencyBandSlider =>
      'Arrastra el control de cada banda de frecuencia para ajustar el sonido. El ecualizador se aplica a todo el audio de Flick.';

  @override
  String get dragScrollHandle => 'Arrastrar el control de desplazamiento';

  @override
  String get dragTheScrollHandleOn =>
      'Arrastra el control del borde derecho para avanzar por el alfabeto. Un globo muestra la letra actual.';

  @override
  String get dragTracksByTheirHandle =>
      'Arrastra las pistas desde el control para cambiar su orden. Los cambios se aplican de inmediato.';

  @override
  String get eachBrowseTabHasIts =>
      'Cada pestaña de exploración tiene arriba su propia barra de búsqueda, que filtra el contenido de esa pestaña mientras escribes.';

  @override
  String get editCover => 'Editar portada';

  @override
  String get crop => 'Recortar';

  @override
  String get adjust => 'Ajustar';

  @override
  String get editing => 'Editando';

  @override
  String get enableDisable => 'Activar / desactivar';

  @override
  String get fastScroll => 'Desplazamiento rápido';

  @override
  String get fastScrollThroughLongLists =>
      'Desplázate rápidamente por listas largas (pestaña Canciones).';

  @override
  String get favoritesTab => 'Pestaña Favoritos';

  @override
  String get fetchingLyrics => 'Buscando letras';

  @override
  String get filters => 'Filtros';

  @override
  String get brightness => 'Brillo';

  @override
  String get contrast => 'Contraste';

  @override
  String get flickFetchesLyricsAutomaticallyWhen =>
      'Flick busca letras automáticamente cuando están disponibles. También puedes pegarlas o editarlas manualmente.';

  @override
  String get folderPlayback => 'Reproducción por carpeta';

  @override
  String get fromAnySongsLong =>
      'En el menú que aparece al mantener presionada cualquier canción, elige Reproducir a continuación para insertarla justo después de la pista actual.';

  @override
  String get gaplessPlaybackCrossfadeViewModes =>
      'Reproducción sin pausas, fundido cruzado, modos de vista y apariencia del tema.';

  @override
  String get generateAShareCardWith =>
      'Crea una tarjeta para compartir con la portada y la información de la pista, o comparte el archivo directamente.';

  @override
  String get gestures => 'Gestos';

  @override
  String get gridView => 'Vista de cuadrícula';

  @override
  String get homeScreenWidget => 'Widget de pantalla de inicio';

  @override
  String get ifSearchIsInYour =>
      'Si agregas Buscar a la barra de navegación, puedes buscar canciones, álbumes y artistas a la vez, con resultados agrupados.';

  @override
  String get immersiveView => 'Vista inmersiva';

  @override
  String get inAppInfoU2192Interactive =>
      'En Información de la app → Tutorial interactivo, vuelve a reproducir el recorrido guiado. Ver bienvenida vuelve a mostrar las pantallas de bienvenida.';

  @override
  String get inTabSearch => 'Búsqueda dentro de la pestaña';

  @override
  String get inTheFullPlayerTap =>
      'En el reproductor completo, toca el ícono del visualizador para activarlo o desactivarlo.';

  @override
  String get interface => 'Interfaz';

  @override
  String get lastFmAndListenBrainzScrobbling =>
      'Configuración del registro de reproducciones en Last.fm y ListenBrainz.';

  @override
  String get layoutModeSizingMiniPlayer =>
      'Modo de diseño, tamaño, gesto del minirreproductor y botones de acciones rápidas personalizados.';

  @override
  String get library => 'Biblioteca';

  @override
  String get longPressASong => 'Mantén presionada una canción';

  @override
  String get longPressOrTapAgain =>
      'Mantén presionado o vuelve a tocar para cambiar de estilo de visualizador (barras, onda, radial, etc.).';

  @override
  String get longPressTheNavBar =>
      'Mantén presionada la barra de navegación o ve a Ajustes → Barra inferior para elegir qué pestañas aparecen y en qué orden.';

  @override
  String get longPressYourHomeScreen =>
      'Mantén presionada la pantalla de inicio → Agregar widget → Flick. Elige un tamaño y colócalo en la pantalla de inicio.';

  @override
  String get manageScanFoldersTriggerRescans =>
      'Administra las carpetas de análisis, vuelve a analizarlas y usa la herramienta para quitar duplicados.';

  @override
  String get manualBands => 'Bandas manuales';

  @override
  String get manualBitPerfectCapsule => 'Cápsula de bit perfecto';

  @override
  String get manualBottomBar => 'Barra inferior';

  @override
  String get manualLongPress => 'Mantener presionado';

  @override
  String get manualLyricsSyncStudio => 'Estudio de letras y sincronización';

  @override
  String get manualPlayNext => 'Reproducir a continuación';

  @override
  String get manualPlaybackSpeed => 'Velocidad de reproducción';

  @override
  String get manualQueue2 => 'Cola';

  @override
  String get manualRemoving => 'Quitar';

  @override
  String get manualSongs => 'Canciones';

  @override
  String get manualSwipeLeftRightOnThe =>
      'Desliza a la izquierda o a la derecha en el área principal para cambiar entre las pestañas de la barra de navegación.';

  @override
  String get manualTap => 'Tocar';

  @override
  String get nextPreviousTrackOrToggle =>
      'Pista siguiente/anterior (o activar o desactivar el visualizador, según los ajustes).';

  @override
  String get openAPlaylistToReorder =>
      'Abre una lista para reordenar las canciones (arrastra el control), quitarlas (desliza o mantén presionado) o cambiar el nombre o eliminar la lista desde su menú.';

  @override
  String get openFromTheLyricsEdit =>
      'Ábrelo desde el ícono de edición de letras. Toca Marcar cuando suene cada línea para sincronizarla con la música. Guarda para conservar la sincronización.';

  @override
  String get openTheActionsSheetFor =>
      'Abre la hoja de acciones de una canción o personaliza la barra de navegación.';

  @override
  String get openTheFullPlayer => 'Abrir el reproductor completo';

  @override
  String get openTheQueueFromThe =>
      'Abre la cola desde el reproductor completo. La pista que se está reproduciendo aparece resaltada y las siguientes se muestran debajo.';

  @override
  String get openingTheFullPlayer => 'Abriendo el reproductor completo';

  @override
  String get opensTheActionsSheetPlay =>
      'Abre la hoja de acciones: Reproducir a continuación, Agregar a la cola, Agregar a la lista, Ir al álbum, Ir al artista, Compartir, Ver información o Eliminar.';

  @override
  String get playASongOpenAn =>
      'Reproduce una canción, abre un álbum o activa un control.';

  @override
  String get playPauseNextPrevious =>
      'Reproducir / Pausar / Siguiente / Anterior';

  @override
  String get playTheWholeAlbumShuffle =>
      'Reproduce el álbum completo, mézclalo o elige canciones individuales. Arriba se muestran la portada, el año y el artista.';

  @override
  String get playing => 'Reproduciendo';

  @override
  String get playingASong => 'Reproduciendo una canción';

  @override
  String get reSyncALineBy =>
      'Vuelve a sincronizar una línea tocándola de nuevo en el momento correcto.';

  @override
  String get removeItFromTheQueue => 'Quitar de la cola.';

  @override
  String get reordering => 'Cambiando el orden';

  @override
  String get replayTutorial => 'Volver a reproducir el tutorial';

  @override
  String get saturation => 'Saturación';

  @override
  String get scrubTheWaveformSeekbarReorder =>
      'Deslizar la barra de reproducción por la forma de onda; reordenar elementos de la cola y canciones de la lista.';

  @override
  String get seeYourMusicOrganizedBy =>
      'Consulta tu música organizada según la estructura de carpetas del disco. Útil si organizas los archivos manualmente.';

  @override
  String get selectionMode => 'Modo de selección';

  @override
  String get setACountdownAfterWhich =>
      'Configura una cuenta regresiva para detener la reproducción. Opciones: 5, 10, 15, 30, 45 o 60 minutos, o al terminar la pista.';

  @override
  String get showOrHideHomeScreen =>
      'Mostrar u ocultar secciones y pestañas de la pantalla de inicio.';

  @override
  String get showsTheArtistsAlbums =>
      'Muestra los álbumes del artista y la lista completa de canciones. Reproduce todo, mézclalo o elige desde qué canción empezar.';

  @override
  String get shuffleFromTheHeaderPlays =>
      'El botón Aleatorio del encabezado reproduce toda la biblioteca en orden aleatorio.';

  @override
  String get shuffleRepeat => 'Aleatorio y repetir';

  @override
  String get sort => 'Ordenar';

  @override
  String get sortAlbumsByTitleArtist =>
      'Ordena los álbumes por título, artista, año o fecha en que se agregaron desde el ícono de orden.';

  @override
  String get sortPersistsAcrossSessions =>
      'El orden se conserva entre sesiones.';

  @override
  String get starRateTheCurrentTrack =>
      'Asigna una calificación por estrellas a la pista actual. Las calificaciones se guardan y puedes usarlas para ordenar.';

  @override
  String get styles => 'Estilos';

  @override
  String get swipeATrackLeftOr =>
      'Desliza una pista a la izquierda o a la derecha para quitarla de la cola.';

  @override
  String get swipeBetweenTabs => 'Deslizar para cambiar de pestaña';

  @override
  String get swipeHorizontallyOnMiniPlayer =>
      'Deslizar horizontalmente sobre el minirreproductor';

  @override
  String get swipeLeftRightOnThe =>
      'Desliza el minirreproductor a la izquierda o a la derecha para ir a la pista siguiente o anterior (si está habilitado en Ajustes).';

  @override
  String get swipeOnAQueueItem => 'Deslizar un elemento de la cola';

  @override
  String get swipeToSwitch => 'Deslizar para cambiar';

  @override
  String get syncStudio => 'Estudio de sincronización';

  @override
  String get tapAFolderToPlay =>
      'Toca una carpeta para reproducir todas las canciones que contiene, incluidas las subcarpetas.';

  @override
  String get tapAPlaylistToPlay =>
      'Toca una lista para reproducirla en orden o usa el botón Aleatorio para mezclar las canciones.';

  @override
  String get tapAnySongToPlay =>
      'Toca cualquier canción para reproducirla de inmediato. La cola se reconstruye a partir de esa canción.';

  @override
  String get tapAnywhereOnTheMini =>
      'Toca cualquier parte del minirreproductor para ampliarlo y abrir el reproductor completo.';

  @override
  String get tapShuffleToToggleRandom =>
      'Toca Aleatorio para activar el orden aleatorio. Toca Repetir para alternar entre desactivado → todo → una canción. Mantén presionado cualquiera de los dos para ver más opciones.';

  @override
  String get tapTheAlbumArtTo =>
      'Toca la portada para alternar entre la vista de portada y la de un disco de vinilo giratorio.';

  @override
  String get tapTheButtonToCreate =>
      'Toca el botón + para crear una lista de reproducción. Ponle un nombre y agrega canciones manteniendo presionada cualquier canción y eligiendo Agregar a la lista.';

  @override
  String get tapTheCheckIconIn =>
      'Toca la marca de verificación del encabezado para entrar en el modo de selección. Elige varias canciones para agregarlas a la cola o a una lista, o para eliminarlas en lote.';

  @override
  String get tapTheEQIconTo =>
      'Toca el ícono del ecualizador para abrirlo y ver los preajustes y los controles manuales de bandas.';

  @override
  String get tapTheEditIconIn =>
      'Toca el ícono de edición de las letras para abrir el Estudio de letras y sincronización.';

  @override
  String get tapTheHeartOnA =>
      'Toca el corazón de una canción (en el reproductor completo o en el menú que aparece al mantenerla presionada) para marcarla como favorita.';

  @override
  String get tapTheLyricsIconIn =>
      'Toca el ícono de letras en el reproductor completo. Las letras sincronizadas se desplazan y resaltan automáticamente; las que no están sincronizadas aparecen como texto normal.';

  @override
  String get tapTheLyricsIconTo =>
      'Toca el ícono de letras para abrir su vista. Si hay letras sincronizadas, se resaltarán al ritmo de la música.';

  @override
  String get tapTheMiniPlayerThe =>
      'Toca el minirreproductor para ampliarlo. Se abrirá el reproductor completo con la portada del álbum, la barra de reproducción con forma de onda y todos los controles.';

  @override
  String get tapTheQueueIconTo =>
      'Toca el ícono de la cola para ver y reordenar las próximas pistas. Arrástralas para cambiar el orden o desliza para quitarlas.';

  @override
  String get tapTheSortIconTop =>
      'Toca el ícono de orden (arriba a la derecha del encabezado) para abrir el panel Ordenar y filtrar. Ordena por título, artista, álbum, fecha en que se agregó o última reproducción. Filtra por tipo de archivo (FLAC, MP3, etc.).';

  @override
  String get tapToHideControlsFor =>
      'Toca para ocultar los controles y dejar solo la portada del álbum. Toca otra vez para mostrarlos.';

  @override
  String get theLeftAndRightAction =>
      'Puedes personalizar los botones de acción izquierdo y derecho, sobre la fila de reproducción, en Ajustes → Diseño del reproductor → Acciones rápidas.';

  @override
  String get theMiniPlayerSitsAbove =>
      'El minirreproductor aparece sobre la barra de navegación y muestra la portada, el título y el artista de la pista actual, junto con su progreso.';

  @override
  String get theSongsTabListsEvery =>
      'La pestaña Canciones muestra todas las pistas que Flick ha analizado. Desplázate para explorar o usa la barra de búsqueda para filtrar por título o artista.';

  @override
  String get theWidgetShowsCurrentTrack =>
      'El widget muestra la portada y el título de la pista actual, con controles para reproducir, pausar y avanzar. Toca la portada para abrir la app.';

  @override
  String get thisScreenReopenAnytimeFrom =>
      'Esta pantalla. Puedes volver a abrirla en cualquier momento desde Ajustes → Ayuda y manual.';

  @override
  String get toggleTheAudioVisualizerOn =>
      'Activa o desactiva el visualizador de audio y cambia su estilo desde el ícono del visualizador.';

  @override
  String get toggleTheMasterSwitchAt =>
      'Activa o desactiva el interruptor principal de arriba para omitir el ecualizador sin perder tus ajustes.';

  @override
  String get toggling => 'Activando o desactivando';

  @override
  String get uac2USBDACPreferencesAnd =>
      'Preferencias del DAC USB UAC2 y ajustes del ecualizador.';

  @override
  String get useTheWaveformScrubberTo =>
      'Usa la barra de reproducción con forma de onda para ir a una línea que te perdiste.';

  @override
  String get viewingLyrics => 'Viendo las letras';

  @override
  String get viewingTheQueue => 'Viendo la cola';

  @override
  String get vinylMorph => 'Efecto de transformación en vinilo';

  @override
  String get visualizerToggle => 'Activar o desactivar el visualizador';

  @override
  String get warmth => 'Calidez';

  @override
  String get vignette => 'Viñeta';

  @override
  String get rotateLeft => 'Girar a la izquierda';

  @override
  String get rotateRight => 'Girar a la derecha';

  @override
  String get flipHorizontal => 'Voltear horizontalmente';

  @override
  String get flipVertical => 'Voltear verticalmente';

  @override
  String get filterOriginal => 'Original';

  @override
  String get filterMono => 'Mono';

  @override
  String get filterWarm => 'Cálido';

  @override
  String get filterCool => 'Frío';

  @override
  String get filterFade => 'Desvanecido';

  @override
  String get filterPunch => 'Intenso';

  @override
  String get filterNoir => 'Noir';

  @override
  String get create => 'Crear';

  @override
  String get createACollection => 'Crear una colección';

  @override
  String get createACustomPreset => 'Crear un preajuste personalizado';

  @override
  String get createAPlaylistImportAnM3u =>
      'Crea una lista de reproducción, importa una lista M3U o deja que las mezclas de arriba acompañen la sesión.';

  @override
  String get createLyrics => 'Crear letras';

  @override
  String get createNewPlaylist => 'Crear una lista de reproducción';

  @override
  String get createNewPlaylist2 => 'Crear una lista de reproducción';

  @override
  String get createOrRefreshPlaylistsFoundInside =>
      'Crear o actualizar las listas de reproducción encontradas en las carpetas analizadas';

  @override
  String get createPlaylist => 'Crear lista de reproducción';

  @override
  String get createPlaylistFromSelected => 'Crear una lista con la selección';

  @override
  String get createYourFirstPlaylistOrJump =>
      'Crea tu primera lista de reproducción o abre una de tus colecciones guardadas.';

  @override
  String get createYourFirstPlaylistToOrganize =>
      'Crea tu primera lista de reproducción para organizar\ntus canciones favoritas';

  @override
  String created(Object arg1) {
    return 'Creada: $arg1';
  }

  @override
  String createdAndAddedSong(Object arg1) {
    return 'Se creó $arg1 y se agregó la canción';
  }

  @override
  String createdAndAddedSongs(Object name, Object arg1) {
    return 'Se creó $name y se agregaron $arg1 canciones';
  }

  @override
  String get creativeFx => 'Efectos creativos';

  @override
  String credentialsRejectedByReEnterThe(Object arg1) {
    return '$arg1 rechazó las credenciales. Vuelve a ingresar la contraseña.';
  }

  @override
  String get credentialsSavedSuccessfully =>
      'Las credenciales se guardaron correctamente.';

  @override
  String get crispestHeavierDuringFastScrolling =>
      'Más nítido: mayor carga durante el desplazamiento rápido';

  @override
  String get crossfade => 'Fundido cruzado';

  @override
  String get crossfadeIsMostReliableOnThe =>
      'El fundido cruzado funciona mejor con el motor Estándar. Puede ser inestable con el motor de alta calidad (Rust); cambia a Estándar para obtener transiciones uniformes.';

  @override
  String get crossfeed => 'Mezcla entre canales';

  @override
  String get crossfeedBs2b => 'Mezcla entre canales (BS2B)';

  @override
  String get crossfeedEasy => 'Mezcla entre canales sencilla';

  @override
  String get crossfeedRunsOnTheHighQuality =>
      'La mezcla entre canales solo funciona con el motor de alta calidad (Rust). El motor Estándar reproduce el audio sin este efecto.';

  @override
  String get crystalCaverns => 'Crystal Caverns';

  @override
  String get cueSheetTracksCannotBeEdited =>
      'No se pueden editar las pistas de una hoja CUE.';

  @override
  String get cueSheetTracksCannotBeEdited2 =>
      'No se pueden editar las pistas de una hoja CUE';

  @override
  String get currentArtwork => 'Portada actual';

  @override
  String get currentCustomArt => 'Imagen personalizada actual';

  @override
  String get currentPlaybackMode => 'Modo de reproducción actual';

  @override
  String currentRoute(Object arg1) {
    return 'Ruta actual: $arg1.';
  }

  @override
  String get currentSongPreviewOnly => 'Canción actual · solo vista previa';

  @override
  String get currentStreak => 'Racha actual';

  @override
  String get curvature => 'Curvatura';

  @override
  String get curvatureSizingDepthAndVisuals =>
      'Curvatura, tamaño, profundidad y efectos visuales';

  @override
  String get curve => 'Curva';

  @override
  String get curveOfTheOrbitArcHigher =>
      'Curva del arco orbital: cuanto mayor sea, más suave';

  @override
  String get curvePreview => 'Vista previa de la curva';

  @override
  String get curvedWave => 'Onda curva';

  @override
  String get custom => 'Personalizado';

  @override
  String get customFormat => 'Formato personalizado';

  @override
  String get customFormatForcesPlaybackToThe =>
      'El formato personalizado obliga a reproducir en el formato de salida seleccionado. Si la frecuencia de muestreo, la profundidad de bits o los canales elegidos no son adecuados para la canción o el dispositivo, el sonido, el tono, la velocidad o la estabilidad podrían verse afectados.';

  @override
  String get customFormatIsDisabledInBit =>
      'El formato personalizado está desactivado en el modo Bit perfecto (DAC USB), que requiere una coincidencia exacta de la frecuencia de muestreo. Desactiva Bit perfecto (DAC USB) para usar formatos personalizados.';

  @override
  String get customFormatIsUnavailableBecauseAudio =>
      'El formato personalizado no está disponible porque el formato de audio está desactivado en Ajustes.';

  @override
  String get customWidth => 'Ancho personalizado';

  @override
  String get customizeBottomBar => 'Personalizar la barra inferior';

  @override
  String get customizeHomeScreenWidgets =>
      'Personalizar los widgets de la pantalla de inicio';

  @override
  String get customizeOrbital => 'Personalizar Orbital';

  @override
  String get customizeWhichTabsAppearAndTheir =>
      'Personaliza qué pestañas aparecen y su tamaño';

  @override
  String dAgo(Object arg1) {
    return 'hace $arg1 d';
  }

  @override
  String dAgo2(Object arg1) {
    return 'hace $arg1 d';
  }

  @override
  String get dacClaim => 'Asignación del DAC';

  @override
  String dacWillBeOfferedAgain(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se volverán a ofrecer $count DAC',
      one: 'Se volverá a ofrecer $count DAC',
    );
    return '$_temp0.';
  }

  @override
  String get daily => 'Diario';

  @override
  String get damp => 'Amortiguación';

  @override
  String get dapNativeBitOrder => 'Orden de bits nativo del DAP';

  @override
  String get dapNativeByteGrouping => 'Agrupación de bytes nativa del DAP';

  @override
  String get dark => 'Oscuro';

  @override
  String get dataCollection => 'Recopilación de datos';

  @override
  String get date => 'Fecha';

  @override
  String get dateAdded => 'Fecha en que se agregó';

  @override
  String get dateAddedNewest => 'Fecha en que se agregó (más reciente)';

  @override
  String get dateAddedOldest => 'Fecha en que se agregó (más antigua)';

  @override
  String get dayStreak => 'días seguidos';

  @override
  String get dayStreak2 => 'Racha diaria';

  @override
  String get dayStreak3 => 'Racha diaria';

  @override
  String get dayStreaks => 'Rachas diarias';

  @override
  String dayUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'días',
      one: 'día',
    );
    return '$_temp0';
  }

  @override
  String db10(Object arg1) {
    return '$arg1 dB';
  }

  @override
  String db13(Object arg1) {
    return '$arg1 dB';
  }

  @override
  String db15(Object arg1, Object arg2) {
    return '$arg1%  $arg2 dB';
  }

  @override
  String db2(Object value) {
    return '$value dB';
  }

  @override
  String db9(Object arg1) {
    return '$arg1 dB';
  }

  @override
  String dbCut(Object arg1) {
    return 'atenuación de $arg1 dB';
  }

  @override
  String dbMax(Object arg1) {
    return 'máx. $arg1 dB';
  }

  @override
  String get deactivateFallback => 'Desactivar alternativa';

  @override
  String get dec => 'dic';

  @override
  String get decode => 'Decodificar';

  @override
  String get decodeSongsAfterScanningToCache =>
      'Decodificar las canciones después del análisis para guardar en caché los picos de forma de onda y las métricas de volumen';

  @override
  String get deepEarth => 'Deep Earth';

  @override
  String get deepScan => 'Análisis profundo';

  @override
  String get deepScanOff => 'Análisis profundo desactivado';

  @override
  String get deepScanOn => 'Análisis profundo activado';

  @override
  String get defaultAndroidPlaybackEngineUsedBy =>
      'Motor de reproducción predeterminado de Android que Flick usa actualmente.';

  @override
  String get defaultAndroidPlayerPlaysEverything =>
      'Reproductor predeterminado de Android: reproduce todo de forma confiable. La opción más segura para la mayoría de las personas.';

  @override
  String get defaultLabel => 'Predeterminado';

  @override
  String get del => 'Supr';

  @override
  String get delays => 'Retardos';

  @override
  String get delete => 'Eliminar';

  @override
  String deleteAndAllSongsAndPlaylists(Object arg1) {
    return '¿Eliminar «$arg1» y todas las canciones y listas sincronizadas desde ahí? Se conservarán las descargas en caché.';
  }

  @override
  String get deleteFile => 'Eliminar archivo';

  @override
  String get deleteFiles => 'Eliminar archivos';

  @override
  String get deletePlaylist => 'Eliminar lista de reproducción';

  @override
  String get deletePreset => '¿Eliminar el preajuste?';

  @override
  String get deleteSelected => 'Eliminar selección';

  @override
  String get deleteSong => 'Eliminar canción';

  @override
  String get deleteSong2 => '¿Eliminar la canción?';

  @override
  String get deleteSong3 => 'Eliminar canción';

  @override
  String deleteSongs(Object arg1) {
    return '¿Eliminar $arg1 canciones?';
  }

  @override
  String get deleteSongs2 => 'Eliminar canciones';

  @override
  String deleteThisCannotBeUndone(Object arg1) {
    return '¿Eliminar «$arg1»? Esta acción no se puede deshacer.';
  }

  @override
  String deleted(Object arg1) {
    return 'Se eliminó «$arg1»';
  }

  @override
  String deletedSongs(Object arg1) {
    return 'Se eliminaron $arg1 canciones';
  }

  @override
  String get depth => 'Profundidad';

  @override
  String get deselectAll => 'Anular selección de todo';

  @override
  String get designed => 'Diseñado';

  @override
  String get detailScreens => 'Pantallas de detalles';

  @override
  String get details => 'Detalles';

  @override
  String get developerMode => 'Modo de desarrollador';

  @override
  String get developerOptionsIsDisabledEnableIt =>
      'Las Opciones para desarrolladores están desactivadas. Actívalas en Ajustes → Acerca del teléfono (toca 7 veces Número de compilación) y vuelve a intentarlo.';

  @override
  String get device => 'Dispositivo';

  @override
  String get deviceCapabilities => 'Capacidades del dispositivo';

  @override
  String get deviceConnected => 'Dispositivo conectado';

  @override
  String get deviceDac => 'DAC del dispositivo';

  @override
  String get deviceDacVolume => 'Volumen del DAC del dispositivo';

  @override
  String get deviceDisconnected => 'Dispositivo desconectado';

  @override
  String get deviceInformation => 'Información del dispositivo';

  @override
  String get deviceType => 'Tipo de dispositivo';

  @override
  String get devices => 'Dispositivos';

  @override
  String get direct => 'Directo';

  @override
  String get directAlsaOutputIsActiveAnd =>
      'La salida ALSA directa está activa y omite el servidor de audio de Android.';

  @override
  String get directLibusbIsochronousUsbEngineBest =>
      'Motor USB isócrono directo con libusb. Se recomienda combinarlo con Bit perfecto (DAC USB) para verificar la reproducción en un DAC externo.';

  @override
  String get directUsb => 'USB directo';

  @override
  String get directUsbDeviceManaged =>
      'USB directo administrado por el dispositivo';

  @override
  String get directUsbExperimental => 'USB directo experimental';

  @override
  String get disableBatteryOptimization =>
      'Desactivar la optimización de batería';

  @override
  String get disableBatteryOptimizationRecommended =>
      'Desactivar la optimización de batería (recomendado)';

  @override
  String get disabled => 'Desactivado';

  @override
  String get disabledInBitPerfectMode => 'Desactivado en modo bit perfecto';

  @override
  String get disabledInBitPerfectUsbDac =>
      'Desactivado en modo Bit perfecto (DAC USB) (requiere una frecuencia exacta)';

  @override
  String get disabledWhileBothBitPerfectOptions =>
      'Desactivado porque las dos opciones de bit perfecto están apagadas en este DAP.';

  @override
  String get disc => 'Disco';

  @override
  String get disc2 => 'Disco n.º';

  @override
  String get discard => 'Descartar';

  @override
  String get discardChanges => '¿Descartar los cambios?';

  @override
  String get discardChanges2 => '¿Descartar los cambios?';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get disconnectBehaviorAndCodecInfo =>
      'Comportamiento al desconectarse e información del códec';

  @override
  String disconnectFrom(Object arg1) {
    return 'Desconectar de $arg1';
  }

  @override
  String get disconnectLastFm => '¿Desconectar Last.fm?';

  @override
  String get disconnectListenbrainz => '¿Desconectar ListenBrainz?';

  @override
  String get discord => 'Discord';

  @override
  String get discoversDlnaUpnpAndChromecastReceivers =>
      'Busca receptores DLNA, UPnP y Chromecast en tu red';

  @override
  String get dismiss => 'Descartar';

  @override
  String get display => 'Pantalla';

  @override
  String get displayFileFormatAndBitrateIn =>
      'Mostrar el formato de archivo y la tasa de bits en el modo inmersivo';

  @override
  String get displayFileFormatAndBitrateIn2 =>
      'Mostrar el formato de archivo y la tasa de bits en el modo de tarjeta con portada';

  @override
  String get displayTextLabelsBelowIcons =>
      'Mostrar etiquetas de texto debajo de los íconos';

  @override
  String get displayTheAlbumNameInArtwork =>
      'Mostrar el nombre del álbum en el modo de tarjeta con portada';

  @override
  String get displayTheArtistNameInArtwork =>
      'Mostrar el nombre del artista en el modo de tarjeta con portada';

  @override
  String get displayTheArtistNameInImmersive =>
      'Mostrar el nombre del artista en el modo inmersivo';

  @override
  String get displayTheTrackTitleInArtwork =>
      'Mostrar el título de la pista en el modo de tarjeta con portada';

  @override
  String get displayTheTrackTitleInImmersive =>
      'Mostrar el título de la pista en el modo inmersivo';

  @override
  String get distanceBetweenSongsAlongTheArc =>
      'Distancia entre canciones a lo largo del arco';

  @override
  String get dlnaAndUpnpReceiversAreControlled =>
      'Los receptores DLNA y UPnP se controlan directamente con Dart puro, sin dependencias adicionales. La compatibilidad con Chromecast usa el SDK nativo de Cast. Se pueden transmitir fuentes de red (Subsonic, WebDAV, Jellyfin y UPnP), archivos locales y canciones en caché; los archivos locales se sirven directamente desde este teléfono. Mientras transmites, las teclas de volumen y el panel de volumen del sistema controlan el dispositivo conectado.';

  @override
  String get dlnaUpnp => 'DLNA / UPnP';

  @override
  String get dlnaUpnpAndChromecastReceivers =>
      'Receptores DLNA, UPnP y Chromecast';

  @override
  String get donTShowAgainToday => 'No volver a mostrar hoy';

  @override
  String get donate => 'Donar';

  @override
  String get donateFundFeaturesAndKeepThe =>
      'Contribuye, apoya nuevas funciones y ayuda a mantener viva la app';

  @override
  String get done => 'Listo';

  @override
  String get dop => 'DoP';

  @override
  String get dots => 'Puntos';

  @override
  String get doubleTapABandToReset =>
      'Toca dos veces una banda para restablecerla';

  @override
  String get doubleTapToReset => 'Toca dos veces para restablecer';

  @override
  String get doubleTapToResetThisBand =>
      'Toca dos veces para restablecer esta banda';

  @override
  String down(Object arg1) {
    return '$arg1 abajo';
  }

  @override
  String get downloadTheLatestApkFromFlick =>
      'Descarga el APK más reciente desde flick-player.site';

  @override
  String get downloadUpdate => 'Descargar actualización';

  @override
  String dp(Object arg1) {
    return '$arg1 dp';
  }

  @override
  String dp2(Object arg1) {
    return '$arg1 dp';
  }

  @override
  String dp3(Object arg1) {
    return '$arg1 dp';
  }

  @override
  String get dragABoundaryToStretchOr =>
      'Arrastra un límite para alargar o acortar la palabra anterior. El último límite desplaza la línea siguiente.';

  @override
  String get dragBandsUpOrDown => 'Arrastra las bandas hacia arriba o abajo';

  @override
  String get dragToChangeFrequencyGain =>
      'Arrastra para cambiar la frecuencia y la ganancia';

  @override
  String get dragToMovePinchToWiden =>
      'Arrastra para mover • Pellizca para ampliar o reducir';

  @override
  String get dragVerticallyToChangeGain =>
      'Arrastra verticalmente para cambiar la ganancia';

  @override
  String get drawTheCurvedArcBehindThe =>
      'Dibujar el arco curvo detrás de las canciones';

  @override
  String driftMs(Object arg1) {
    return 'Desfase de $arg1 ms';
  }

  @override
  String get dsdDsfPlayback => 'Reproducción DSD / DSF';

  @override
  String get dsdMode => 'Modo DSD';

  @override
  String get dsdOutputMode => 'Modo de salida DSD';

  @override
  String get dsdStream => 'Flujo DSD';

  @override
  String get duckOnNotifications => 'Atenuar el audio con las notificaciones';

  @override
  String get duplicateCleaner => 'Limpiador de duplicados';

  @override
  String get duplicatesRemovedUsingRecommendedPicks =>
      'Se quitaron los duplicados con las selecciones recomendadas.';

  @override
  String get duration => 'Duración';

  @override
  String get durationMatch => 'Coincidencia de duración';

  @override
  String get dynamics => 'Dinámica';

  @override
  String get earlier => 'Anterior';

  @override
  String get earlierStandoutsPulledBackIntoView =>
      'Canciones destacadas de antes que vuelven a aparecer gracias a tu historial de escucha.';

  @override
  String get editCredentials => 'Editar credenciales';

  @override
  String get editDescription => 'Editar descripción';

  @override
  String get editDescription2 => 'Editar descripción';

  @override
  String get editMetadata => 'Editar metadatos';

  @override
  String get editServer => 'Editar servidor';

  @override
  String get editSync => 'Editar y sincronizar';

  @override
  String get editText => 'Editar texto';

  @override
  String get editToken => 'Editar token';

  @override
  String get electricSunset => 'Atardecer eléctrico';

  @override
  String get empty => 'Vacío';

  @override
  String get emptyLine => '(Línea vacía)';

  @override
  String get emptyTheLibraryFilesOnDisk =>
      'Vaciar la biblioteca; se conservarán los archivos del disco';

  @override
  String get enable => 'Activar';

  @override
  String get enable432HzTuning => '¿Activar la afinación a 432 Hz?';

  @override
  String get enableAnimatedTransitionsAndEffects =>
      'Activar transiciones y efectos animados';

  @override
  String get enableEqToEdit => 'Activar el ecualizador para editarlo';

  @override
  String get enableFullLibraryAccess =>
      'Activar acceso completo a la biblioteca';

  @override
  String get enableVibrationOnInteractions =>
      'Activar la vibración al interactuar';

  @override
  String get enabled => 'Activado';

  @override
  String get endpoint => 'Punto de conexión';

  @override
  String get engine => 'Motor';

  @override
  String get engineSelector => 'Selector de motor';

  @override
  String get english => 'Inglés';

  @override
  String enterAValidNumber(Object label) {
    return 'Ingresa un número válido para $label';
  }

  @override
  String enterAValueFromTo(Object arg1, Object arg2) {
    return 'Ingresa un valor entre $arg1% y $arg2%';
  }

  @override
  String get enterAYear19999 => 'Ingresa un año (1–9999)';

  @override
  String get enterYourApiKey => 'Ingresa tu clave de API';

  @override
  String get enterYourSharedSecret => 'Ingresa tu secreto compartido';

  @override
  String ep(Object arg1) {
    return 'EP $arg1';
  }

  @override
  String get eqDynamics => 'Ecualizador y dinámica';

  @override
  String get equalPower => 'Potencia constante';

  @override
  String get equalizer => 'Ecualizador';

  @override
  String error(Object error) {
    return 'Error: $error';
  }

  @override
  String error2(Object arg1) {
    return 'Error: $arg1';
  }

  @override
  String get error3 => 'Error';

  @override
  String errorLoadingCapabilities(Object error) {
    return 'Error al cargar las capacidades: $error';
  }

  @override
  String get errorLoadingPlaylists =>
      'Error al cargar las listas de reproducción';

  @override
  String errorLoadingPlaylists2(Object error) {
    return 'Error al cargar las listas de reproducción: $error';
  }

  @override
  String get errorLoadingPreference => 'Error al cargar la preferencia';

  @override
  String get errorLoadingSongs => 'Error al cargar las canciones';

  @override
  String get etherealTones => 'Tonos etéreos';

  @override
  String get everyAlbumHasArtistAndAlbum =>
      'Todos los álbumes tienen etiquetas de artista y de álbum.';

  @override
  String get everySongIsRemovedFromYour =>
      'Se quitarán de tu biblioteca todas las canciones. Se conservarán los archivos del disco; vuelve a analizar las carpetas para agregarlas otra vez.';

  @override
  String get exactMatch => 'Coincidencia exacta';

  @override
  String get excludeTinyClipsPreviewsAndAccidental =>
      'Excluir clips muy cortos, vistas previas y fragmentos accidentales';

  @override
  String get exclusiveDirectPcmIsActiveAnd =>
      'La salida PCM directa exclusiva está activa y omite el mezclador de Android usando la frecuencia nativa de la pista.';

  @override
  String get exclusiveUsbBitPerfectReEngaged =>
      'Se reactivó el modo bit perfecto USB exclusivo.';

  @override
  String get exclusiveUsbDroppedToTheAndroid =>
      'La conexión USB exclusiva pasó al mezclador de Android. El modo bit perfecto está en pausa.';

  @override
  String get exclusiveUsbIsActiveAndBypassing =>
      'La conexión USB exclusiva está activa y omite el mezclador de Android.';

  @override
  String get exclusiveUsbIsStillUnavailableCheck =>
      'USB exclusivo sigue sin estar disponible. Consulta los diagnósticos USB.';

  @override
  String get expanded => 'Expandido';

  @override
  String get expandedHeaderArt => 'Portada del encabezado expandido';

  @override
  String get expectedAJsonObject => 'Se esperaba un objeto JSON.';

  @override
  String get experimental => 'Experimental';

  @override
  String get experimentalDownTunePlaybackBy432 =>
      'Experimental: multiplica la velocidad de reproducción por 432/440 para bajar la afinación de 440 a 432 Hz. Esto desactiva el paso directo bit-perfect y usa la ruta DSP.';

  @override
  String get exportAsM3u => 'Exportar como .m3u';

  @override
  String get exportAsM3u8 => 'Exportar como .m3u8';

  @override
  String get exportCsv => 'Exportar CSV';

  @override
  String get exportCurrentPreset => 'Exportar el preajuste actual';

  @override
  String get exportEqualizerPreset => 'Exportar preajuste del ecualizador';

  @override
  String exportFailed(Object e) {
    return 'Error al exportar: $e';
  }

  @override
  String get exportFormat => 'Formato de exportación';

  @override
  String get exportTxt => 'Exportar TXT';

  @override
  String exportedPresetTo(Object savePath) {
    return 'Se exportó el preajuste a $savePath';
  }

  @override
  String exportedPresetTo2(Object fallbackPath) {
    return 'Se exportó el preajuste a $fallbackPath';
  }

  @override
  String exportedSongsTo(Object arg1, Object arg2) {
    return 'Se exportaron $arg1 canciones a «$arg2».';
  }

  @override
  String get extendedVolume => 'Volumen ampliado';

  @override
  String get externalLabel => 'Externo';

  @override
  String get externalSongsCannotBeEdited =>
      'No se pueden editar canciones externas.';

  @override
  String get externalSongsCannotBeEdited2 =>
      'No se pueden editar canciones externas';

  @override
  String get extraCovers => 'Portadas adicionales';

  @override
  String get failedToActivateFallback => 'No se pudo activar la alternativa';

  @override
  String failedToAddFolder(Object e) {
    return 'No se pudo agregar la carpeta: $e';
  }

  @override
  String failedToAddToFavorites(Object arg1) {
    return 'No se pudo agregar «$arg1» a favoritos';
  }

  @override
  String failedToClearCache(Object e) {
    return 'No se pudo borrar la caché: $e';
  }

  @override
  String get failedToDeactivateFallback =>
      'No se pudo desactivar la alternativa';

  @override
  String failedToDownloadAlbumArt(int status) {
    return 'No se pudo descargar la portada del álbum (HTTP $status).';
  }

  @override
  String failedToGetPersistedUris(String? error) {
    return 'No se pudieron obtener los URI persistentes: $error';
  }

  @override
  String get failedToImportPresetFile =>
      'No se pudo importar el archivo de preajuste.';

  @override
  String failedToOpenAllFilesAccess(Object e) {
    return 'No se pudo abrir la configuración de acceso a todos los archivos: $e';
  }

  @override
  String failedToOpenBatteryOptimizationSettings(Object e) {
    return 'No se pudo abrir la configuración de optimización de batería: $e';
  }

  @override
  String failedToOpenFolderPicker(String? error) {
    return 'No se pudo abrir el selector de carpetas: $error';
  }

  @override
  String get failedToPersistFolderAccess =>
      'No se pudo conservar el acceso a la carpeta';

  @override
  String failedToPersistPermission(String? error) {
    return 'No se pudo conservar el permiso: $error';
  }

  @override
  String failedToReadBatteryOptimizationStatus(String? error) {
    return 'No se pudo leer el estado de optimización de batería: $error';
  }

  @override
  String failedToReleasePermission(String? error) {
    return 'No se pudo liberar el permiso: $error';
  }

  @override
  String failedToRemoveFolder(Object e) {
    return 'No se pudo quitar la carpeta: $e';
  }

  @override
  String failedToRemoveSongs(Object e) {
    return 'No se pudieron quitar las canciones: $e';
  }

  @override
  String failedToRequestBatteryOptimizationBypass(String? error) {
    return 'No se pudo solicitar la excepción a la optimización de batería: $error';
  }

  @override
  String get failedToSave => 'No se pudo guardar';

  @override
  String failedToSaveMetadata(Object e) {
    return 'No se pudieron guardar los metadatos: $e';
  }

  @override
  String get failedToSaveMetadata2 => 'No se pudieron guardar los metadatos.';

  @override
  String get failedToSaveTheRecapImage =>
      'No se pudo guardar la imagen del resumen en la galería.';

  @override
  String get failedToSearchAlbumArtOnline =>
      'No se pudo buscar la portada del álbum en línea.';

  @override
  String get failedToStartStreaming => 'No se pudo iniciar la transmisión';

  @override
  String get failedToStopStreaming => 'No se pudo detener la transmisión';

  @override
  String get failedToWritePlaylistFile =>
      'No se pudo escribir el archivo de la lista de reproducción';

  @override
  String get failedToWriteTagsToTheFile =>
      'No se pudieron escribir las etiquetas en el archivo.';

  @override
  String get faintHueShiftFromAlbumArt =>
      'Ligero cambio de tono a partir de la portada del álbum.';

  @override
  String get fallback => 'Alternativa';

  @override
  String get fallbackAudio => 'Audio alternativo';

  @override
  String get fallbackAudioActivated => 'Se activó el audio alternativo';

  @override
  String get fallbackAudioDeactivated => 'Se desactivó el audio alternativo';

  @override
  String get fallbackAudioWillBeUsedIf =>
      'Se usará el audio alternativo si falla el dispositivo UAC2';

  @override
  String get fastDirectTrackingImmediateResponse =>
      'Seguimiento directo rápido: respuesta inmediata';

  @override
  String get fastIndexScrolling => 'Desplazamiento rápido por el índice';

  @override
  String get favoriteAll => 'Agregar todo a favoritos';

  @override
  String get favoriteRemoval => 'Quitar de favoritos';

  @override
  String get favoriteSongs => 'Canciones favoritas';

  @override
  String get favorites => 'Favoritos';

  @override
  String get favoritesYouHaveNotRevisitedLately =>
      'Favoritos que hace tiempo no vuelves a escuchar';

  @override
  String get feb => 'feb';

  @override
  String get feedback => 'Comentarios';

  @override
  String get file => 'Archivo';

  @override
  String get fileInformation => 'Información del archivo';

  @override
  String get fileIsNoLongerAvailable =>
      'Este archivo ya no está disponible. Es posible que se haya movido o eliminado. Vuelve a analizar la biblioteca e inténtalo de nuevo.';

  @override
  String get filePath => 'Ruta del archivo';

  @override
  String files(Object done, Object total) {
    return '$done / $total archivos';
  }

  @override
  String files2(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos',
      one: '$count archivo',
    );
    return '$_temp0';
  }

  @override
  String filesChecked(Object arg1) {
    return 'Se revisaron $arg1 archivos…';
  }

  @override
  String get filter => 'Filtrar';

  @override
  String get filterByFormat => 'FILTRAR POR FORMATO';

  @override
  String get filterFilesSizeLimitsAndPlaylist =>
      'Filtrar archivos, establecer límites de tamaño y configurar la importación de listas de reproducción';

  @override
  String get filterLogs => 'Filtrar registros…';

  @override
  String get filterNonMusicFilesFolders =>
      'Filtrar archivos y carpetas que no sean de música';

  @override
  String get findAndCleanUpDuplicateSongs =>
      'Buscar y limpiar canciones duplicadas';

  @override
  String get findAndRemoveDuplicateSongs =>
      'Buscar y quitar canciones duplicadas';

  @override
  String get findSongsArtistsAlbumsFolders =>
      'Buscar canciones, artistas, álbumes y carpetas…';

  @override
  String get fineTuneTheOverallGain =>
      'Ajustar con precisión la ganancia general';

  @override
  String get finishingMetadataEnrichment =>
      'Finalizando el enriquecimiento de metadatos…';

  @override
  String finishingMetadataForSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Finalizando los metadatos de $count canciones…',
      one: 'Finalizando los metadatos de $count canción…',
    );
    return '$_temp0';
  }

  @override
  String get finishingUp => 'Terminando…';

  @override
  String get fix => 'Corregir';

  @override
  String get fixMissingMetadata => 'Corregir metadatos faltantes';

  @override
  String get fixedBands => '31 bandas fijas';

  @override
  String fixedCenterFrequenciesWithADb(Object arg1) {
    return 'Frecuencias centrales fijas con un rango de $arg1 dB. Toca para interactuar.';
  }

  @override
  String get flac24Bit96Khz => 'FLAC · 24 bits / 96 kHz';

  @override
  String get flat => 'Plano';

  @override
  String get flatResponse => 'Respuesta plana';

  @override
  String get flick => 'Flick';

  @override
  String get flickCanAttemptToPreferA =>
      'Flick puede intentar dar prioridad al códec seleccionado arriba, pero el resultado depende del dispositivo, los audífonos y la versión de Android. Para forzar el códec se usa una API oculta del sistema y puede que no funcione en dispositivos sin root.';

  @override
  String get flickCanReceivePlaybackHandoffsFrom =>
      'Flick puede recibir transferencias de reproducción de Locker (otra app de Moss). Las solicitudes de reproducción solo contienen las rutas y los metadatos de los archivos de canciones. No se intercambian datos personales. La integración funciona completamente de forma local.';

  @override
  String get flickChecksFlickPlayerSiteFor =>
      'Flick busca actualizaciones en flick-player.site cuando tienes conexión a internet';

  @override
  String get flickIsBuiltAndMaintainedBy =>
      'Flick lo desarrolla y mantiene una sola persona, sin presupuesto. No hay equipo, financiación ni anuncios.';

  @override
  String get flickLogs => 'Registros de Flick';

  @override
  String get flickNoLongerHasPermissionToEditThisFile =>
      'Flick ya no tiene permiso para editar este archivo. Vuelve a agregar su carpeta en Ajustes para conceder acceso de edición e inténtalo de nuevo.';

  @override
  String get flickPlayer => 'Flick Player';

  @override
  String get flickPlayerDoesNotCollectStore =>
      'Flick Player no recopila, almacena ni transmite datos personales. No reúne información personal, estadísticas de uso, informes de fallos ni identificadores publicitarios. No comparte datos con terceros.';

  @override
  String get flickPreview => 'Vista previa de Flick';

  @override
  String get flickReplay => 'Flick Replay';

  @override
  String get flickScansForPlayStoreUpdates =>
      'Flick busca actualizaciones en Play Store cuando tienes conexión a internet';

  @override
  String get flickWillAlwaysBeFreeDonations =>
      'Flick siempre será gratis. Las donaciones mantienen vivo el proyecto sin muros de pago ni suscripciones.';

  @override
  String get flickWillForceYourChosenCodec =>
      'Flick forzará el códec que elegiste al conectarse';

  @override
  String get flickplayer => 'FlickPlayer';

  @override
  String get floatingIsland => 'Isla flotante';

  @override
  String get floatingMiniPlayer => 'Minirreproductor flotante';

  @override
  String get folder => 'Carpeta';

  @override
  String get folderLimit => 'LÍMITE DE CARPETAS';

  @override
  String get folderName => 'Nombre de la carpeta';

  @override
  String folderOf(Object current, Object total) {
    return 'Carpeta $current de $total';
  }

  @override
  String folderOf2(Object current, Object total) {
    return 'Carpeta $current de $total';
  }

  @override
  String get folderSongCount => 'Cantidad de canciones en la carpeta';

  @override
  String get folders => 'Carpetas';

  @override
  String folders2(Object arg1) {
    return '$arg1 carpetas';
  }

  @override
  String get foldersScanningAndDuplicates => 'Carpetas, análisis y duplicados';

  @override
  String get foldersShownPerPage => 'Carpetas por página';

  @override
  String get fontScale => 'Escala de fuente';

  @override
  String get footerLine => 'Línea de pie';

  @override
  String get forceDop => 'Forzar DoP';

  @override
  String get forceDopAlwaysUseDsdOver =>
      'Forzar DoP: usar siempre DSD sobre PCM (DAC USB)';

  @override
  String get forcePcm => 'Forzar PCM';

  @override
  String get forcePcmAlwaysConvertDsdTo =>
      'Forzar PCM: convertir siempre DSD a PCM';

  @override
  String get format => 'Formato';

  @override
  String get formatControlsAreDisabledTheEngine =>
      'Los controles de formato están desactivados. El motor usa el formato predeterminado.';

  @override
  String get formatStrategy => 'Estrategia de formato';

  @override
  String get formatStrategyAndCustomFormatControls =>
      'La estrategia de formato y los controles de formato personalizado están activos.';

  @override
  String get formatStrategyIsDisabledInBit =>
      'La estrategia de formato está desactivada en el modo Bit perfecto (DAC USB), que requiere una coincidencia exacta de la frecuencia de muestreo. Desactiva Bit perfecto (DAC USB) para cambiar las preferencias de formato.';

  @override
  String get formatStrategyIsUnavailableBecauseAudio =>
      'La estrategia de formato no está disponible porque el formato de audio está desactivado en Ajustes.';

  @override
  String foundOnline(Object arg1) {
    return 'Se encontró «$arg1» en línea.';
  }

  @override
  String frPkt(Object arg1) {
    return '$arg1 tramas/paquete';
  }

  @override
  String get freeOpenSource => 'Gratis y de código abierto';

  @override
  String get freq => 'Frec.';

  @override
  String get frequency => 'Frecuencia';

  @override
  String get frequencyFocus => 'Enfoque de frecuencias';

  @override
  String get freshAdditions => 'Novedades recientes';

  @override
  String from(Object sourceLabel) {
    return 'De $sourceLabel';
  }

  @override
  String get fromSquareCornersToARounded =>
      'De esquinas cuadradas a una barra redondeada';

  @override
  String get fullBleedAlbumArtWithThe =>
      'Portada del álbum a sangre, con la estética cinematográfica actual.';

  @override
  String get fullLibrary => 'Biblioteca completa';

  @override
  String get fullLibraryAccess => 'Acceso completo a la biblioteca';

  @override
  String get fullPlayer => 'Reproductor completo';

  @override
  String get fullScan => 'Análisis completo';

  @override
  String get fullSpectrum => 'Espectro completo';

  @override
  String get fullViewCardSize => 'Tamaño de tarjeta en vista completa';

  @override
  String get fullViewCardSize2 => 'Tamaño de tarjeta en vista completa';

  @override
  String get fullscreen => 'Pantalla completa';

  @override
  String get fundingNativeDsdDsfPlaybackDevelopment =>
      'Financia el desarrollo de la reproducción DSD/DSF nativa, una función muy solicitada por los audiófilos.';

  @override
  String get fxOff => 'Efectos desactivados';

  @override
  String get fxOn => 'Efectos activados';

  @override
  String get gain => 'Ganancia';

  @override
  String get gallery => 'Galería';

  @override
  String get gapAboveNavigation => 'Espacio sobre la navegación';

  @override
  String get gaplessPlayback => 'Reproducción sin pausas';

  @override
  String get gaplessViewModeAndAppearance =>
      'Reproducción sin pausas, modo de vista y apariencia';

  @override
  String gb(Object arg1) {
    return '$arg1 GB';
  }

  @override
  String get generatedFromYourListeningHabitsFavorites =>
      'Se generan a partir de tus hábitos de escucha, tus favoritos y lo que agregaste recientemente.';

  @override
  String get genre => 'Género';

  @override
  String get geometry => 'Geometría';

  @override
  String get getStarted => 'Comenzar';

  @override
  String get getTheLatestApkFromFlick =>
      'Descarga el APK más reciente desde flick-player.site';

  @override
  String get getYourApiCredentials => 'Obtener credenciales de API';

  @override
  String get github => 'GitHub';

  @override
  String get goToAlbum => 'Ir al álbum';

  @override
  String get goToArtist => 'Ir al artista';

  @override
  String get goodAfternoon => 'Buenas tardes';

  @override
  String get goodEvening => 'Buenas noches';

  @override
  String get goodMorning => 'Buenos días';

  @override
  String get gotIt => 'Entendido';

  @override
  String get grantBluetoothAccess => 'Conceder acceso a Bluetooth';

  @override
  String get grantedScansReadEveryVolumeDirectly =>
      'Concedido: el análisis lee directamente todos los volúmenes, incluidos DSD, DSF y WavPack';

  @override
  String get graphic => 'Gráfico';

  @override
  String get graphicEq => 'Ecualizador gráfico';

  @override
  String get green => 'Verde';

  @override
  String get groupingByTitleArtistThisIs =>
      'Agrupar por título y artista suele ser rápido.';

  @override
  String get groups => 'Grupos';

  @override
  String groupsToRemove(Object arg1, Object arg2) {
    return '$arg1 grupos • $arg2 por quitar';
  }

  @override
  String groupsToRemove2(Object arg1, Object toRemove) {
    return '$arg1 grupos • $toRemove por quitar';
  }

  @override
  String get growsFurtherIfLargerSystemText =>
      'Se amplía si el texto grande del sistema necesita más espacio';

  @override
  String hAgo(Object arg1) {
    return 'hace $arg1 h';
  }

  @override
  String get hapticFeedback => 'Respuesta háptica';

  @override
  String get hardwareUsbDac => 'Hardware (DAC USB)';

  @override
  String get hardwareVolumeIsDetectedButWrites =>
      'Se detecta el volumen del hardware, pero no se permiten cambios mientras está activa la reproducción USB directa.';

  @override
  String get hasArtwork => 'Tiene portada';

  @override
  String get havingMoreThan4ButtonsMay =>
      'Más de 4 botones pueden comprimir sus etiquetas de texto. Prueba a reducir el espacio entre los botones más abajo.';

  @override
  String get heavyRotation => 'En rotación frecuente';

  @override
  String get held => 'En espera';

  @override
  String get help => 'Ayuda';

  @override
  String get helpManual => 'Ayuda y manual';

  @override
  String get hiResDirect => 'Directo de alta resolución';

  @override
  String get hidden => 'Oculto';

  @override
  String get hideLyrics => 'Ocultar letras';

  @override
  String get hideNavigationButtonsAfterBeingIdle =>
      'Ocultar los botones de navegación tras un periodo de inactividad';

  @override
  String get hidePassword => 'Ocultar contraseña';

  @override
  String get hideShortStingersRingtonesAndVoice =>
      'Ocultar fragmentos cortos, tonos de llamada y fragmentos de voz';

  @override
  String get hideTheFloatingMiniPlayerPill =>
      'Ocultar la pastilla flotante del minirreproductor';

  @override
  String get hideTheIndexRailAfterInactivity =>
      'Ocultar el índice tras un periodo de inactividad';

  @override
  String get hideVisualizer => 'Ocultar visualizador';

  @override
  String get hideVisualizer2 => 'Ocultar visualizador';

  @override
  String get high => 'Alto';

  @override
  String get high120hz => 'Alto (120 Hz)';

  @override
  String get highFrequenciesOnly => 'Solo frecuencias altas';

  @override
  String get highPass => 'Filtro pasa altos';

  @override
  String get highQuality => 'Alta calidad';

  @override
  String get highQualityEngine => 'Motor de alta calidad';

  @override
  String get highQualityWidelySupported =>
      'Alta calidad y amplia compatibilidad';

  @override
  String get highResolutionAptx => 'aptX de alta resolución';

  @override
  String get highShelf => 'Filtro shelving de agudos';

  @override
  String get highestBitrateUpTo990Kbps =>
      'La tasa de bits más alta (hasta 990 kbps)';

  @override
  String get highestQuality => 'Máxima calidad';

  @override
  String get historyCleared => 'Se borró el historial';

  @override
  String get holdASongToUnfavorite =>
      'Mantén presionada una canción para quitarla de favoritos';

  @override
  String get homeScreenSections => 'Secciones de la pantalla de inicio';

  @override
  String get horizontalReach => 'Alcance horizontal';

  @override
  String hourUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'horas',
      one: 'hora',
    );
    return '$_temp0';
  }

  @override
  String get howFarTheArcOpensFrom =>
      'Qué tanto se abre el arco desde el borde izquierdo';

  @override
  String get howMuchSideCardsShrinkAway =>
      'Cuánto se reducen las tarjetas laterales al alejarse del centro';

  @override
  String get howWeHandleYourData => 'Cómo tratamos tus datos';

  @override
  String get howWideEachCardSpansAcross =>
      'Qué ancho ocupa cada tarjeta en la pantalla';

  @override
  String get httpBasicNeedsItRecoverableStored =>
      'HTTP Basic necesita poder recuperar la contraseña; se guarda codificada';

  @override
  String hz(Object rate) {
    return '$rate Hz';
  }

  @override
  String hz3(Object hz) {
    return '$hz Hz';
  }

  @override
  String get hz5 => 'Hz';

  @override
  String hz6(Object arg1) {
    return '$arg1 Hz';
  }

  @override
  String get hzTuning => 'Afinación a 432 Hz';

  @override
  String get iconSize => 'Tamaño de ícono';

  @override
  String identified(int count, Object note) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se identificaron $count canciones',
      one: 'Se identificó $count canción',
    );
    return '$_temp0$note.';
  }

  @override
  String get identifyAlbum => 'Identificar álbum';

  @override
  String get identifyAlbum2 => 'Identificar álbum';

  @override
  String get identifyAlbumsWithUnknownArtistOr =>
      'Identificar álbumes con etiquetas de artista o título desconocidas';

  @override
  String get idle => 'Inactivo';

  @override
  String get ifYouConnectYourLastFm =>
      'Si conectas tu cuenta de Last.fm, las credenciales se guardan de forma segura en el dispositivo. Los datos de reproducción solo se envían a Last.fm. No recibimos ni procesamos esos datos.';

  @override
  String get ignoreTracksUnder500Kb => 'Ignorar pistas de menos de 500 KB';

  @override
  String get ignoreTracksUnder60Seconds =>
      'Ignorar pistas de menos de 60 segundos';

  @override
  String get immersive => 'Inmersivo';

  @override
  String get immersiveFullViewTimer =>
      'Temporizador de vista completa inmersiva';

  @override
  String importFailed(Object e) {
    return 'Error al importar: $e';
  }

  @override
  String get importM3uM3u8 => 'Importar M3U/M3U8';

  @override
  String get importM3uM3u8Playlists => 'Importar listas M3U/M3U8';

  @override
  String get importPresetFile => 'Importar archivo de preajuste';

  @override
  String imported(Object arg1) {
    return 'Se importó «$arg1»';
  }

  @override
  String get importedArtIsSavedInsideThe =>
      'La portada importada se guarda en la app y se sincroniza con todas las canciones de este álbum.';

  @override
  String get importedArtIsSavedInsideThe2 =>
      'La portada importada se guarda en la app solo para esta canción.';

  @override
  String get importedPreset => 'Preajuste importado';

  @override
  String importedWithSongs(Object arg1, Object arg2, Object unmatchedText) {
    return 'Se importó «$arg1» con $arg2 canciones.$unmatchedText';
  }

  @override
  String get impulseResponse => 'Respuesta al impulso';

  @override
  String get inAppUpdates => 'Actualizaciones desde la app';

  @override
  String inLabel(Object folder) {
    return 'en $folder';
  }

  @override
  String inYourLibrary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '$count canción',
    );
    return '$_temp0 en tu biblioteca';
  }

  @override
  String get inactive => 'Inactivo';

  @override
  String get incredibleOverAMonthOfDaily =>
      'Increíble: más de un mes escuchando música todos los días.';

  @override
  String get info2 => 'Información';

  @override
  String get initializing => 'Inicializando…';

  @override
  String get inkCardWithTheReplaySignature =>
      'Tarjeta de tinta con los acentos característicos de Replay';

  @override
  String get inputGain => 'Ganancia de entrada';

  @override
  String get insertIntoTheCurrentQueueFallBackToResults =>
      'Insertar en la cola actual; si no, volver a los resultados';

  @override
  String get inst => 'Inst.';

  @override
  String get instructions => 'Instrucciones';

  @override
  String get instrumental => 'Instrumental';

  @override
  String get integrations => 'Integraciones';

  @override
  String get interactiveEq => 'Ecualizador interactivo';

  @override
  String get interactiveTutorial => 'Tutorial interactivo';

  @override
  String get interfaceClaimed => 'Interfaz asignada';

  @override
  String get interfaceLabel => 'Interfaz';

  @override
  String get invalidToken => 'Token no válido';

  @override
  String isOfflineRetainedSongsStillListed(Object folder) {
    return '$folder está sin conexión; las canciones guardadas siguen en la lista';
  }

  @override
  String get isochronousUsb => 'USB isócrono';

  @override
  String get itemSpacing => 'Espacio entre elementos';

  @override
  String items(Object count) {
    return '$count elementos';
  }

  @override
  String get jan => 'ene';

  @override
  String get jellyfin => 'Jellyfin';

  @override
  String get jellyfinEmby => 'Jellyfin · Emby';

  @override
  String get jul => 'jul';

  @override
  String get jumpBackIn => 'Retomar';

  @override
  String get jumpToTheFlickListingAnd =>
      'Ve a la ficha de Flick y actualiza desde allí';

  @override
  String get jun => 'jun';

  @override
  String get justAudioExoplayer => 'just_audio / ExoPlayer';

  @override
  String get justAudioExoplayerDefault =>
      'just_audio / ExoPlayer (predeterminado)';

  @override
  String get justNow => 'Ahora mismo';

  @override
  String get karaokeEffect => 'Efecto de karaoke';

  @override
  String get karaokePreview => 'Vista previa de karaoke';

  @override
  String kb(Object arg1) {
    return '$arg1 KB';
  }

  @override
  String get keepAll => 'Conservar todo';

  @override
  String get keepEditing => 'Seguir editando';

  @override
  String get keepItGoingOpenTomorrowTo =>
      'Sigue así. Abre la app mañana para sumar otro día.';

  @override
  String get keepListeningWithFlick => 'Sigue escuchando con Flick';

  @override
  String get keepMiniPlayerAndNavVisible =>
      'Mantener visible el minirreproductor y la navegación';

  @override
  String get keepPlaybackPausedWhenADevice =>
      'Mantener la reproducción en pausa cuando se reconecte un dispositivo';

  @override
  String get keepPlayingOnQuit => 'Seguir reproduciendo al salir';

  @override
  String get keepRelativeLevelsInsideEachAlbum =>
      'Conservar los niveles relativos dentro de cada álbum';

  @override
  String get keepTheSessionMovingOrHead =>
      'Sigue con la sesión o vuelve directamente al reproductor.';

  @override
  String get keepYourReplay => 'Conserva tu Replay.';

  @override
  String keeping(Object type, Object br) {
    return 'Conservando • $type • $br';
  }

  @override
  String keepingOfToRemove(Object keptCount, Object arg1, Object removeCount) {
    return 'Se conservan $keptCount de $arg1 • se quitarán $removeCount';
  }

  @override
  String get keepingThisVersion => 'Conservar esta versión';

  @override
  String get keepsBitPerfectAudioAliveIn =>
      'Mantiene el audio bit perfecto activo en segundo plano';

  @override
  String get keepsSoftwareVolumeAndDspActive =>
      'Mantiene activos el volumen por software y el DSP en la ruta compartida del DAP.';

  @override
  String get keptInSecureStorageToRe =>
      'Se conserva en el almacenamiento seguro para volver a iniciar sesión cuando venza el token';

  @override
  String keptWillBeRemoved(Object keptCount, Object removeCount) {
    return '$keptCount se conservan • se quitarán $removeCount';
  }

  @override
  String khz(Object arg1) {
    return '$arg1 kHz';
  }

  @override
  String khz2(Object arg1) {
    return '$arg1 kHz';
  }

  @override
  String khzBit(Object arg1, Object arg2) {
    return '$arg1 kHz/$arg2 bits';
  }

  @override
  String khzBit2(Object arg1, Object arg2) {
    return '$arg1 kHz/$arg2 bits';
  }

  @override
  String khzBitCh(Object arg1, Object arg2, Object arg3) {
    return '$arg1 kHz / $arg2 bits / $arg3 canales';
  }

  @override
  String get koFi => 'Ko-fi';

  @override
  String get label => 'Etiqueta';

  @override
  String get labelOrganization => 'Sello discográfico / organización';

  @override
  String get landscape => 'Horizontal';

  @override
  String get landscapeLayoutReset => 'Se restableció el diseño horizontal';

  @override
  String get language => 'Idioma';

  @override
  String get languageSectionDescription =>
      'Elige el idioma que se usará en toda la app.';

  @override
  String get languageSystemDefault => 'Predeterminado del sistema';

  @override
  String get lastFm => 'Last.fm';

  @override
  String get lastFmConfiguration => 'Configuración de Last.fm';

  @override
  String get lastFmConnected => 'Last.fm conectado';

  @override
  String get lastFmConnected2 => 'Se conectó Last.fm.';

  @override
  String get lastFmListenbrainzScrobbling =>
      'Registro de reproducciones en Last.fm y ListenBrainz';

  @override
  String get lastFmScrobbling => 'Registro de reproducciones en Last.fm';

  @override
  String get lastPick => 'Última selección';

  @override
  String get lastUpdated => 'Última actualización';

  @override
  String get lastWeek => 'La semana pasada';

  @override
  String get lateNightSessions => 'Sesiones nocturnas';

  @override
  String get latestArrivalsFromYourLibrary =>
      'Lo último que llegó a tu biblioteca';

  @override
  String get latestUpdate => 'Última actualización';

  @override
  String get layered => 'En capas';

  @override
  String get layoutMode => 'Modo de diseño';

  @override
  String get layoutModeSizingAndQuickActions =>
      'Modo de diseño, tamaño y acciones rápidas';

  @override
  String get ldac330Kbps => 'LDAC 330 kbps';

  @override
  String get ldac660Kbps => 'LDAC 660 kbps';

  @override
  String get ldac990Kbps => 'LDAC 990 kbps';

  @override
  String get ldacAdaptive => 'LDAC adaptable';

  @override
  String get ldacBitsPerSample => 'Bits por muestra de LDAC';

  @override
  String get leLsbLittleEndianSubslotLsb =>
      'LE-LSB: subranura en orden little-endian, primero el bit menos significativo';

  @override
  String get leMsbLittleEndianSubslotMsb =>
      'LE-MSB: subranura en orden little-endian, primero el bit más significativo';

  @override
  String get leaveEmptyToKeepTheCurrent =>
      'Déjalo vacío para conservar las credenciales actuales';

  @override
  String get left => 'Izquierda';

  @override
  String get leftBottom => 'Izquierda (abajo)';

  @override
  String get leftBottomButton => 'Botón izquierdo (abajo)';

  @override
  String get leftTop => 'Izquierda (arriba)';

  @override
  String get leftTopButton => 'Botón izquierdo (arriba)';

  @override
  String get length => 'Duración:';

  @override
  String get lengthOfTheOverlap => 'Duración del solapamiento';

  @override
  String lengthS(Object arg1) {
    return 'Duración: $arg1 s';
  }

  @override
  String get letAndroidChooseTheBestCodec =>
      'Permitir que Android elija el mejor códec';

  @override
  String get letAndroidChooseTheOutputDevice =>
      'Permitir que Android elija el dispositivo de salida';

  @override
  String get letAndroidNegotiateTheCodecAutomatically =>
      'Permitir que Android negocie el códec automáticamente';

  @override
  String get letOboePickTheBestApi =>
      'Permitir que Oboe elija la mejor API. Primero AAudio y luego OpenSL ES como alternativa.';

  @override
  String get letTheSystemDecideBestBattery =>
      'Dejar que el sistema decida: máximo ahorro de batería';

  @override
  String get letsFlickScanYourEntireLibrary =>
      'Permite que Flick analice directamente toda tu biblioteca, incluidos los archivos DSD, DSF y WavPack que algunos dispositivos ocultan del índice multimedia del sistema';

  @override
  String get level => 'Nivel';

  @override
  String get libraryEmptied => 'Se vació la biblioteca';

  @override
  String get libraryGlanceCard => 'Tarjeta de resumen de la biblioteca';

  @override
  String get libraryLabel => 'Biblioteca';

  @override
  String get licenses => 'Licencias';

  @override
  String get light => 'Claro';

  @override
  String likedSongs(Object arg1) {
    return '$arg1 canciones que te gustan';
  }

  @override
  String get likedSongsLiveHere => 'Aquí están tus canciones favoritas';

  @override
  String get likesAndReplaysBlendedTogether =>
      'Me gusta y repeticiones combinados';

  @override
  String get limit => 'Límite';

  @override
  String get limitPositiveGainSoTheLevel =>
      'Limitar la ganancia positiva para que el nivel nunca supere el máximo';

  @override
  String get limiter => 'Limitador';

  @override
  String get limiterOff => 'Limitador desactivado';

  @override
  String get limiterOn => 'Limitador activado';

  @override
  String get line => 'Línea';

  @override
  String lineOf(Object arg1, Object arg2) {
    return 'Línea $arg1 de $arg2';
  }

  @override
  String lineOfWords(
    Object arg1,
    Object arg2,
    Object captured,
    Object segmentCount,
  ) {
    return 'Línea $arg1 de $arg2  ·  $captured/$segmentCount palabras';
  }

  @override
  String get lineThickness => 'Grosor de línea';

  @override
  String get lineThicknessDescription =>
      'Ajusta el grosor de la línea de progreso.';

  @override
  String get linear => 'Lineal';

  @override
  String get lines => 'Líneas';

  @override
  String lines2(Object arg1) {
    return '$arg1 líneas';
  }

  @override
  String get linkReady => 'Enlace listo';

  @override
  String linkedToThisSong(Object arg1) {
    return 'Se vinculó «$arg1» con esta canción.';
  }

  @override
  String get list => 'Lista';

  @override
  String get listAvailableLocalAudioOutputDevices =>
      'Mostrar los dispositivos locales de salida de audio disponibles';

  @override
  String get listenbrainz => 'ListenBrainz';

  @override
  String get listenbrainzConnected => 'ListenBrainz conectado';

  @override
  String get listenbrainzConnected2 => 'Se conectó ListenBrainz.';

  @override
  String get listeningHours => 'Horas de escucha';

  @override
  String listeningToByOnFlick(Object arg1, Object arg2) {
    return 'Escuchando $arg1 de $arg2 en Flick';
  }

  @override
  String get littleEndianSubslotLsbFirstBits =>
      'Subranura en orden little-endian, primero los bits menos significativos';

  @override
  String get littleEndianSubslotMsbFirstBits =>
      'Subranura en orden little-endian, primero los bits más significativos';

  @override
  String get livePreview => 'Vista previa en tiempo real';

  @override
  String get livingOrnament => 'Adorno animado';

  @override
  String get loadAJsonOrTxtPreset => 'Cargar un preajuste JSON o TXT';

  @override
  String get loadAnImpulseResponseForRoom =>
      'Cargar una respuesta al impulso para reverberación de sala, mezcla entre canales, gabinete o corrección.';

  @override
  String get loadIr => 'Cargar respuesta al impulso';

  @override
  String loadedIr(Object displayName) {
    return 'Respuesta al impulso cargada: $displayName';
  }

  @override
  String get loadingArtwork => 'Cargando portada';

  @override
  String get loadingArtwork2 => 'Cargando portada…';

  @override
  String get loadingFavoritesRecentSessionsGenerated =>
      'Cargando favoritos, sesiones recientes, mezclas generadas y listas de reproducción.';

  @override
  String get loadingPatchNotes => 'Cargando notas de la versión…';

  @override
  String get loadingReplay => 'Cargando Replay';

  @override
  String get loadingSession => 'Cargando sesión…';

  @override
  String get localData => 'Datos locales';

  @override
  String get locked => 'Bloqueado';

  @override
  String get logFrequencyControl => 'Control de frecuencia logarítmica';

  @override
  String get logs => 'Registros';

  @override
  String get logsCopied => 'Registros copiados';

  @override
  String get longPress => 'Mantener presionado';

  @override
  String get longSongTitles => 'Títulos de canciones largos';

  @override
  String get look => 'Apariencia';

  @override
  String get lookingForCoverArtFromMusicbrainz =>
      'Buscando portadas en MusicBrainz y Cover Art Archive.';

  @override
  String get lookingForTheLatestFlickRelease =>
      'Buscando la versión más reciente de Flick';

  @override
  String get lookingForTheLatestPlayStore =>
      'Buscando la actualización más reciente de Play Store';

  @override
  String get lossless => ' Sin pérdida';

  @override
  String get losslessQualityPreservedDuringConversion =>
      'Se conserva la calidad sin pérdida durante la conversión';

  @override
  String get low => 'Bajo';

  @override
  String get lowAndHighFrequenciesScoopedMids =>
      'Graves y agudos realzados, medios atenuados';

  @override
  String get lowFrequenciesOnly => 'Solo frecuencias bajas';

  @override
  String get lowLatencyGoodQuality => 'Baja latencia, buena calidad';

  @override
  String get lowLatencyMode => 'Modo de baja latencia';

  @override
  String get lowPass => 'Filtro pasa bajos';

  @override
  String get lowShelf => 'Filtro shelving de graves';

  @override
  String get lrclib => 'LRCLib';

  @override
  String get lyric => 'Letra';

  @override
  String get lyrics => 'Letras';

  @override
  String get lyricsPreview => 'Vista previa de letras';

  @override
  String get lyricsSavedFromLrclib => 'Letras guardadas desde LRCLib.';

  @override
  String get lyricsSavingBehavior => 'Comportamiento al guardar letras';

  @override
  String get lyricsSyncHelp => 'Ayuda para sincronizar letras';

  @override
  String get lyricsSyncStudio => 'Estudio de letras y sincronización';

  @override
  String get lyricsText => 'Texto de las letras';

  @override
  String m(Object arg1) {
    return '$arg1 min';
  }

  @override
  String m2(Object arg1) {
    return '$arg1 min';
  }

  @override
  String mAgo(Object arg1) {
    return 'hace $arg1 min';
  }

  @override
  String get madeForYou => 'Hecho para ti';

  @override
  String get makeup => 'Compensación';

  @override
  String get manual => 'Manual';

  @override
  String get manualOrder => 'Orden manual';

  @override
  String get manualQueue => 'Cola manual';

  @override
  String get manufacturer => 'Fabricante';

  @override
  String get mar => 'mar';

  @override
  String get masterBypassed => 'Ecualizador principal omitido';

  @override
  String get matchAudioFilename =>
      'Coincidir con el nombre del archivo de audio';

  @override
  String matchByArtistAlbumAndTrack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos',
      one: '$count archivo',
    );
    return 'Identificar $_temp0 por artista, álbum y duración de la pista';
  }

  @override
  String get matchEqToYourHeadphoneModel =>
      'Ajustar el ecualizador a tu modelo de audífonos';

  @override
  String get matchNavigation => 'Igualar navegación';

  @override
  String get matches => 'Coincidencias';

  @override
  String maxB(Object arg1) {
    return 'Máx. $arg1 B';
  }

  @override
  String get maximumAudioQuality => 'Máxima calidad de audio';

  @override
  String get maximumSmoothnessUsesMoreBattery =>
      'Máxima fluidez: consume más batería';

  @override
  String get may => 'may';

  @override
  String get may42026 => '4 de mayo de 2026';

  @override
  String get mayStopInTheBackgroundOn =>
      'Puede que en algunos dispositivos deje de funcionar en segundo plano';

  @override
  String mb(Object arg1) {
    return '$arg1 MB';
  }

  @override
  String get media => 'Multimedia';

  @override
  String get medium => 'Medio';

  @override
  String get menu => 'Menú';

  @override
  String get metadata => 'Metadatos';

  @override
  String get metropolitan => 'Metropolitano';

  @override
  String mhz(Object arg1) {
    return '$arg1 MHz';
  }

  @override
  String get mid => 'Medios';

  @override
  String get midFrequenciesOnly => 'Solo frecuencias medias';

  @override
  String get midnightCityDreams => 'Sueños de ciudad a medianoche';

  @override
  String get midnightDreams => 'Sueños de medianoche';

  @override
  String get midnightSignal => 'Señal de medianoche';

  @override
  String get milestone => 'Hito';

  @override
  String get milestones => 'Hitos';

  @override
  String min(Object arg1) {
    return '$arg1 min';
  }

  @override
  String get miniPlayer => 'Minirreproductor';

  @override
  String get miniPlayerAppearance => 'Apariencia del minirreproductor';

  @override
  String get miniPlayerDefaultsRestored =>
      'Se restablecieron los valores predeterminados del minirreproductor';

  @override
  String get miniPlayerHeight => 'Altura del minirreproductor';

  @override
  String get miniPlayerLayout => 'Diseño del minirreproductor';

  @override
  String get minimal => 'Mínimo';

  @override
  String get minimize => 'Minimizar';

  @override
  String get minimserverServiioKodi => 'MinimServer · Serviio · Kodi';

  @override
  String get mirrorTest => 'Prueba de espejo';

  @override
  String get mirrored => 'En espejo';

  @override
  String get mitLicenseCopyrightC2026Flick =>
      'Licencia MIT\n\nCopyright (c) 2026 Colaboradores de Flick Player\n\nPor la presente se concede permiso, sin cargo, a toda persona que obtenga una copia de este software y de los archivos de documentación asociados (el «Software») para tratar el Software sin restricciones, incluidos, entre otros, los derechos de usar, copiar, modificar, combinar, publicar, distribuir, sublicenciar o vender copias del Software, y permitir que las personas a quienes se proporcione el Software lo hagan, sujeto a las siguientes condiciones:\n\nEl aviso de derechos de autor anterior y este aviso de permiso deben incluirse en todas las copias o partes sustanciales del Software.\n\nEL SOFTWARE SE PROPORCIONA «TAL CUAL», SIN GARANTÍAS DE NINGÚN TIPO, EXPRESAS O IMPLÍCITAS, INCLUIDAS, ENTRE OTRAS, LAS GARANTÍAS DE COMERCIABILIDAD, IDONEIDAD PARA UN FIN DETERMINADO Y NO INFRACCIÓN. EN NINGÚN CASO LOS AUTORES O TITULARES DE LOS DERECHOS DE AUTOR SERÁN RESPONSABLES DE NINGUNA RECLAMACIÓN, DAÑO U OTRA RESPONSABILIDAD, YA SEA EN UNA ACCIÓN CONTRACTUAL, EXTRACONTRACTUAL O DE OTRO TIPO, QUE SURJA DE, SE DERIVE DE O ESTÉ RELACIONADA CON EL SOFTWARE O SU USO U OTRAS OPERACIONES CON EL SOFTWARE.\n';

  @override
  String get mix => 'Mezcla';

  @override
  String mix2(Object arg1) {
    return 'Mezcla $arg1';
  }

  @override
  String get mixer => 'Mezclador';

  @override
  String get mixerManagement => 'Administración del mezclador';

  @override
  String moAgo(Object arg1) {
    return 'hace $arg1 meses';
  }

  @override
  String get mod => 'Mod';

  @override
  String get moderate => 'Moderado';

  @override
  String get mono => 'Mono';

  @override
  String get monthly => 'Mensual';

  @override
  String get more => 'Más';

  @override
  String more2(Object arg1, Object arg2) {
    return '$arg1 + $arg2 más';
  }

  @override
  String get moreActions => 'Más acciones';

  @override
  String get moreArtists => 'Más artistas';

  @override
  String get moreArtists2 => 'Más artistas';

  @override
  String get moreExportOptions => 'Más opciones de exportación';

  @override
  String moreFrom(Object arg1) {
    return 'Más de $arg1';
  }

  @override
  String get moreFromArtist => 'Más de este artista';

  @override
  String get moreFromArtist2 => 'Más de este artista';

  @override
  String moreTo(Object arg1, Object arg2) {
    return '$arg1 más para $arg2';
  }

  @override
  String moreToUnlock(Object remaining, Object unit) {
    return '$remaining $unit más para desbloquear.';
  }

  @override
  String get mossEcosystem => 'Ecosistema Moss';

  @override
  String get mostDlnaServersNeedNoPassword =>
      'La mayoría de los servidores DLNA no requieren contraseña';

  @override
  String get mostPlayed => 'Más reproducidas';

  @override
  String mostReplayed(Object arg1) {
    return 'Más repetida · $arg1';
  }

  @override
  String get motionArtInBitPerfect => 'Motion Art en modo bit perfecto';

  @override
  String get motionArtIsReplacedWhileBit =>
      'La animación de portada se reemplaza mientras está activa la salida bit perfecta';

  @override
  String get motionArtPlaysDuringBitPerfect =>
      'La animación de portada se reproduce con audio bit perfecto (puede interrumpir la reproducción en algunos DAP)';

  @override
  String get motionArtRefreshed => 'Se actualizó la animación de portada';

  @override
  String get moveEveryStampedLyricForwardOr =>
      'Desplazar todas las líneas de letras sincronizadas hacia adelante o hacia atrás a la vez.';

  @override
  String get movement => 'Movimiento';

  @override
  String ms(Object arg1) {
    return '$arg1 ms';
  }

  @override
  String ms2(Object arg1) {
    return '$arg1 ms';
  }

  @override
  String ms3(Object arg1) {
    return '$arg1 ms';
  }

  @override
  String ms4(Object arg1) {
    return '$arg1 ms';
  }

  @override
  String ms5(Object arg1) {
    return '$arg1 ms';
  }

  @override
  String get multiFilterBands => 'Bandas con varios filtros';

  @override
  String musicFolders(Object arg1) {
    return '$arg1 carpetas de música';
  }

  @override
  String get mute => 'Silenciar';

  @override
  String my(Object arg1) {
    return 'Mi $arg1';
  }

  @override
  String nDb(Object arg1, Object arg2) {
    return '$arg1%\n$arg2 dB';
  }

  @override
  String get nameAZ => 'Nombre (A-Z)';

  @override
  String narrow(Object amount) {
    return '$amount% más estrecho';
  }

  @override
  String get nativeDsd => 'DSD nativo';

  @override
  String get nativeDsdExperimental => 'DSD nativo (experimental)';

  @override
  String get nativeDsdExperimentalMayBeBuggy =>
      'DSD nativo: experimental (puede tener errores)';

  @override
  String get nativeFlickPresetFormat => 'Formato nativo de preajustes de Flick';

  @override
  String get naturalEqualizerFeelResponsiveYetSmooth =>
      'Ecualizador natural: respuesta rápida y a la vez fluida';

  @override
  String get natureAmbient => 'Ambiente natural';

  @override
  String get navidromeAirsonicGonic => 'Navidrome · Airsonic · Gonic';

  @override
  String get navigationAppearance => 'Apariencia de navegación';

  @override
  String get navigationBar => 'Barra de navegación';

  @override
  String get navigationDefaultsRestored =>
      'Se restablecieron los valores predeterminados de navegación';

  @override
  String get needsMetadata => 'Faltan metadatos';

  @override
  String negotiated(Object arg1) {
    return 'Negociado: $arg1';
  }

  @override
  String get neonLimeWithSignalOrangeReplay =>
      'Verde neón con acentos naranja señal de Replay';

  @override
  String get neonNights => 'Noches de neón';

  @override
  String get neonPulse => 'Pulso de neón';

  @override
  String get neonSkyline => 'Horizonte de neón';

  @override
  String get network => 'Red';

  @override
  String get networkSources => 'Fuentes de red';

  @override
  String neutral(Object amount) {
    return '$amount% neutral';
  }

  @override
  String get neverSynced => 'Nunca sincronizado';

  @override
  String get newLabel => 'Nuevo';

  @override
  String get next => 'Siguiente';

  @override
  String get nextSong => 'Canción siguiente';

  @override
  String get nextSong2 => 'Canción siguiente';

  @override
  String nextToGo(Object arg1, Object remaining, Object unit) {
    return 'Siguiente: $arg1 — faltan $remaining $unit';
  }

  @override
  String get nextcloudOwncloudSabredav => 'Nextcloud · ownCloud · SabreDAV';

  @override
  String get night => 'Noche';

  @override
  String get no => 'No';

  @override
  String get noAchievementsYetKeepListening =>
      'Aún no hay logros: sigue escuchando';

  @override
  String get noAlbumDataYet => 'Aún no hay datos del álbum';

  @override
  String get noAlbumsFound => 'No se encontraron álbumes';

  @override
  String get noAppleMusicReleaseFoundTry =>
      'No se encontró el lanzamiento en Apple Music. Prueba a editar el nombre del artista o del álbum y vuelve a buscar.';

  @override
  String get noArtistsFound => 'No se encontraron artistas';

  @override
  String noArtistsMatch(Object _searchQuery) {
    return 'Ningún artista coincide con «$_searchQuery»';
  }

  @override
  String get noAudioWasFoundIfThis =>
      'No se encontró audio. Si esta carpeta contiene música, es posible que un archivo .nomedia la esté ocultando o que Android aún no la haya indexado. Prueba a activar el análisis profundo o quita cualquier archivo .nomedia y vuelve a analizarla.';

  @override
  String get noCastingDevicesFoundMakeSure =>
      'No se encontraron dispositivos para transmitir. Asegúrate de que el teléfono y el receptor estén conectados a la misma red.';

  @override
  String get noCategoriesSelected => 'No hay categorías seleccionadas';

  @override
  String get noChangelogNotesForThisVersion =>
      'Aún no hay notas de cambios para esta versión.';

  @override
  String get noCustomAlbumArtIsSet =>
      'Todavía no hay una portada personalizada para el álbum.';

  @override
  String get noCustomPresetsYet => 'Aún no hay preajustes personalizados.';

  @override
  String get noDuplicatesFound => 'No se encontraron duplicados';

  @override
  String get noFavoritesYet => 'Aún no tienes favoritos';

  @override
  String get noFeaturedTrackYet => 'Aún no hay una pista destacada';

  @override
  String get noFiltersFoundInPresetFile =>
      'No se encontraron filtros en el archivo de preajuste.';

  @override
  String get noFoldersAdded => 'No se agregaron carpetas';

  @override
  String get noHistoryYet => 'Aún no hay historial';

  @override
  String get noInternetConnectionPleaseCheckYour =>
      'No hay conexión a internet. Comprueba la red e inténtalo de nuevo.';

  @override
  String get noLibraryFilesForThisAlbum =>
      'No se encontraron archivos de la biblioteca para este álbum.';

  @override
  String get noLogsYet => 'Aún no hay registros.';

  @override
  String get noLyricsFoundOnlineForThis =>
      'No se encontraron letras en línea para esta canción.';

  @override
  String get noLyricsYet => 'Aún no hay letras';

  @override
  String get noMatchFound => 'No se encontró ninguna coincidencia';

  @override
  String get noMatches => 'No hay coincidencias.';

  @override
  String noMatchesFor(Object _query) {
    return 'No hay coincidencias para «$_query»';
  }

  @override
  String get noMatchesFound => 'No se encontraron coincidencias';

  @override
  String get noMatchesTryFewerWordsOr =>
      'No hay coincidencias. Prueba con menos palabras o busca en línea.';

  @override
  String get noMusicYet => 'Aún no hay música';

  @override
  String get noNewAdditionsYet => 'Todavía no hay canciones nuevas';

  @override
  String get noNewUpdateFound => 'No se encontraron actualizaciones nuevas.';

  @override
  String get noOnlineArtworkFound => 'No se encontraron portadas en línea';

  @override
  String get noOutputDevicesAvailable =>
      'No hay dispositivos de salida disponibles.';

  @override
  String get noPatchNotesAvailableYet => 'Aún no hay notas de la versión.';

  @override
  String get noPlaybackYet => 'Aún no hay reproducciones';

  @override
  String get noPlaylistsYet => 'Aún no hay listas de reproducción';

  @override
  String get noPlaylistsYet2 => 'Aún no hay listas de reproducción';

  @override
  String get noPlaylistsYetNcreateOneIn =>
      'Aún no hay listas de reproducción.\nCrea una en la pestaña Listas.';

  @override
  String get noRankingDataYet => 'Aún no hay datos de clasificación';

  @override
  String noResultsFor(Object query) {
    return 'No hay resultados para «$query»';
  }

  @override
  String noResultsFoundFor(Object query) {
    return 'No se encontraron resultados para «$query».';
  }

  @override
  String get noRipData => 'No hay datos de extracción';

  @override
  String get noScanResultsYet => 'Aún no hay resultados del análisis';

  @override
  String get noServerPlaylistsFound =>
      'No se encontraron listas de reproducción en el servidor';

  @override
  String get noServersConnected => 'No hay servidores conectados';

  @override
  String get noSongPlaying => 'No se está reproduciendo ninguna canción';

  @override
  String get noSongsFound => 'No se encontraron canciones';

  @override
  String get noSongsInThisPlaylist =>
      'Esta lista de reproducción no tiene canciones';

  @override
  String get noUpcomingQueueItemsYet =>
      'Aún no hay canciones siguientes en la cola.';

  @override
  String get noUpdateAvailable => 'No hay actualizaciones disponibles';

  @override
  String get noUrbData => 'No hay datos URB';

  @override
  String get noUsbAudioDevicesFound =>
      'No se encontraron dispositivos de audio USB';

  @override
  String get noWordTimingYetAutoFill =>
      'Aún no hay tiempos para las palabras. El autorrelleno las distribuye uniformemente como punto de partida; también puedes marcarlas en el modo Sincronizar palabras.';

  @override
  String get nocturnal => 'Nocturno';

  @override
  String get none => 'Ninguno';

  @override
  String get normalizeEachTrackToMatchLoudness =>
      'Normalizar cada pista para igualar el volumen';

  @override
  String get notAnAlacFile => 'No es un archivo ALAC';

  @override
  String get notAvailableInBitPerfectMode =>
      'No disponible en modo bit perfecto';

  @override
  String get notFoundOnlineTryADifferent =>
      'No se encontró en línea. Prueba con otra forma de escribirlo.';

  @override
  String get notGrantedEnableSoScansCover =>
      'Permiso no concedido: actívalo para que el análisis incluya archivos DSD, DSF y WavPack que el índice del sistema podría omitir';

  @override
  String get notHeld => 'No retenido';

  @override
  String get notRecommendedForNormalUsageDsd =>
      'No se recomienda para el uso normal. La reproducción DSD es inestable y puede causar cortes de audio.';

  @override
  String get notRegistered => 'No registrado';

  @override
  String get notSet => 'No establecido';

  @override
  String get notStampedYet => 'Aún no sincronizado';

  @override
  String get notVerified => 'No verificado';

  @override
  String get notch => 'Muesca';

  @override
  String get notchDepth => 'Profundidad de muesca';

  @override
  String get noticeableTintingFromAlbumArt =>
      'Tinte perceptible a partir de la portada del álbum.';

  @override
  String get nov => 'nov';

  @override
  String get now => 'Ahora';

  @override
  String get nowPlaying => 'En reproducción';

  @override
  String get nowPlaying2 => 'En reproducción';

  @override
  String get numberOnArt => 'Número en la portada';

  @override
  String get oauthSignInNoPasswordStored =>
      'Inicio de sesión con OAuth; aquí no se guarda ninguna contraseña';

  @override
  String get oceanWaves => 'Olas del océano';

  @override
  String get oct => 'oct';

  @override
  String get off => 'Desactivado';

  @override
  String get offCropsToFillTheSquare =>
      'Desactivado: recorta la imagen para llenar el cuadrado; activado: estira la portada de borde a borde';

  @override
  String get offline => 'Sin conexión';

  @override
  String get onAndroidTheStandardJustAudio =>
      'En Android, la ruta de reproducción estándar de just_audio ahora aplica equivalentes nativos del ecualizador, la dinámica, el balance y los efectos espaciales en los dispositivos compatibles. El motor Rust sigue ofreciendo la versión más precisa de estos controles, por lo que algunos resultados en Android son aproximados.';

  @override
  String get onRepeat => 'En repetición';

  @override
  String get onboardingBrowseBody =>
      'Desliza entre pestañas para explorar\nCanciones, Artistas, Álbumes y\nListas. Ordena y busca en\ntoda tu colección.';

  @override
  String get onboardingBrowseTitle => 'Explora\ntu música';

  @override
  String get onboardingLibraryBody =>
      'Ve a Ajustes y toca\nCarpetas de música para analizar\ntu dispositivo. Compatible con MP3, FLAC,\nAAC, WAV y más.';

  @override
  String get onboardingLibraryTitle => 'Crea tu\nbiblioteca';

  @override
  String get onboardingPlaybackBody =>
      'Toca cualquier canción para abrir el reproductor\ncompleto con barra de reproducción de forma de onda,\necualizador, letras y visuales\nde portada ambiental.';

  @override
  String get onboardingPlaybackTitle => 'Reproducción\ncompleta';

  @override
  String get onboardingReadyBody =>
      'Empieza a explorar tu música.\nRelájate y disfruta\ndel sonido de Flick Player.';

  @override
  String get onboardingReadyTitle => 'Ya\nestá todo listo';

  @override
  String get onboardingWelcomeBody =>
      'Un reproductor de música atractivo y rápido\npara tu biblioteca local.\nSin anuncios. Sin rastreo. Solo música.';

  @override
  String get onboardingWelcomeTitle => 'Te damos la bienvenida a\nFlick Player';

  @override
  String get onlineArtistAlbumInformation =>
      'Información de artistas y álbumes en línea';

  @override
  String get onlineResults => 'Resultados en línea';

  @override
  String get onlyLibraryEntriesAreRemovedYour =>
      'Solo se quitan las entradas de la biblioteca; los archivos de audio permanecen en el disco.';

  @override
  String get onlyReReadFilesThatAre =>
      'Volver a leer solo los archivos nuevos o modificados.';

  @override
  String get open => 'Abrir';

  @override
  String get openAndroidSettings => 'Abrir ajustes de Android';

  @override
  String get openBluetoothCodecSettings => 'Abrir ajustes del códec Bluetooth';

  @override
  String get openFullNotes => 'Abrir notas completas';

  @override
  String get openInAppleMusic => 'Abrir en Apple Music';

  @override
  String get openInBrowser => 'Abrir en el navegador';

  @override
  String get openInPlayStore => 'Abrir en Play Store';

  @override
  String get openLibrary => 'Abrir biblioteca';

  @override
  String get openListenbrainzOrgSettings => 'Abrir listenbrainz.org/settings';

  @override
  String get openManual => 'Abrir manual';

  @override
  String get openPlayer => 'Abrir reproductor';

  @override
  String get openReleaseNotes => 'Abrir notas de la versión';

  @override
  String get openSourceLicenses => 'Abrir licencias de código abierto';

  @override
  String get openThePlayStoreToInstall =>
      'Abre Play Store para instalar la versión más reciente de Flick';

  @override
  String get openedFromLocker => 'Abierto desde Locker';

  @override
  String get openslEs => 'OpenSL ES';

  @override
  String get openslEsLegacy => 'OpenSL ES (heredado)';

  @override
  String get orRemoveAllUsingRecommendedPicks =>
      'O quitar todos con las selecciones recomendadas';

  @override
  String get orbital => 'Orbital';

  @override
  String get orbitHeaderBoundaryBody =>
      'Las tarjetas orbitales y la trayectoria pueden pasar detrás del encabezado Tu biblioteca y de la barra de búsqueda. Permanecen dentro de la pantalla de Canciones y se recortan en sus bordes.';

  @override
  String get orbitHeaderBoundaryTitle =>
      'La órbita pasa detrás de la cabecera de la biblioteca';

  @override
  String get orbitLandscapeHint =>
      'Se usa cuando la ventana de la app es más ancha que alta.';

  @override
  String get orbitLayoutProfile => 'Perfil de diseño';

  @override
  String get orbitPortraitHint =>
      'Se usa cuando la ventana de la app es más alta que ancha.';

  @override
  String get orbitPreviewHide => 'Ocultar vista previa';

  @override
  String get orbitPreviewHint =>
      'Desliza para explorar. No se reproduce, no se añade a la cola ni se cambian los favoritos.';

  @override
  String get orbitPreviewShow => 'Mostrar vista previa';

  @override
  String get orbitSharedVisuals => 'Elementos visuales compartidos';

  @override
  String get otherPlaylists => 'Otras listas de reproducción';

  @override
  String get ourRustPoweredEngineCleanerSound =>
      'Nuestro motor con tecnología Rust ofrece un sonido más limpio y una reproducción más fluida. Recomendado para escuchar a diario.';

  @override
  String get outlineTheMiniPlayer => 'Delinear el minirreproductor';

  @override
  String get output => 'Salida';

  @override
  String get outputDevice => 'Dispositivo de salida';

  @override
  String get outputMode => 'Modo de salida';

  @override
  String get outputRate => 'Frecuencia de salida';

  @override
  String get overlapTheEndOfATrack =>
      'Superponer el final de una pista con la siguiente';

  @override
  String get overlayPermissionIsRequiredToShow =>
      'Se requiere permiso de superposición para mostrar el reproductor flotante';

  @override
  String get overviewMetricsChooseUpTo3 => 'Métricas generales · elige hasta 3';

  @override
  String get paired => 'Emparejado';

  @override
  String get parametric => 'Paramétrico';

  @override
  String parametricBandsWithIndependentFrequency(Object arg1) {
    return '$arg1 bandas paramétricas con controles independientes de frecuencia, ganancia y Q. Toca para interactuar.';
  }

  @override
  String get parametricEq => 'Ecualizador paramétrico';

  @override
  String get passthrough => 'Paso directo';

  @override
  String get password => 'Contraseña';

  @override
  String get pasteOrTypeTheSongLyrics =>
      'Pega o escribe aquí la letra de la canción, una línea por renglón';

  @override
  String get pasteYourListenbrainzToken => 'Pega tu token de ListenBrainz';

  @override
  String get patchNotes => 'Notas de la versión';

  @override
  String get pause => 'Pausar';

  @override
  String get pauseOnBluetoothConnect => 'Pausar al conectarse por Bluetooth';

  @override
  String get pauseOnDisconnect => 'Pausar al desconectarse';

  @override
  String get pauseOnUsbDacAttach => 'Pausar al conectar un DAC USB';

  @override
  String get pauseOnUsbDacDetach => 'Pausar al desconectar un DAC USB';

  @override
  String get pcmFrames => 'Tramas PCM';

  @override
  String get peakHour => 'Hora de mayor actividad';

  @override
  String get peaking => 'Pico';

  @override
  String get permission => 'Permiso';

  @override
  String get personalPlaylist => 'Lista de reproducción personal';

  @override
  String get phoneAndHeadsetVolumeAreIndependent =>
      'El volumen del teléfono y el de los audífonos son independientes';

  @override
  String get phoneAndHeadsetVolumeAreLinked =>
      'El volumen del teléfono y el de los audífonos están vinculados';

  @override
  String get photoFraming => 'Encuadre de la foto';

  @override
  String get pickALineWithLyrics => 'Elige una línea con letra';

  @override
  String get pickALyricLineIn =>
      '1. En Líneas, elige una línea de la letra y luego cambia a Herramientas.\n2. Pulsa reproducir y toca el botón grande «Marcar palabra» al oír cada palabra. El primer toque también marca el tiempo de la línea.\n3. Toca una etiqueta de palabra para ajustarla, cambiarle el tiempo o borrarla.\n4. Las líneas con todas las palabras marcadas se guardan con tiempos de karaoke para cada palabra.';

  @override
  String get pickAgain => 'Elegir de nuevo';

  @override
  String get pickImage => 'Elegir imagen';

  @override
  String get pickUpExactlyWhereYourLast =>
      'Retoma justo donde terminaste en tus últimas sesiones.';

  @override
  String get pinchApartNarrowerHigherQNpinch =>
      'Pellizca hacia afuera para estrechar (Q más alto)\nPellizca hacia adentro para ensanchar (Q más bajo)';

  @override
  String get pitch => 'Tono';

  @override
  String pitchSemitones(int semitones) {
    String _temp0 = intl.Intl.pluralLogic(
      semitones,
      locale: localeName,
      other: '$semitones semitonos',
      one: '$semitones semitono',
    );
    return '$_temp0';
  }

  @override
  String get pixelatedLightestOnMemory => 'Pixelado: consume menos memoria';

  @override
  String get plain => 'Normal';

  @override
  String get plainText => 'Texto sin formato';

  @override
  String get play => 'Reproducir';

  @override
  String get playAFewSongsAndThis =>
      'Reproduce algunas canciones y esta página empezará a mostrar mezclas, artistas y accesos directos.';

  @override
  String get playAFewTracksTodayTo =>
      'Reproduce algunas canciones hoy para crear el resumen diario.';

  @override
  String get playARandomLibrarySongWhen =>
      'Reproducir una canción aleatoria de la biblioteca cuando termine la cola';

  @override
  String get playAgain => 'Reproducir de nuevo';

  @override
  String get playAtTheRecordedLevel => 'Reproducir al nivel grabado';

  @override
  String get playBadges => 'Insignias de reproducción';

  @override
  String get playCategoriesInRandomOrderTracks =>
      'Reproducir las categorías en orden aleatorio y las pistas en secuencia';

  @override
  String get playInOrder => 'Reproducir en orden';

  @override
  String get playNext => 'Reproducir a continuación';

  @override
  String get playStoreUpdatesUseGooglePlay =>
      'Las actualizaciones de Play Store usan la API de actualización dentro de Google Play (sujeta a las políticas de privacidad de Google). Las notas de la versión se obtienen desde la API de GitHub Releases sin enviar datos personales.';

  @override
  String get playback => 'Reproducción';

  @override
  String get playbackCacheLimit => 'Límite de caché de reproducción';

  @override
  String playbackCacheLimit2(Object arg1) {
    return 'Límite de caché de reproducción: $arg1';
  }

  @override
  String get playbackCacheUnlimited => 'Caché de reproducción ilimitada';

  @override
  String get playbackContinuesWhenABluetoothDevice =>
      'La reproducción continúa cuando se conecta un dispositivo Bluetooth';

  @override
  String get playbackContinuesWhenAUsbDac =>
      'La reproducción continúa cuando se conecta un DAC USB';

  @override
  String get playbackContinuesWhenAUsbDac2 =>
      'La reproducción continúa cuando se desconecta un DAC USB';

  @override
  String get playbackContinuesWhenAudioOutput =>
      'La reproducción continúa cuando se desconecta la salida de audio';

  @override
  String get playbackContinuesWhenTheAppIs =>
      'La reproducción continúa cuando cierras la app al deslizarla fuera de la pantalla';

  @override
  String get playbackDesynced => 'Reproducción desincronizada';

  @override
  String get playbackDisplay => 'Reproducción y pantalla';

  @override
  String get playbackEngine => 'Motor de reproducción';

  @override
  String get playbackIsUsingAndroidManagedOutput =>
      'La reproducción usa la salida administrada por Android y es posible que se remuestree.';

  @override
  String get playbackIsUsingTheStandardAndroid =>
      'La reproducción usa la ruta de salida estándar de Android.';

  @override
  String get playbackModeWillUpdateAfterThe =>
      'El modo de reproducción se actualizará después de la próxima actualización de la ruta o de la reproducción.';

  @override
  String get playbackPath => 'Ruta de reproducción';

  @override
  String get playbackPausesWhenABluetoothAudio =>
      'La reproducción se pausa cuando se conecta un dispositivo de audio Bluetooth';

  @override
  String get playbackPausesWhenAUsbDac =>
      'La reproducción se pausa cuando se conecta un DAC USB';

  @override
  String get playbackPausesWhenAUsbDac2 =>
      'La reproducción se pausa cuando se desconecta físicamente un DAC USB';

  @override
  String get playbackPausesWhenBluetoothOrHeadphones =>
      'La reproducción se pausa cuando se desconectan los audífonos o Bluetooth';

  @override
  String get playbackPausesWhileNotificationSoundsPlay =>
      'La reproducción se pausa mientras suenan las notificaciones';

  @override
  String get playbackResumesWhenADeviceReconnects =>
      'La reproducción se reanuda si un dispositivo vuelve a conectarse en 30 segundos';

  @override
  String get playbackSpeed => 'Velocidad de reproducción';

  @override
  String get playbackStopsWhenTheAppIs =>
      'La reproducción se detiene cuando cierras la app al deslizarla fuera de la pantalla';

  @override
  String played(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se reprodujeron $count canciones',
      one: 'Se reprodujo 1 canción',
    );
    return '$_temp0';
  }

  @override
  String get playerLayout => 'Diseño del reproductor';

  @override
  String get playerMenuAddToPlaylist => 'Agregar a la lista de reproducción';

  @override
  String get playerMenuAddToQueue => 'Agregar a la cola';

  @override
  String get playerMenuEditMetadata => 'Editar metadatos';

  @override
  String get playerMenuRefreshAlbumArt => 'Actualizar portada animada';

  @override
  String get playerMenuSetAlbumArt => 'Establecer portada del álbum';

  @override
  String get playerMenuShare => 'Compartir';

  @override
  String get playerMenuSleepTimer => 'Temporizador de apagado';

  @override
  String playlist(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listas de reproducción',
      one: '$count lista de reproducción',
    );
    return '$_temp0';
  }

  @override
  String get playlist2 => 'Lista de reproducción';

  @override
  String get playlistCoverRemoved =>
      'Se quitó la portada de la lista de reproducción';

  @override
  String get playlistCoverUpdated =>
      'Se actualizó la portada de la lista de reproducción';

  @override
  String playlistCreated(Object arg1) {
    return 'Se creó la lista de reproducción «$arg1»';
  }

  @override
  String get playlistExportAndroidOnly =>
      'Por ahora, la exportación de listas de reproducción solo está disponible en Android.';

  @override
  String get playlistImportAndroidOnly =>
      'Por ahora, la importación de listas de reproducción solo está disponible en Android.';

  @override
  String get playlistName => 'Nombre de la lista de reproducción';

  @override
  String get playlistNotFound => 'No se encontró la lista de reproducción';

  @override
  String playlistRenamed(Object arg1) {
    return 'Se cambió el nombre de la lista a «$arg1»';
  }

  @override
  String get playlists => 'Listas de reproducción';

  @override
  String plays(Object arg1) {
    return '$arg1 reproducciones';
  }

  @override
  String plays2(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reproducciones',
      one: '1 reproducción',
    );
    return '$_temp0';
  }

  @override
  String get playsInRotation => 'reproducciones en rotación';

  @override
  String get pleaseEnterAPlaylistName =>
      'Ingresa un nombre para la lista de reproducción';

  @override
  String get pleaseEnterYourListenbrainzUserToken =>
      'Ingresa tu token de usuario de ListenBrainz.';

  @override
  String get portrait => 'Vertical';

  @override
  String get portraitLayoutReset => 'Se restableció el diseño vertical';

  @override
  String posterPreviewPlays(Object arg1, Object arg2) {
    return 'Vista previa del póster $arg1. $arg2 reproducciones.';
  }

  @override
  String get preAmp => 'Preamplificación';

  @override
  String get preamp => 'Preamplificador';

  @override
  String get preferences => 'Preferencias';

  @override
  String get preloadAudioData => 'Precargar datos de audio';

  @override
  String get preloadLibraryAudio => 'Precargar el audio de la biblioteca';

  @override
  String get preloadingAudio => 'Precargando audio';

  @override
  String preloadingAudio2(Object arg1, Object arg2) {
    return 'Precargando audio $arg1/$arg2';
  }

  @override
  String get preloadingAudio3 => 'Precargando audio';

  @override
  String get preparing => 'Preparando…';

  @override
  String get presence => 'Presencia';

  @override
  String preset(Object activePresetName) {
    return 'Preajuste: $activePresetName';
  }

  @override
  String get presetFileIsEmpty => 'El archivo de preajuste está vacío.';

  @override
  String get presetImportedWithAdjustments => 'Preajuste importado con ajustes';

  @override
  String get presetName => 'Nombre del preajuste';

  @override
  String get presets => 'Preajustes';

  @override
  String get pressBackAgainToExit => 'Pulsa atrás otra vez para salir';

  @override
  String get preventClipping => 'Evitar la saturación';

  @override
  String get preview => 'Vista previa';

  @override
  String get previewUse => 'Vista previa y usar';

  @override
  String get previousSong => 'Canción anterior';

  @override
  String get previousSong2 => 'Canción anterior';

  @override
  String get prewarming => 'Calentando';

  @override
  String get prioritiseConnectionStability =>
      'Priorizar la estabilidad de la conexión';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get processingLive => 'Procesamiento en tiempo real';

  @override
  String get product => 'Producto';

  @override
  String get productId => 'ID del producto';

  @override
  String get progress => 'Progreso';

  @override
  String get progressBar => 'Barra de progreso';

  @override
  String get protocol => 'Protocolo';

  @override
  String get pulledFromYourLateSessionPlays =>
      'Basado en las canciones que escuchaste en tus últimas sesiones nocturnas';

  @override
  String get purple => 'Morado';

  @override
  String get queue => 'Cola';

  @override
  String queue2(Object count) {
    return 'Cola $count';
  }

  @override
  String get queueIsEmpty => 'La cola está vacía';

  @override
  String queued(Object arg1) {
    return 'Se agregó «$arg1» a la cola';
  }

  @override
  String queuedSongs(Object arg1) {
    return 'Se agregaron $arg1 canciones a la cola';
  }

  @override
  String queuedSongs3(Object arg1) {
    return 'Se agregaron $arg1 canciones a la cola';
  }

  @override
  String get quickAccess => 'Acceso rápido';

  @override
  String get quickActions => 'Acciones rápidas';

  @override
  String get quickOrFullReIndexOf =>
      'Análisis rápido o completo de todas las carpetas';

  @override
  String get quickScan => 'Análisis rápido';

  @override
  String get random => 'Aleatorio';

  @override
  String get rate => 'Calificar';

  @override
  String get rating => 'Calificación';

  @override
  String get ratio => 'Proporción';

  @override
  String get rawDsdStreamToDacRequires =>
      'La transmisión DSD sin procesar al DAC requiere compatibilidad de hardware con ENCODING_DSD; de lo contrario, se cambia automáticamente a DoP o PCM.';

  @override
  String get rawPcm => '→ PCM sin procesar';

  @override
  String get reReadMetadataForEveryFile =>
      'Volver a leer los metadatos de todos los archivos. Es más lento; úsalo si las etiquetas parecen desactualizadas.';

  @override
  String get readMode => 'Modo de lectura';

  @override
  String get readingTheCoverColors => 'Leyendo los colores de la portada…';

  @override
  String readyToRemoveSongKeepingIn(int count, Object kept) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '$count canción',
    );
    return 'Todo listo para quitar $_temp0. Total a conservar: $kept.';
  }

  @override
  String recapSavedAs(Object format) {
    return 'Resumen guardado como $format';
  }

  @override
  String recentPicksOnHand(Object arg1) {
    return '$arg1 selecciones recientes disponibles';
  }

  @override
  String get recentlyAdded => 'Agregadas recientemente';

  @override
  String get recentlyAddedTracksWaitingForMore =>
      'Canciones agregadas recientemente que aún necesitan más reproducciones.';

  @override
  String get recentlyPlayed => 'Reproducidas recientemente';

  @override
  String get recommended => 'Recomendado';

  @override
  String get recommendedOnly => 'Solo recomendados';

  @override
  String get reconnectAttempts => 'Intentos de reconexión';

  @override
  String get reconnectNow => 'Reconectar ahora';

  @override
  String get reconnectToTheInternetToScan =>
      'Vuelve a conectarte a internet para buscar actualizaciones';

  @override
  String get reconnectToWiFiOrMobile =>
      'Vuelve a conectarte a Wi-Fi o a los datos móviles para que Flick pueda buscar de nuevo';

  @override
  String get reconnectionFailed => 'No se pudo reconectar';

  @override
  String get reconnectionSuccessful => 'Reconexión correcta';

  @override
  String get recorded => 'Grabado';

  @override
  String get refreshAppleMusic => 'Actualizar Apple Music';

  @override
  String get refreshDevices => 'Actualizar dispositivos';

  @override
  String get refreshDevices2 => 'Actualizar dispositivos';

  @override
  String get refreshOutputs => 'Actualizar salidas';

  @override
  String get refreshRate => 'Frecuencia de actualización';

  @override
  String get refreshingAppleMusicData =>
      'Actualizando los datos de Apple Music';

  @override
  String get registeredNotClaimed => 'Registrado, sin asignar';

  @override
  String get reinitializingPlayback => 'Reiniciando la reproducción…';

  @override
  String get release => 'Liberación';

  @override
  String get remove => 'Quitar';

  @override
  String get removeAll => 'Quitar todo';

  @override
  String get removeAllSongs => '¿Quitar todas las canciones?';

  @override
  String get removeAllSongs2 => 'Quitar todas las canciones';

  @override
  String get removeAllWithBestPicks =>
      '¿Quitar todo con las mejores selecciones?';

  @override
  String removeAndAllOfItsSongs(Object arg1) {
    return '¿Quitar «$arg1» y todas sus canciones de la biblioteca? Los archivos del disco no se eliminarán.';
  }

  @override
  String get removeCustomArt => 'Quitar imagen personalizada';

  @override
  String get removeCover => 'Quitar portada';

  @override
  String get removeDuplicates => 'Quitar duplicados';

  @override
  String removeDuplicates2(Object toRemove) {
    return '¿Quitar $toRemove duplicados?';
  }

  @override
  String removeDuplicates3(Object toRemove) {
    return 'Quitar $toRemove duplicados';
  }

  @override
  String get removeFolder => '¿Quitar la carpeta?';

  @override
  String get removeFromFavorites => 'Quitar de favoritos';

  @override
  String get removeFromFavorites2 => 'Quitar de favoritos';

  @override
  String get removeFromLibrary => 'Quitar de la biblioteca';

  @override
  String get removeFromPlaylist => 'Quitar de la lista de reproducción';

  @override
  String get removeSelected => 'Quitar selección';

  @override
  String get removeServer => '¿Quitar el servidor?';

  @override
  String get removeServer2 => 'Quitar servidor';

  @override
  String get removeTheDatabaseEntriesOrDelete =>
      'Quitar las entradas de la base de datos o eliminar los archivos del dispositivo. Esta acción no se puede deshacer.';

  @override
  String get removeTheDatabaseEntryOrDelete =>
      'Quitar la entrada de la base de datos o eliminar el archivo del dispositivo. Esta acción no se puede deshacer.';

  @override
  String get removeTheseSongsFromYourLibrary =>
      'Quita estas canciones de la biblioteca. Los archivos del dispositivo no se verán afectados.';

  @override
  String get removeThisSongFromYourLibrary =>
      'Quita esta canción de la biblioteca. El archivo del dispositivo no se verá afectado.';

  @override
  String removedCustomAlbumArtFor(Object arg1) {
    return 'Se quitó la portada personalizada de «$arg1».';
  }

  @override
  String removedCustomAlbumArtFor2(Object arg1) {
    return 'Se quitó la portada personalizada de «$arg1».';
  }

  @override
  String removedDuplicatesKept(Object arg1, Object arg2) {
    return 'Se quitaron $arg1 duplicados; se conservaron $arg2.';
  }

  @override
  String removedFromFavorites(Object arg1) {
    return 'Se quitó «$arg1» de favoritos';
  }

  @override
  String removedFromFavorites2(Object arg1) {
    return 'Se quitó $arg1 de favoritos';
  }

  @override
  String get removedFromFavorites3 => 'Se quitó de favoritos';

  @override
  String removedFromLibrary(Object arg1) {
    return 'Se quitó «$arg1» de la biblioteca';
  }

  @override
  String removedSongsFromFavorites(Object arg1) {
    return 'Se quitaron $arg1 canciones de favoritos';
  }

  @override
  String removedSongsFromLibrary(Object arg1) {
    return 'Se quitaron $arg1 canciones de la biblioteca';
  }

  @override
  String get removing => 'Quitando…';

  @override
  String get removingDuplicates => 'Quitando duplicados…';

  @override
  String get rename => 'Cambiar nombre';

  @override
  String get renamePreset => 'Cambiar nombre del preajuste';

  @override
  String repeat(Object arg1) {
    return 'Repetir: $arg1';
  }

  @override
  String get repeatMode => 'Modo de repetición';

  @override
  String get repeatRewind => 'Rebobinar al repetir';

  @override
  String get replaceAlbumNameWithAVerified =>
      'Reemplazar el nombre del álbum con una cápsula bit-perfect verificada durante la transmisión bit-perfect';

  @override
  String get replay => 'Replay';

  @override
  String get replayCouldnTLoad => 'No se pudo cargar Replay.';

  @override
  String get replayStudio => 'Estudio de Replay';

  @override
  String get replayTheTutorialAndFeatureGuide =>
      'Volver a reproducir el tutorial y la guía de funciones';

  @override
  String get replaygain => 'ReplayGain';

  @override
  String get replaygainScan => 'Análisis de ReplayGain';

  @override
  String get reportedOutputRate => 'Frecuencia de salida informada';

  @override
  String get requestedOutputRate => 'Frecuencia de salida solicitada';

  @override
  String get requiredToDetectDevicesCodecsAnd =>
      'Se necesita para detectar dispositivos, códecs y niveles de batería';

  @override
  String get resampler => 'Remuestreador';

  @override
  String get rescanLibrary => 'Volver a analizar la biblioteca';

  @override
  String get reset => 'Restablecer';

  @override
  String get resetArtwork => 'Restablecer portada';

  @override
  String get resetArtworkDescription =>
      '¿Volver a detectar la portada a partir de los archivos de este álbum? Las portadas detectadas automáticamente se reemplazarán con las que se lean de los archivos; las personalizadas se conservarán.';

  @override
  String resetArtworkFor(Object arg1) {
    return 'Restablecer la portada de «$arg1».';
  }

  @override
  String resetArtworkFor2(Object arg1) {
    return 'Restablecer la portada de «$arg1».';
  }

  @override
  String get resetCardDesign => 'Restablecer diseño de tarjeta';

  @override
  String get resetDeclinedUsbDacs => 'Restablecer los DAC USB rechazados';

  @override
  String get resetDynamics => 'Restablecer dinámica';

  @override
  String get resetFx => 'Restablecer efectos';

  @override
  String get resetMiniPlayerToDefaults =>
      'Restablecer los valores predeterminados del minirreproductor';

  @override
  String get resetNavigationToDefaults =>
      'Restablecer los valores predeterminados de navegación';

  @override
  String get resetPreferences => 'Restablecer preferencias';

  @override
  String get resetStreakData => '¿Restablecer los datos de racha?';

  @override
  String get resetStreakData2 => 'Restablecer datos de racha';

  @override
  String get resetTo0Db => 'Restablecer a 0 dB';

  @override
  String get resetToDefaults => 'Restablecer valores predeterminados';

  @override
  String get resolution => 'Resolución';

  @override
  String get resonance => 'Resonancia';

  @override
  String get restart => 'Reiniciar';

  @override
  String get restartRequired => 'Es necesario reiniciar';

  @override
  String get restartTheAppToApplyPlayback =>
      'Reinicia la app para aplicar los cambios de reproducción.';

  @override
  String get restartYourDeviceToApplyOutput =>
      'Reinicia el dispositivo para aplicar los cambios de formato de salida.';

  @override
  String get restartingFlick => 'Reiniciando Flick';

  @override
  String get restoreDefaultProgressBarSize =>
      'Restablece el tamaño predeterminado del estilo de barra de progreso seleccionado.';

  @override
  String get restoreThisProfilesOrbitLayout =>
      'Restablecer el diseño orbital original de este perfil';

  @override
  String results(Object arg1) {
    return 'Resultados ($arg1)';
  }

  @override
  String get resumeAFamiliarFavoriteOrShuffle =>
      'Retoma un favorito conocido o mezcla una de las listas que se crearon a partir de lo que escuchas.';

  @override
  String get resumeOnReconnect => 'Reanudar al reconectarse';

  @override
  String get retakePhoto => 'Volver a tomar la foto';

  @override
  String get retroFuture => 'Futuro retro';

  @override
  String get retry => 'Reintentar';

  @override
  String get reviewBeforeYouClean => 'Revisar antes de limpiar';

  @override
  String get right => 'Derecha';

  @override
  String get rightBottom => 'Derecha (abajo)';

  @override
  String get rightBottomButton => 'Botón derecho (abajo)';

  @override
  String get rightTop => 'Derecha (arriba)';

  @override
  String get rightTopButton => 'Botón derecho (arriba)';

  @override
  String get ripSource => 'Fuente de extracción';

  @override
  String get root => 'Raíz';

  @override
  String get rotationSeek => 'búsqueda rotatoria';

  @override
  String get roundedAlbumArtCardWithA =>
      'Tarjeta redondeada con portada y fondo difuminado de la misma imagen.';

  @override
  String get route => 'Ruta';

  @override
  String get routesBluetoothThroughTheHiRes =>
      'Enruta el audio Bluetooth por el motor Rust de alta resolución';

  @override
  String get routesBluetoothThroughTheRustEngine =>
      'Enruta el audio Bluetooth por el motor Rust';

  @override
  String get runAnotherPlayStoreUpdateScan =>
      'Buscar actualizaciones de Play Store ahora mismo';

  @override
  String get runAnotherUpdateScanRightNow =>
      'Buscar actualizaciones ahora mismo';

  @override
  String get rustViaOboe => 'Rust mediante Oboe';

  @override
  String get rustViaOboeHighRes => 'Rust mediante Oboe (alta resolución)';

  @override
  String s(Object arg1) {
    return '$arg1 s';
  }

  @override
  String s2(Object arg1) {
    return '$arg1 s';
  }

  @override
  String sAgo(Object arg1) {
    return 'hace $arg1 s';
  }

  @override
  String get sCurve => 'Curva en S';

  @override
  String get sambaWindowsShareTransportPending =>
      'Samba · recurso compartido de Windows';

  @override
  String get sampleArtist => 'Artista de ejemplo';

  @override
  String get samplePreview => 'Vista previa de muestra';

  @override
  String get sampleRate => 'Frecuencia de muestreo';

  @override
  String get sampleRate2 => 'Frecuencia de muestreo';

  @override
  String get sampleRates => 'Frecuencias de muestreo';

  @override
  String get sampleSongPreviewOnly => 'Canción de ejemplo · solo vista previa';

  @override
  String get samples => 'Muestras';

  @override
  String get save => 'Guardar';

  @override
  String get saveAsText => 'Guardar como texto';

  @override
  String get saveChanges => 'Guardar cambios';

  @override
  String get saveConnect => 'Guardar y conectar';

  @override
  String get saveCreatesAnLrcFileIf =>
      'Al guardar, se crea un archivo `.lrc`. Si algunas líneas aún no tienen tiempo marcado, Flick lo completa automáticamente para que el archivo siga funcionando. Las líneas con todas las palabras marcadas se exportan con tiempos de karaoke para cada palabra.';

  @override
  String get saveCurrentAsPreset => 'Guardar como preajuste';

  @override
  String get saveCustomizeReplay => 'Guardar / personalizar Replay';

  @override
  String get saveInFlick => 'Guardar en Flick';

  @override
  String get saveLogs => 'Guardar registros';

  @override
  String get saveLrcFile => 'Guardar archivo LRC';

  @override
  String get saveLrcFile2 => 'Guardar archivo LRC';

  @override
  String get saveLyrics => 'Guardar letras';

  @override
  String get savePng => 'Guardar PNG';

  @override
  String get savePreset => 'Guardar preajuste';

  @override
  String get saveTheCurrentEqAsJson =>
      'Guardar el ecualizador actual como JSON o TXT';

  @override
  String get saved => 'Guardado';

  @override
  String get savedAgain => 'Guardado · otra vez';

  @override
  String get savedAndVerified => 'Guardado y verificado';

  @override
  String savedCollections(Object playlistCount) {
    return '$playlistCount colecciones guardadas';
  }

  @override
  String get savedLyricsAndLinkedThemTo =>
      'Se guardaron las letras y se vincularon con esta canción.';

  @override
  String get savedLyricsBesideTheSongAs =>
      'Se guardaron las letras junto a la canción como archivo `.lrc`.';

  @override
  String get savedLyricsToTheChosenLocation =>
      'Se guardaron las letras en la ubicación seleccionada.';

  @override
  String get savedPlaylistsAndQuickJumpsInto =>
      'Listas guardadas y accesos rápidos a la organización de tu biblioteca.';

  @override
  String get savedToGallery => 'Guardado en la galería';

  @override
  String savedToNNNshareIt(Object path) {
    return 'Guardado en:\n$path\n\n¿Quieres compartirlo ahora?';
  }

  @override
  String savedToYourGallery(Object arg1) {
    return '$arg1 se guardó en la galería';
  }

  @override
  String get savedVerificationPending => 'Guardado (verificación pendiente)';

  @override
  String get saving => 'Guardando…';

  @override
  String get saving2 => 'Guardando';

  @override
  String get savingRecapAndroidOnly =>
      'Por ahora, guardar imágenes del resumen solo está disponible en Android.';

  @override
  String get scaleOfTheCenteredFocusedSong =>
      'Tamaño de la tarjeta de canción centrada y enfocada';

  @override
  String get scaleTheAlbumArtCard =>
      'Ajustar el tamaño de la tarjeta con portada';

  @override
  String get scaleTheFullViewAlbumArt =>
      'Ajustar el tamaño de la tarjeta con portada en vista completa';

  @override
  String get scalesWithWidgetSizeAutomatically =>
      'Se ajusta automáticamente al tamaño del widget';

  @override
  String get scanAgain => 'Analizar de nuevo';

  @override
  String get scanComplete => 'Análisis completo';

  @override
  String get scanFailedPleaseTryAgain =>
      'No se pudo completar el análisis. Inténtalo de nuevo.';

  @override
  String get scanForDevices => 'Buscar dispositivos';

  @override
  String get scanProgress => 'Progreso del análisis';

  @override
  String get scanReplaygain => 'Analizar ReplayGain';

  @override
  String get scanningForDuplicates => 'Buscando duplicados…';

  @override
  String get scanningSettings => 'Ajustes del análisis';

  @override
  String scanningSongsFound(Object count) {
    return 'Analizando… Se encontraron $count canciones';
  }

  @override
  String get scanningYourLibrary => 'Analizando tu biblioteca…';

  @override
  String get scroll => 'Desplazarse';

  @override
  String get scrollForMore => 'Desplázate para ver más';

  @override
  String get scrollingPausesWhenReducedMotionIs =>
      'El desplazamiento se pausa si está activada la opción para reducir el movimiento';

  @override
  String get seamlessTransitionBetweenTracks =>
      'Transición fluida entre pistas';

  @override
  String get search => 'Buscar';

  @override
  String get searchAgain => 'Buscar de nuevo';

  @override
  String get searchArtistTitle => 'Buscar artista + título…';

  @override
  String get searchArtists => 'Buscar artistas…';

  @override
  String get searchFailed => 'Error en la búsqueda';

  @override
  String searchFailed2(Object e) {
    return 'Error en la búsqueda: $e';
  }

  @override
  String get searchHeadphones => 'Buscar audífonos…';

  @override
  String searchModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelos',
      one: '$count modelo',
    );
    return 'Buscar $_temp0…';
  }

  @override
  String get searchOnline => 'Buscar en línea';

  @override
  String get searchOnline2 => 'Buscar en línea';

  @override
  String get searchOnlineCreateYourOwnSynced =>
      'Busca letras en línea, crea tus propias letras sincronizadas o importa un archivo existente.';

  @override
  String get searchOnlineLyrics => 'Buscar letras en línea';

  @override
  String get searchPlayback => 'Buscar en reproducción';

  @override
  String get searchResults => 'Resultados de búsqueda';

  @override
  String get searchSongsArtists => 'Buscar canciones, artistas…';

  @override
  String get searchSongsArtistsAlbums =>
      'Buscar canciones, artistas y álbumes…';

  @override
  String get searchTheManual => 'Buscar en el manual…';

  @override
  String get searchSettings => 'Buscar ajustes…';

  @override
  String get searchYourLibrary => 'Buscar en tu biblioteca';

  @override
  String get searching => 'Buscando…';

  @override
  String get searchingOnline => 'Buscando en línea';

  @override
  String get searchingTheLocalNetwork => 'Buscando en la red local…';

  @override
  String get secondsOfInactivityBeforeCollapsing =>
      'Segundos de inactividad antes de contraer';

  @override
  String get seeAll => 'Ver todo';

  @override
  String seeAll2(Object count) {
    return 'Ver los $count';
  }

  @override
  String get seeWhatIsNewInThis =>
      'Descubre las novedades de esta actualización';

  @override
  String get select => 'Seleccionar';

  @override
  String get selectAFolderToScan => 'Selecciona una carpeta para analizar';

  @override
  String get selectALineAndEdit =>
      '1. Selecciona una línea y edita directamente su marca de tiempo o usa «Usar hora actual».\n2. En la línea de tiempo de palabras, arrastra un límite para alargar o acortar el segmento anterior; los cambios se ajustan a intervalos de 10 ms.\n3. Toca letras en el inspector para dividir una palabra en sílabas con tiempos separados (ritmo lento y luego rápido) y después arrastra sus límites.\n4. Arrastra el último límite (o usa Duración ±) para cambiar el tiempo de la línea siguiente. Usa Autorrellenar para distribuir las palabras uniformemente.\n5. Usa los controles de desplazamiento para mover a la vez todas las letras marcadas.\n6. Guarda para generar el archivo `.lrc` final.';

  @override
  String get selectARelease => 'Seleccionar un lanzamiento';

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get selectAll2 => 'Seleccionar todo';

  @override
  String get selectDevice => 'Seleccionar dispositivo';

  @override
  String selected(Object count) {
    return '$count seleccionados';
  }

  @override
  String get selectedFileIsNotASupported =>
      'El archivo seleccionado no es una imagen compatible.';

  @override
  String selectedOfSong(Object selected, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '$count canción',
    );
    return 'Selección: $selected de $_temp0';
  }

  @override
  String get selectedPlaylistFileIsEmpty =>
      'El archivo de lista de reproducción seleccionado está vacío';

  @override
  String get selectedSize => 'Tamaño seleccionado';

  @override
  String get sep => 'sep';

  @override
  String get separateFromNavBar => 'Separar de la barra de navegación';

  @override
  String get separateTheMiniPlayerToCustomize =>
      'Separa el minirreproductor para personalizar su ancho y el espacio. Tus valores personalizados se conservan al volver a unirlo.';

  @override
  String get serialNumber => 'Número de serie';

  @override
  String serverPlaylistSyncFailed(Object e) {
    return 'No se pudo sincronizar la lista de reproducción del servidor: $e';
  }

  @override
  String get serverUrl => 'URL del servidor';

  @override
  String get session => 'Sesión';

  @override
  String get setAlbumArt => 'Establecer portada del álbum';

  @override
  String get setCover => 'Establecer portada';

  @override
  String get setToNow => 'Establecer en ahora';

  @override
  String get settings => 'Ajustes';

  @override
  String get shadow => 'Sombra';

  @override
  String get shadowJazz => 'Shadow Jazz';

  @override
  String get share => 'Compartir';

  @override
  String shareFailed(Object e) {
    return 'No se pudo compartir: $e';
  }

  @override
  String get sharedSecret => 'Secreto compartido';

  @override
  String get sharpRecommended => 'Nítido (recomendado)';

  @override
  String get shiftMetadataTextUpOrDown =>
      'Mover el texto de metadatos hacia arriba o abajo';

  @override
  String get shiftOnlyTheAlbumArtUp =>
      'Mover solo la portada del álbum hacia arriba o abajo';

  @override
  String get shiftOnlyTheSongDetailsUp =>
      'Mover solo los detalles de la canción hacia arriba o abajo';

  @override
  String get showASystemOverlayMiniPlayer =>
      'Mostrar un minirreproductor superpuesto sobre otras apps';

  @override
  String get showAThinPlaybackProgressLine =>
      'Mostrar una línea delgada con el progreso de reproducción';

  @override
  String get showAlbum => 'Mostrar álbum';

  @override
  String get showAlbum2 => 'Mostrar álbum';

  @override
  String get showAlbumArtwork => 'Mostrar la portada del álbum.';

  @override
  String get showAlbumArtworkOnTheMini =>
      'Mostrar la portada del álbum en el minirreproductor';

  @override
  String get showAppleMusicBiographiesRecommendationsAnd =>
      'Mostrar biografías de Apple Music, artistas similares, canciones destacadas, notas de los álbumes y retratos de los artistas.';

  @override
  String get showArtist => 'Mostrar artista';

  @override
  String get showArtist2 => 'Mostrar artista';

  @override
  String get showArtistBelowSongTitle =>
      'Mostrar el artista debajo del título de la canción';

  @override
  String get showFileInfo => 'Mostrar información del archivo';

  @override
  String get showFileInfo2 => 'Mostrar información del archivo';

  @override
  String get showFrame => 'Mostrar cuadro';

  @override
  String get showFrame2 => 'Mostrar cuadro';

  @override
  String get showGlow => 'Mostrar brillo';

  @override
  String get showLabels => 'Mostrar etiquetas';

  @override
  String get showLess => 'Mostrar menos';

  @override
  String get showLyrics => 'Mostrar letras';

  @override
  String get showMore => 'Mostrar más';

  @override
  String get showMoreArtByFadingOnly =>
      'Mostrar más portada desvaneciendo solo la parte inferior del encabezado y bajando el contenido';

  @override
  String get showOrHideHomeScreenSections =>
      'Mostrar u ocultar secciones de la pantalla de inicio';

  @override
  String get showOrbitPath => 'Mostrar la trayectoria orbital';

  @override
  String get showOtherArtistsOnAlbumPages =>
      'Mostrar otros artistas en las páginas de álbumes';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get showPlaylistPreviewsOnTheHome =>
      'Mostrar vistas previas de listas en la pantalla de inicio';

  @override
  String get showRecentlyPlayedArtistsOnThe =>
      'Mostrar los artistas reproducidos recientemente en la pantalla de inicio';

  @override
  String get showRelatedAlbumsOnAlbumPages =>
      'Mostrar álbumes relacionados en las páginas de álbumes';

  @override
  String get showSmartMixesGeneratedFromYour =>
      'Mostrar mezclas inteligentes generadas a partir de tus hábitos de escucha';

  @override
  String get showTheArtistBelowTheSong =>
      'Mostrar el artista debajo del título de la canción';

  @override
  String get showTheAtAGlanceSummary =>
      'Mostrar el resumen rápido en Artistas/Álbumes';

  @override
  String get showTheAudioEnginePickerCard =>
      'Mostrar la tarjeta para elegir el motor de audio en la pantalla de inicio';

  @override
  String get showTheAudioVisualizerOffSaves =>
      'Mostrar el visualizador de audio (desactivarlo ahorra batería)';

  @override
  String get showTheBrowseChipsForLibrary =>
      'Mostrar los accesos rápidos para explorar las secciones de la biblioteca en la pantalla de inicio';

  @override
  String get showTheFloatingMiniPlayerPill =>
      'Mostrar la pastilla flotante del minirreproductor en las pantallas';

  @override
  String get showTheGlassFrameAroundAlbum =>
      'Mostrar el marco de vidrio alrededor de la portada del álbum';

  @override
  String get showTheGridOfShortcutCards =>
      'Mostrar la cuadrícula de tarjetas de acceso directo en la pantalla de inicio';

  @override
  String get showTheMiniPlayerAsIts =>
      'Mostrar el minirreproductor como una barra independiente sobre los botones';

  @override
  String get showTheNumberOverBlurredArt =>
      'Mostrar el número sobre la portada difuminada.';

  @override
  String showTheTabInTheBottom(Object arg1) {
    return 'Mostrar la pestaña $arg1 en la barra inferior';
  }

  @override
  String get showTheTrackNumber => 'Mostrar el número de pista.';

  @override
  String get showTheUsbVolumeBarOn =>
      'Mostrar la barra de volumen USB en la pantalla de inicio';

  @override
  String get showTheUsbVolumeBarOn2 =>
      'Mostrar la barra de volumen USB en la pantalla de ajustes UAC2';

  @override
  String get showTitle => 'Mostrar título';

  @override
  String get showTitle2 => 'Mostrar título';

  @override
  String get showVerboseAudioDiagnosticsAndEngine =>
      'Mostrar diagnósticos de audio detallados y registros de seguimiento del motor y la sesión.';

  @override
  String get showVisualizer => 'Mostrar visualizador';

  @override
  String get showYourRecentListeningHistoryOn =>
      'Mostrar el historial de escucha reciente en la pantalla de inicio';

  @override
  String showingAllAlbums(Object totalCount) {
    return 'Se muestran los $totalCount álbumes';
  }

  @override
  String showingOfAlbums(Object visibleCount, Object totalCount) {
    return 'Se muestran $visibleCount de $totalCount álbumes';
  }

  @override
  String get showingYourLastLoadedReplay =>
      'Se muestra el último Replay que cargaste.';

  @override
  String get shownWhenThereIsRoomBeside =>
      'Se muestra cuando hay espacio junto a los controles';

  @override
  String get shuffle => 'Aleatorio';

  @override
  String shuffle2(Object arg1) {
    return 'Aleatorio: $arg1';
  }

  @override
  String get shuffleFavorites => 'Mezclar favoritos';

  @override
  String get shuffleMode => 'Modo aleatorio';

  @override
  String get shuffleSongsAndJumpBetweenCategories =>
      'Mezclar canciones y saltar entre categorías';

  @override
  String get shuffleSongsInCurrentList =>
      'Mezclar canciones de la lista actual';

  @override
  String get signInFailedRetry => 'Error al iniciar sesión: volver a intentar';

  @override
  String get signInWithTidal => 'Iniciar sesión con Tidal';

  @override
  String get signInWithYourAccountHifi =>
      'Inicia sesión con tu cuenta · HiFi sin pérdida';

  @override
  String get signInWithYourOwnTidal =>
      'Inicia sesión con tu cuenta de Tidal. El audio sin pérdida HiFi (FLAC/ALAC) se reproduce con el motor bit perfecto; Tidal restringe HiRes/MQA y Atmos, que mostrarán un error en lugar de reproducirse.';

  @override
  String get signal => 'Señal';

  @override
  String get signalAccurateUnverified => 'AccurateRip sin verificar';

  @override
  String get signalAccurateVerified => 'AccurateRip verificado en el registro';

  @override
  String get signalAltSetting => 'Ajuste alternativo';

  @override
  String get signalBufferCapacity => 'Capacidad del búfer';

  @override
  String get signalBufferFill => 'Nivel del búfer';

  @override
  String get signalBufferOccupancy => 'Ocupación del búfer al abrir';

  @override
  String get signalBufferTarget => 'Objetivo del búfer';

  @override
  String get signalCopyCrc => 'CRC de copia';

  @override
  String get signalCrcCannotCompare => 'No se puede comparar';

  @override
  String get signalCrcComparison => 'Comparación de CRC';

  @override
  String get signalCrcMatch => 'Coincide';

  @override
  String get signalCrcMismatch => 'No coincide';

  @override
  String get signalDriftFromTarget => 'Desfase respecto al objetivo';

  @override
  String get signalDsdBitRate => 'Tasa de bits DSD';

  @override
  String get signalFileFormat => 'Formato del archivo';

  @override
  String get signalFramesPerPacket => 'Tramas / paquete';

  @override
  String get signalMaxPacket => 'Paquete máximo';

  @override
  String get signalNoRipDescription =>
      'No se encontró información de extracción ni de verificación para esta pista.';

  @override
  String get signalNotReported => 'No informado';

  @override
  String get signalNotVerified => 'No verificado';

  @override
  String get signalOrangeSurfaceFromTheReplay =>
      'Superficie naranja señal de la portada de Replay';

  @override
  String get signalRecordingUnavailable =>
      'Historial de extracción no disponible';

  @override
  String get signalRipDescription =>
      'Información del registro de extracción; no corresponde a una etapa de la ruta de reproducción actual.';

  @override
  String get signalRipProvenance => 'Procedencia de la extracción';

  @override
  String get signalRipper => 'Extractor';

  @override
  String get signalServiceInterval => 'Intervalo de servicio';

  @override
  String get signalSnapshot => 'Instantánea';

  @override
  String get signalSnapshotAtOpen => 'Instantánea al abrir';

  @override
  String get signalSourceDescription =>
      'Propiedades del archivo de origen, no de la salida enviada al dispositivo.';

  @override
  String get signalSourceDetails => 'Detalles del formato de origen';

  @override
  String get signalSubslot => 'Subranura';

  @override
  String get signalSyncType => 'Tipo de sincronización';

  @override
  String get signalTarget => 'objetivo';

  @override
  String get signalTestCrc => 'CRC de prueba';

  @override
  String get signalTransportFormat => 'Transporte';

  @override
  String get signalUnderruns => 'Subdesbordamientos';

  @override
  String get signalUsageType => 'Tipo de uso';

  @override
  String get signalUsbDescription =>
      'Valores de transporte disponibles cuando se abrió este panel. No es un registro en tiempo real de paquetes.';

  @override
  String get signalUsbMissingDescription =>
      'Los detalles URB solo se informan en la ruta USB directa. No se infiere ninguna actividad de transferencia.';

  @override
  String get signalUsbTransport => 'Transporte USB';

  @override
  String get signalUsbUnavailable =>
      'Detalles del transporte USB no disponibles';

  @override
  String get signalVerificationMissing => 'Verificación no informada';

  @override
  String get signalVerifiedInLog => 'Verificado en el registro';

  @override
  String get signedIn => 'Sesión iniciada';

  @override
  String get silkySmoothBZierCurvesFluid =>
      'Curvas de Bézier muy suaves y fluidas, con un movimiento natural';

  @override
  String get similarArtists => 'Artistas similares';

  @override
  String get simple => 'Simple';

  @override
  String get simpleMode => 'Modo simple';

  @override
  String get simplifiedChinese => 'Chino simplificado';

  @override
  String get single => 'Sencillo';

  @override
  String get size => 'Tamaño';

  @override
  String get sizing => 'Ajuste de tamaño';

  @override
  String get skip => 'Omitir';

  @override
  String get skipUnsupportedFilesAndHiddenNomedia =>
      'Omitir archivos no compatibles y directorios .nomedia ocultos';

  @override
  String skippedUnmatchedEntr(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se omitieron $count entradas sin coincidencia',
      one: 'Se omitió $count entrada sin coincidencia',
    );
    return ' $_temp0.';
  }

  @override
  String get sleepTimer => 'Temporizador de apagado';

  @override
  String get sleepTimer2 => 'Temporizador de apagado';

  @override
  String get sleeves => 'Fundas';

  @override
  String get slope => 'Pendiente';

  @override
  String get smbInvalidServerUrl =>
      'Usa smb://servidor/recurso o smb://servidor/recurso/carpeta. Ingresa las credenciales en los campos de usuario y contraseña, no en la URL.';

  @override
  String get smbSigningRequired =>
      'El servidor requiere firma SMB. Usa una cuenta permitida por la política de seguridad del servidor; es posible que no se permita el acceso de invitado.';

  @override
  String get smbCacheWriteFailed =>
      'No se pudo guardar la descarga SMB. Comprueba el espacio libre en el teléfono e inténtalo de nuevo.';

  @override
  String get smbDownloadIncomplete =>
      'La descarga SMB no terminó. Comprueba la conexión e inténtalo de nuevo; no se reproducirá ningún archivo parcial.';

  @override
  String get smbPathNotFound =>
      'No se encontró la carpeta o el archivo SMB. Comprueba la carpeta en la URL del servidor o vuelve a sincronizar la biblioteca.';

  @override
  String get smbDecodeFailed =>
      'Se descargó el archivo SMB, pero no se pudo iniciar la reproducción. Prueba el mismo archivo localmente en Flick y comprueba la salida de audio seleccionada.';

  @override
  String get smbOperationFailed =>
      'Falló la operación SMB. Ejecuta Probar conexión y comprueba la etapa o el código SMB en el registro antes de volver a intentarlo.';

  @override
  String get smbAccessDenied =>
      'Acceso denegado. Comprueba que la cuenta tenga permiso para leer este recurso compartido.';

  @override
  String get smbAuthFailed =>
      'El servidor rechazó el nombre de usuario o la contraseña. Comprueba la cuenta: Samba podría asignar los usuarios desconocidos como invitados.';

  @override
  String get smbConnectionRefused =>
      'Se rechazó la conexión. Comprueba que el uso compartido de archivos esté activado y que el puerto 445 esté accesible.';

  @override
  String get smbCouldNotReach =>
      'No se pudo acceder al servidor. Comprueba la dirección IP y que el teléfono esté conectado a la misma red.';

  @override
  String get smbHostNotResolved =>
      'No se pudo encontrar el nombre del servidor. Prueba con la dirección IP; Android no puede resolver nombres NetBIOS ni .local.';

  @override
  String get smbMissingServerAddress =>
      'Falta la dirección del servidor: usa smb://host/recurso (por ejemplo, smb://nas/musica).';

  @override
  String get smbMissingShareName =>
      'Falta el nombre del recurso compartido: usa smb://host/recurso (por ejemplo, smb://nas/musica).';

  @override
  String get smbServerUnresponsive =>
      'El servidor dejó de responder. Comprueba el servidor e inténtalo de nuevo.';

  @override
  String get smbShareNotFound =>
      'El servidor respondió, pero no se encontró el recurso compartido. Comprueba su nombre en la URL.';

  @override
  String get smbSharesCanBeAddedNow =>
      'Los recursos SMB2/3 se conectan con el cliente integrado. Ingresa la URL del recurso (smb://host/recurso) e inicia sesión si el servidor lo solicita.';

  @override
  String get smbTimedOut =>
      'Se agotó el tiempo de espera. Usa la IP del servidor (no un nombre NetBIOS o .local), comprueba el puerto 445 y asegúrate de que el teléfono esté en la misma red.';

  @override
  String get smooth => 'Suave';

  @override
  String get smoothsPeaksAndRaisesBodyBefore =>
      'Suaviza los picos y realza el cuerpo del sonido antes de que el limitador controle los transitorios.';

  @override
  String get snappy => 'Ágil';

  @override
  String get softDetailBalanced => 'Detalle suave y equilibrado';

  @override
  String get softHighlightBehindTheSelectedSong =>
      'Resaltado suave detrás de la canción seleccionada';

  @override
  String get softwareAppControlled => 'Software (controlado por la app)';

  @override
  String get solid => 'Sólido';

  @override
  String get soloDeveloper => 'Desarrollador independiente';

  @override
  String get someOnlineFeaturesMayNotWork =>
      '  · Es posible que algunas funciones en línea no estén disponibles';

  @override
  String get someWordsAreStillUntimedFinish =>
      'Aún faltan tiempos para algunas palabras. Termina de marcarlas en el modo Sincronizar palabras.';

  @override
  String get somethingWentWrong => 'Algo salió mal';

  @override
  String song2(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '$count canción',
    );
    return '$_temp0';
  }

  @override
  String song3(int count, Object server) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '$count canción',
    );
    return '$_temp0 · $server';
  }

  @override
  String get songActions => 'Acciones de la canción';

  @override
  String get songArtist => 'Artista de la canción';

  @override
  String get songCount => 'Cantidad de canciones';

  @override
  String get songGestures => 'Gestos de canción';

  @override
  String get songHasNoFilePath => 'La canción no tiene una ruta de archivo.';

  @override
  String get songMetadata => 'Metadatos de la canción';

  @override
  String get songTitle => 'Título de la canción';

  @override
  String songUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'canciones',
      one: 'canción',
    );
    return '$_temp0';
  }

  @override
  String get songViewList => 'Vista de canciones: lista';

  @override
  String get songViewOrbital => 'Vista de canciones: orbital';

  @override
  String songs(Object arg1, Object arg2) {
    return '$arg1 • $arg2 canciones';
  }

  @override
  String songs12(Object arg1) {
    return '$arg1 canciones';
  }

  @override
  String songs13(Object count) {
    return '$count canciones';
  }

  @override
  String get songs14 => 'Canciones';

  @override
  String songs15(Object arg1) {
    return '$arg1 canciones';
  }

  @override
  String songs2(Object songCount) {
    return '$songCount canciones';
  }

  @override
  String songs3(Object arg1) {
    return '$arg1 canciones';
  }

  @override
  String songs4(Object _totalSongs) {
    return '$_totalSongs canciones';
  }

  @override
  String songs5(Object arg1) {
    return '$arg1 canciones';
  }

  @override
  String songs9(Object arg1) {
    return '$arg1 canciones';
  }

  @override
  String songsAlbums(Object arg1, Object uniqueAlbums) {
    return '$arg1 canciones • $uniqueAlbums álbumes';
  }

  @override
  String songsAlbums2(Object arg1, Object albumCount) {
    return '$arg1 canciones · $albumCount álbumes';
  }

  @override
  String get songsBeforeTheTappedTrackQueue =>
      'Las canciones anteriores a la pista seleccionada se agregan al final de la cola';

  @override
  String get songsCategories => 'Canciones y categorías';

  @override
  String songsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '$count canción',
    );
    return '$_temp0';
  }

  @override
  String songsFound(Object arg1) {
    return 'Se encontraron $arg1 canciones';
  }

  @override
  String songsIn(int songs, int folders) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs canciones',
      one: '$songs canción',
    );
    String _temp1 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders carpetas',
      one: '$folders carpeta',
    );
    return '$_temp0 en $_temp1';
  }

  @override
  String songsInRotation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones en tu rotación',
      one: '$count canción en tu rotación',
    );
    return '$_temp0';
  }

  @override
  String songsU2022Albums(Object arg1, Object uniqueAlbums) {
    return '$arg1 canciones • $uniqueAlbums álbumes';
  }

  @override
  String get songsYouPlayWillAppearHere =>
      'Las canciones que reproduzcas aparecerán aquí';

  @override
  String get songsYouScanIntoYourLibrary =>
      'Las canciones que analices para agregarlas a tu biblioteca aparecerán aquí';

  @override
  String get sortBy => 'ORDENAR POR';

  @override
  String get sortFilter => 'Ordenar y filtrar';

  @override
  String get sortSongs => 'Ordenar canciones';

  @override
  String get source => 'Origen';

  @override
  String get sourceRate => 'Frecuencia de origen';

  @override
  String get spaceBetweenTheTwoBars => 'Espacio entre las dos barras';

  @override
  String get spaceOdyssey => 'Odisea espacial';

  @override
  String get spanishDraftDescription =>
      'Español latinoamericano. Traducción preliminar pendiente de revisión por hablantes nativos.';

  @override
  String get spatialTime => 'Espacial y tiempo';

  @override
  String get speedUp => 'Acelerar';

  @override
  String get springPhysicsEnergeticAndReactive =>
      'Física de resorte: dinámica y reactiva';

  @override
  String get squareRoot => 'Raíz cuadrada';

  @override
  String get stampNext => 'Marcar y siguiente';

  @override
  String get stampNow => 'Marcar ahora';

  @override
  String get stampThisLineFirstToEdit =>
      'Primero marca el tiempo de esta línea para editar su línea de tiempo de palabras.';

  @override
  String get standard => 'Estándar';

  @override
  String get standard60hz => 'Estándar (60 Hz)';

  @override
  String get standardBluetoothRoutingViaAndroid =>
      'Enrutamiento Bluetooth estándar mediante Android';

  @override
  String get standardEngine => 'Motor estándar';

  @override
  String get starlightSerenade => 'Serenata de luz estelar';

  @override
  String get start => 'Iniciar';

  @override
  String get startAtNow => 'Empezar ahora';

  @override
  String get startBuildingYourHome => 'Empieza a crear tu pantalla de inicio';

  @override
  String get startPlayingToPopulateThisSpace =>
      'Empieza a reproducir música para llenar este espacio';

  @override
  String get startStreaming => 'Iniciar transmisión';

  @override
  String get startedPresetDownload => 'Se inició la descarga del preajuste.';

  @override
  String get state => 'Estado';

  @override
  String get status => 'Estado';

  @override
  String get stepByStepWalkthroughOfThe =>
      'Recorrido guiado paso a paso por la app';

  @override
  String get stereo => 'Estéreo';

  @override
  String get stop => 'Detener';

  @override
  String get stopAtTheEndOfThe => 'Detener al final de la lista actual';

  @override
  String get stopCasting => 'Detener transmisión';

  @override
  String get stopStreaming => 'Detener transmisión';

  @override
  String get stopUsbOnQuit => 'Detener USB al salir';

  @override
  String get stopWhenTheQueueEnds => 'Detener al terminar la cola';

  @override
  String stoppingIn(Object arg1) {
    return 'Se detendrá en $arg1';
  }

  @override
  String get storage => 'Almacenamiento';

  @override
  String get storageAccessIsRequiredToScan =>
      'Se necesita acceso al almacenamiento para analizar y leer archivos de música, extraer metadatos, importar o exportar preajustes del ecualizador y guardar imágenes del resumen. Todo el procesamiento se realiza en el dispositivo.';

  @override
  String get storagePermissionIsRequiredToAdd =>
      'Se necesita permiso de almacenamiento para agregar carpetas de música';

  @override
  String get storagePermissionRequiredForRecap =>
      'Se necesita permiso de almacenamiento para guardar imágenes del resumen en esta versión de Android.';

  @override
  String get storagePermissions => 'Permisos de almacenamiento';

  @override
  String get storeOn => 'Guardar en';

  @override
  String get storedAsASaltedHashNever =>
      'Se guarda como un hash con sal, nunca como texto sin cifrar';

  @override
  String get storedEncodedPlaybackUnavailableInThis =>
      'Se guarda codificado en Base64; es necesario para iniciar sesión con NTLM';

  @override
  String get stormChasers => 'Cazatormentas';

  @override
  String get strategy => 'Estrategia';

  @override
  String get stream => 'Flujo';

  @override
  String get streamConfigurationNotAvailable =>
      'Configuración del flujo no disponible';

  @override
  String get streamStable => 'Flujo estable';

  @override
  String get streaming => 'Transmitiendo';

  @override
  String get streamingFromQueue => 'Transmitiendo desde la cola';

  @override
  String get stretchNonSquareArt => 'Estirar portadas no cuadradas';

  @override
  String get strong => 'Fuerte';

  @override
  String get studioGradeOutputForExternalDacs =>
      'Salida de calidad de estudio para DAC externos y amplificadores de audífonos. Omite el procesamiento de audio de Android para ofrecer un sonido puro.';

  @override
  String get sub => 'Subgraves';

  @override
  String subfolderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subcarpetas',
      one: '$count subcarpeta',
    );
    return '$_temp0';
  }

  @override
  String get subsonic => 'Subsonic';

  @override
  String get subsonicServersSyncAndStreaming =>
      'Servidores Subsonic, sincronización y transmisión';

  @override
  String get subtle => 'Sutil';

  @override
  String get support => 'Ayuda';

  @override
  String get supportDevelopmentOnBuyMeACoffee =>
      'Apoya el desarrollo en Buy Me a Coffee';

  @override
  String get supportDevelopmentOnKoFi => 'Apoya el desarrollo en Ko-fi';

  @override
  String get supportFlick => 'Apoyar Flick';

  @override
  String get supportFlickOnKoFi => 'Apoya Flick en Ko-fi';

  @override
  String get surfaceShading => 'Sombreado de superficie';

  @override
  String get sweepAHighlightThroughWordsAs =>
      'Resalta las palabras al ritmo de la voz';

  @override
  String get swipe => 'Deslizar';

  @override
  String get swipeActions => 'Acciones al deslizar';

  @override
  String get swipeHorizontallyToFineTuneEach =>
      'Desliza horizontalmente para ajustar con precisión cada banda central.';

  @override
  String get swipeLeftRightToSkipTracks =>
      'Desliza a la izquierda o a la derecha para cambiar de pista';

  @override
  String get swipeLeftToUnfavoriteASong =>
      'Desliza a la izquierda para quitar una canción de favoritos';

  @override
  String get swipeSongsLeftToQueueOr =>
      'Desliza canciones a la izquierda para agregarlas a la cola o a la derecha para marcarlas como favoritas';

  @override
  String get swipeToShowOrHideThe =>
      'Desliza para mostrar u ocultar el visualizador';

  @override
  String get switchSongs => 'Cambiar canciones';

  @override
  String get switchToTheExclusiveUsbPath =>
      'Cambiar automáticamente a la ruta USB exclusiva cuando se conecte un DAC. Se recuerdan los DAC rechazados.';

  @override
  String get switchedBackToTheAutomaticLyrics =>
      'Se volvió a la fuente automática de letras.';

  @override
  String get syllablesTapALetterToSplit =>
      'Sílabas: toca una letra para separar o unir:\n';

  @override
  String get symmetricalBarsMirroredFromTheCenter =>
      'Barras simétricas reflejadas desde el centro';

  @override
  String get sync => 'Sincronizar';

  @override
  String syncFailed(Object e) {
    return 'Error al sincronizar: $e';
  }

  @override
  String get syncNow => 'Sincronizar ahora';

  @override
  String get syncServerPlaylists => 'Sincronizar listas del servidor';

  @override
  String get synced => 'Sincronizado';

  @override
  String synced2(Object arg1) {
    return 'Sincronizado: $arg1';
  }

  @override
  String get syncedLrc => 'LRC sincronizado';

  @override
  String syncedPlaylistFromServers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se sincronizaron $count listas de reproducción',
      one: 'Se sincronizó $count lista de reproducción',
    );
    return '$_temp0 desde los servidores';
  }

  @override
  String get syncing => 'Sincronizando…';

  @override
  String get synthwaveCity => 'Ciudad synthwave';

  @override
  String get system => 'Sistema';

  @override
  String get systemAndroidMixer => 'Sistema (mezclador de Android)';

  @override
  String get tagsWereWrittenButCouldNot =>
      'Se escribieron las etiquetas, pero no se pudieron confirmar al volver a leer el archivo. Al volver a analizar la biblioteca se corregirán las diferencias.';

  @override
  String tap(Object label) {
    return 'Tocar: «$label»';
  }

  @override
  String get tapABandToExpandDrag =>
      'Toca una banda para ampliarla. Arrastra una perilla para ajustarla. Toca un valor para ingresarlo directamente.';

  @override
  String get tapAllOrEnableAChip =>
      'Toca Todo o activa un filtro para ver resultados';

  @override
  String get tapChipsToFilterCategories =>
      'Toca los filtros para elegir categorías';

  @override
  String get tapEditTextTopRight =>
      '1. Toca Editar texto (arriba a la derecha) y pega las letras, una línea por renglón.\n2. Reproduce la canción.\n3. Elige la línea actual en la lista Líneas.\n4. Toca Marcar y siguiente cuando escuches esa línea.\n5. Cuando termines, guarda los cambios.';

  @override
  String get tapTheHeartIconOnAny =>
      'Toca el ícono del corazón en cualquier canción\npara agregarla a favoritos';

  @override
  String get tapToInspect12602280Png =>
      'Toca para inspeccionar · PNG de 1260 × 2280';

  @override
  String get tapToPreview => 'Toca para obtener una vista previa';

  @override
  String targetMs(Object arg1) {
    return 'objetivo $arg1 ms';
  }

  @override
  String get tempo => 'Tempo';

  @override
  String tempoX(Object arg1) {
    return 'Tempo ${arg1}x';
  }

  @override
  String test(Object arg1) {
    return 'Prueba: $arg1';
  }

  @override
  String get testConnection => 'Probar conexión';

  @override
  String get textGestures => 'Texto y gestos';

  @override
  String get textPlacement => 'Ubicación del texto';

  @override
  String get textPlacement2 => 'Ubicación del texto';

  @override
  String get textSize => 'Tamaño del texto';

  @override
  String get textSize2 => 'Tamaño del texto';

  @override
  String get theAppDoesNotKnowinglyCollect =>
      'La app no recopila deliberadamente información de nadie, sin importar su edad.';

  @override
  String get theAppQueriesPublicApisMusicbrainz =>
      'La app consulta API públicas (MusicBrainz/Cover Art Archive, iTunes y Deezer) para encontrar portadas de álbumes coincidentes. Las búsquedas usan metadatos locales de música. Las imágenes descargadas se guardan en caché local.';

  @override
  String get theAudioEngineDeterminesHowYour =>
      'El motor de audio determina cómo se reproduce la música. Cada opción equilibra de forma distinta la confiabilidad, la calidad y la compatibilidad.';

  @override
  String get theIsochronousUsbEngineWillBe =>
      'El motor USB isócrono se detendrá al cerrar la app.';

  @override
  String get theIsochronousUsbEngineWillStay =>
      'El motor USB isócrono seguirá activo al cerrar la app.';

  @override
  String get theNamesShowingUpAgainAnd =>
      'Los nombres que aparecen una y otra vez en tu cola reciente.';

  @override
  String get thePosterIsNotReadyYet =>
      'El póster aún no está listo. Intenta guardarlo de nuevo.';

  @override
  String get theTracksDominatingYourWeeklyAnd =>
      'Las canciones que más sonaron en tu resumen semanal y mensual.';

  @override
  String get thisAppIsBuiltByA =>
      'Esta app la desarrolla una sola persona y no tiene presupuesto. Si te gusta el audio de alta fidelidad, considera apoyar su desarrollo en Ko-fi.';

  @override
  String get thisClearsYourCurrentDayStreak =>
      'Esto borrará tu racha actual y los hitos de racha que hayas desbloqueado. Esta acción no se puede deshacer.';

  @override
  String get thisDevice => 'Este dispositivo';

  @override
  String get thisFolderAppearsToBeEmpty => 'Esta carpeta parece estar vacía';

  @override
  String get thisFolderHasAlreadyBeenAdded => 'Esta carpeta ya se agregó';

  @override
  String get thisMonth => 'Este mes';

  @override
  String get thisMonthSRecap => 'Resumen de este mes';

  @override
  String thisRemovesAllEntriesFromMemory(Object arg1) {
    return 'Esto quita de la memoria todas las entradas de $arg1.';
  }

  @override
  String get thisSlowsPlaybackTo432440 =>
      'Esto baja la reproducción a 432/440 (aprox. 1,8 % menos de tono y tempo) y desactiva el paso directo bit perfecto. La música sonará un poco más grave. Activa esta opción solo si quieres intencionalmente afinar a A=432.';

  @override
  String get thisSongHasNoFilePath =>
      'Esta canción no tiene una ruta de archivo y no se puede editar.';

  @override
  String get thisSongIsMissingAlbumMetadata =>
      'A esta canción le faltan los metadatos del álbum, por lo que la búsqueda en línea es limitada.';

  @override
  String get thisSongOnly => 'Solo esta canción';

  @override
  String get thisWeek => 'Esta semana';

  @override
  String get thisWeekSRecap => 'Resumen de esta semana';

  @override
  String get thisYearSRecap => 'Resumen de este año';

  @override
  String get threshold => 'Umbral';

  @override
  String get thunderRoad => 'Thunder Road';

  @override
  String get tidal => 'Tidal';

  @override
  String get tidalAppKeyRejected =>
      'Tidal rechazó la clave de inicio de sesión de la app. Estas claves cambian, así que la integrada podría estar desactualizada (una limitación conocida de la integración no oficial).';

  @override
  String tidalCouldNotReach(int status) {
    return 'No se pudo acceder a Tidal (HTTP $status). Comprueba tu conexión.';
  }

  @override
  String tidalEncryptedTrack(String trackId) {
    return 'La pista $trackId está cifrada (HiRes/MQA). Solo se admite audio HiFi sin pérdida que no esté cifrado.';
  }

  @override
  String tidalManifestDecodeFailed(String trackId, String error) {
    return 'No se pudo decodificar el manifiesto de Tidal para la pista $trackId: $error';
  }

  @override
  String tidalManifestNoStream(String trackId) {
    return 'La pista $trackId no tiene una URL de transmisión en su manifiesto.';
  }

  @override
  String get tidalNoPlayableStream =>
      'No hay una transmisión reproducible para esta pista.';

  @override
  String get tidalNoSignInCode =>
      'Tidal no devolvió un código de inicio de sesión.';

  @override
  String get tidalNotSignedIn =>
      'No iniciaste sesión en Tidal. Toca Iniciar sesión con Tidal.';

  @override
  String tidalOpenLinkManually(String uri) {
    return 'No se pudo abrir el navegador automáticamente. Abre este enlace en cualquier dispositivo para terminar de iniciar sesión y luego toca Iniciar sesión otra vez:\n\n$uri';
  }

  @override
  String get tidalSessionExpired =>
      'La sesión de Tidal venció. Vuelve a iniciar sesión.';

  @override
  String get tidalSignInDenied => 'Se rechazó el inicio de sesión en Tidal.';

  @override
  String get tidalSignInExpired =>
      'El código de inicio de sesión de Tidal venció. Inténtalo de nuevo.';

  @override
  String get tidalSignInRefused =>
      'Tidal rechazó el inicio de sesión. Inténtalo de nuevo.';

  @override
  String get tidalSignInTimedOut =>
      'Se agotó el tiempo de espera para iniciar sesión en Tidal.';

  @override
  String get tidalTokenRefreshFailed =>
      'No se pudo actualizar el token de Tidal.';

  @override
  String get tidalTooManyRequests =>
      'Demasiadas solicitudes a Tidal. Espera un momento e inténtalo de nuevo.';

  @override
  String get tidalUnavailable =>
      'Tidal no está disponible ahora. Inténtalo de nuevo en un momento.';

  @override
  String tidalUnsupportedFormat(String trackId) {
    return 'La pista $trackId usa un formato de Tidal no compatible (HiRes/MQA/Atmos). Solo se admite audio HiFi sin pérdida que no esté cifrado.';
  }

  @override
  String get time => 'Hora';

  @override
  String get timeShift => 'Desplazamiento de tiempo';

  @override
  String get timestamp => 'Marca de tiempo';

  @override
  String get tintedFromTodaySTopCover =>
      'Con tinte de la portada más destacada de hoy';

  @override
  String get tips => 'Consejos';

  @override
  String get title => 'Título';

  @override
  String get toRemove => 'Por quitar';

  @override
  String get today => 'Hoy';

  @override
  String get todaySRecap => 'Resumen de hoy';

  @override
  String get toneControls => 'Controles de tono';

  @override
  String get tools => 'Herramientas';

  @override
  String get top => 'Arriba';

  @override
  String get topAlbum => 'Álbum destacado';

  @override
  String get topArtist => 'Artista destacado';

  @override
  String get topArtists => 'Artistas destacados';

  @override
  String get topSongs => 'Canciones destacadas';

  @override
  String get topSongs2 => 'Canciones destacadas';

  @override
  String get total => 'Total';

  @override
  String get track => 'Pista';

  @override
  String track2(Object arg1) {
    return 'Pista $arg1';
  }

  @override
  String get track3 => 'N.º de pista';

  @override
  String get trackBitDepth => 'Profundidad de bits de la pista';

  @override
  String get trackChannels => 'Canales de la pista';

  @override
  String get trackConsecutiveListeningDaysAndShow =>
      'Registrar los días consecutivos de escucha y mostrar la ventana emergente';

  @override
  String get trackCount => 'Cantidad de pistas';

  @override
  String get trackDsdRate => 'Frecuencia DSD de la pista';

  @override
  String get trackNumber => 'Número de pista';

  @override
  String get trackSampleRate => 'Frecuencia de muestreo de la pista';

  @override
  String get trackThumbnails => 'Miniaturas de pistas';

  @override
  String get trackTime => 'Duración de la pista';

  @override
  String get trackTimeSumsTheFullDuration =>
      'La duración de la pista suma el tiempo total de todas las reproducciones registradas.';

  @override
  String tracks(Object _totalTracks) {
    return '$_totalTracks pistas';
  }

  @override
  String tracks2(Object arg1) {
    return '$arg1 pistas';
  }

  @override
  String tracks3(Object arg1) {
    return '$arg1 pistas';
  }

  @override
  String tracks4(Object arg1) {
    return '$arg1 pistas';
  }

  @override
  String tracks5(Object arg1, Object arg2) {
    return '$arg1 · $arg2 pistas';
  }

  @override
  String tracks6(Object arg1) {
    return '$arg1 pistas';
  }

  @override
  String tracks7(Object trackCount, Object arg1) {
    return '$trackCount pistas • $arg1';
  }

  @override
  String tracks8(Object arg1) {
    return '$arg1 pistas';
  }

  @override
  String tracksLikedSongsPlaylists(
    Object songCount,
    Object favoriteCount,
    Object playlistCount,
  ) {
    return '$songCount pistas, $favoriteCount canciones que te gustan, $playlistCount listas de reproducción';
  }

  @override
  String tracksReadyToRevisit(Object favoritesCount) {
    return '$favoritesCount pistas para volver a escuchar';
  }

  @override
  String get tracksThatFitTheQuieterSide =>
      'Canciones que van con el lado más tranquilo de lo que escuchas.';

  @override
  String get transparent => 'Transparente';

  @override
  String get treble => 'Agudos';

  @override
  String get trueRandomMayRepeatBeforeList =>
      'Aleatorio real (puede repetir antes de terminar la lista)';

  @override
  String get truncate => 'Recortar';

  @override
  String get tryAdjustingYourSearchQuery => 'Prueba a modificar la búsqueda';

  @override
  String get tryAgain => 'Inténtalo de nuevo';

  @override
  String get tryAnotherKeywordOrEnableMore =>
      'Prueba con otra palabra clave o activa más categorías';

  @override
  String get tryOriginalSearch => 'Probar la búsqueda original';

  @override
  String get tryPickingALocalImageIf =>
      'Prueba a elegir una imagen local si los metadatos del lanzamiento son poco comunes.';

  @override
  String get turnOff432HzTuningTo =>
      'Desactiva la afinación a 432 Hz para usar el fundido cruzado';

  @override
  String get turnOff432HzTuningTo2 =>
      'Desactiva la afinación a 432 Hz para usar la mezcla entre canales';

  @override
  String get typeABrandAndModelTo =>
      'Escribe la marca y el modelo para buscar en línea.';

  @override
  String get u162ByteSubslotsLlRr => 'U16: subranuras de 2 bytes, LL|RR';

  @override
  String u2022(Object arg1, Object valueLabel) {
    return '$arg1  •  $valueLabel';
  }

  @override
  String u20223(Object arg1, Object gainLabel) {
    return '$arg1  •  $gainLabel';
  }

  @override
  String u2022Bit(Object arg1) {
    return ' • $arg1 bits';
  }

  @override
  String get u324ByteSubslotsLlllRrrr =>
      'U32: subranuras de 4 bytes, LLLL|RRRR (heredado)';

  @override
  String get u8ByteInterleavedLrlr => 'U8: intercalado por bytes LRLR';

  @override
  String get u8ByteInterleavedRecommendedDefault =>
      'U8: intercalado por bytes, predeterminado recomendado';

  @override
  String get uac2AndEqualizer => 'UAC2 y ecualizador';

  @override
  String get uac2IsNotAvailableOnThis =>
      'UAC2 no está disponible en esta plataforma';

  @override
  String get uac2NotAvailableOnThisPlatform =>
      'UAC2 no está disponible en esta plataforma';

  @override
  String get uac2Preferences => 'Preferencias de UAC2';

  @override
  String get uac2PreferencesResetSuccessfully =>
      'Se restablecieron las preferencias de UAC2';

  @override
  String get uiCustomization => 'Personalización de la interfaz';

  @override
  String get ultra => 'Ultra';

  @override
  String get unableToCheckForUpdatesRight =>
      'No se pueden buscar actualizaciones en este momento.';

  @override
  String get unableToLoadPatchNotesRight =>
      'No se pueden cargar las notas de la versión en este momento.';

  @override
  String get unableToOpenAllFilesAccess =>
      'No se puede abrir la configuración de acceso a todos los archivos';

  @override
  String get unableToOpenBatteryOptimizationSettings =>
      'No se puede abrir la configuración de optimización de batería';

  @override
  String unavailable(Object featureName) {
    return '$featureName no disponible';
  }

  @override
  String get unavailable2 => 'No disponible';

  @override
  String underruns(Object arg1) {
    return '$arg1 subdesbordamientos';
  }

  @override
  String get undo => 'Deshacer';

  @override
  String get unfavorite => 'Quitar de favoritos';

  @override
  String get unfavoriteSelected => 'Quitar la selección de favoritos';

  @override
  String get uniqueArtists => 'Artistas únicos';

  @override
  String get universalCompatibility => 'Compatibilidad universal';

  @override
  String get unknown => 'Desconocido';

  @override
  String get unknownAlbum => 'Álbum desconocido';

  @override
  String get unknownArtist => 'Artista desconocido';

  @override
  String get unknownBitrate => 'Tasa de bits desconocida';

  @override
  String get unknownFolder => 'Carpeta desconocida';

  @override
  String get unknownLastFmError => 'Error desconocido de Last.fm';

  @override
  String get unknownTitle => 'Título desconocido';

  @override
  String get unknownTrack => 'Pista desconocida';

  @override
  String unlocked(Object unlocked, Object arg1) {
    return '$unlocked / $arg1 desbloqueados';
  }

  @override
  String unlocked3(Object _milestonesUnlocked, Object arg1) {
    return '$_milestonesUnlocked / $arg1 desbloqueados';
  }

  @override
  String get unmute => 'Activar sonido';

  @override
  String get unreported => 'No informado';

  @override
  String get unsavedChanges => 'Cambios sin guardar';

  @override
  String up(Object arg1) {
    return '$arg1 arriba';
  }

  @override
  String get upNext => 'A continuación';

  @override
  String upcomingSong(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count próximas canciones',
      one: '$count próxima canción',
    );
    return '$_temp0';
  }

  @override
  String get update => 'Actualizar';

  @override
  String get updateAvailable => 'Actualización disponible';

  @override
  String get updateAvailableDownloadFromFlickPlayer =>
      'Hay una actualización disponible: descárgala desde flick-player.site';

  @override
  String get updateAvailableOnThePlayStore =>
      'Hay una actualización disponible en Play Store.';

  @override
  String get updateNoticeHidden => 'Se ocultó el aviso de actualización.';

  @override
  String updated(Object arg1) {
    return 'Actualizado: $arg1';
  }

  @override
  String updatedAlbumArtFor(Object arg1) {
    return 'Se actualizó la portada del álbum «$arg1».';
  }

  @override
  String updatedAlbumArtFor2(Object arg1) {
    return 'Se actualizó la portada del álbum «$arg1».';
  }

  @override
  String get updates => 'Actualizaciones';

  @override
  String get updatesAboutAndSupport => 'Actualizaciones, información y ayuda';

  @override
  String get upload => 'Subir';

  @override
  String uploadFailed(Object arg1) {
    return 'Error al subir ($arg1).';
  }

  @override
  String uploadFailed2(Object e) {
    return 'Error al subir: $e';
  }

  @override
  String get uploadLogsAsALink => '¿Subir los registros como enlace?';

  @override
  String get upnpDlna => 'UPnP / DLNA';

  @override
  String get urbPacket => 'Paquete URB';

  @override
  String get urbTransfer => 'Transferencia URB';

  @override
  String get urbanEchoes => 'Ecos urbanos';

  @override
  String get usbAudioClass20Devices =>
      'Los dispositivos USB Audio Class 2.0 (DAC/amplificadores externos) se usan localmente para reproducir audio bit perfecto. No se transmite información de dispositivos USB a terceros.';

  @override
  String get usbAudioDevice => 'Dispositivo de audio USB';

  @override
  String get usbAudioDevices => 'Dispositivos de audio USB';

  @override
  String get usbAudioError => 'Error de audio USB';

  @override
  String get usbAudioUac2 => 'Audio USB (UAC2)';

  @override
  String get usbDacAutoBitPerfectOffers =>
      'Se restablecieron las ofertas automáticas de modo bit perfecto para DAC USB.';

  @override
  String get usbDacsHeadphonesAndReferenceGear =>
      'DAC USB, audífonos y equipos de referencia para probar y mejorar la calidad de reproducción.';

  @override
  String get usbDeviceAccess => 'Acceso al dispositivo USB';

  @override
  String get usbNotConnected => 'USB no conectado';

  @override
  String get usbRouteVolume => 'Volumen de la ruta USB';

  @override
  String get usbStorageNotConnected => 'Almacenamiento USB no conectado';

  @override
  String get usbVolume => 'Volumen USB';

  @override
  String get usbVolumeInSettings => 'Volumen USB en Ajustes';

  @override
  String get usbVolumeOnHome => 'Volumen USB en Inicio';

  @override
  String get useAFixed48khz16bitOutput =>
      'Usar una salida fija de 48 kHz/16 bits para mejorar la compatibilidad';

  @override
  String get useAaudioDirectlyLowestLatencyOn =>
      'Usar AAudio directamente. Menor latencia en Android 8.1 y versiones posteriores.';

  @override
  String get useAlbumArtAsBackground => 'Usar la portada del álbum como fondo';

  @override
  String get useAutoSource => 'Usar fuente automática';

  @override
  String get useCurrentTime => 'Usar hora actual';

  @override
  String get useExistingFile => 'Usar archivo existente';

  @override
  String get useExistingFileInTheLyrics =>
      '- «Usar archivo existente» en el panel de letras vincula un archivo `.lrc`, `.txt` o `.xml`.\n- Si algunas líneas no tienen tiempo marcado, Flick los completa automáticamente.\n- Al guardar, se escribe junto a la canción cuando es posible; de lo contrario, Flick guarda una copia vinculada.';

  @override
  String get useFilesystemLevelScanningInsteadOf =>
      'Usar análisis a nivel del sistema de archivos en lugar de MediaStore para obtener etiquetas más precisas';

  @override
  String get useMmSsCcEG => 'Usar mm:ss.cc; por ejemplo, 01:23.45';

  @override
  String get useTheCurrentAudioFileS =>
      'Usar el nombre del archivo de audio actual al guardar las letras en la app';

  @override
  String get useTheDefaultMonochromeTheme =>
      'Usar el tema monocromático predeterminado.';

  @override
  String get useTheHighestFixedOutputRate =>
      'Usar la frecuencia de salida fija y la profundidad de bits más altas disponibles';

  @override
  String get useTheLegacyOpenslEsBackend =>
      'Usar el motor OpenSL ES heredado. Alternativa para solucionar problemas en dispositivos antiguos o problemáticos.';

  @override
  String get useTheListSongsBrowser => 'Usar la vista de canciones en lista';

  @override
  String get useTheOrbitalSongsBrowser => 'Usar la vista orbital de canciones';

  @override
  String get useTheVerifiedDirectUsbPath =>
      'Usar la ruta USB directa verificada y desactivar los controles de DSP por software que impedirían la reproducción bit perfecta en un DAC USB externo.';

  @override
  String get userToken => 'Token de usuario';

  @override
  String get username => 'Nombre de usuario';

  @override
  String using(Object arg1) {
    return 'Usando $arg1';
  }

  @override
  String using2(Object arg1) {
    return 'Usando $arg1';
  }

  @override
  String get variableBitrateLowLatency =>
      'Tasa de bits variable y baja latencia';

  @override
  String get variousArtists2 => 'Varios artistas';

  @override
  String get velvetNoir => 'Noir aterciopelado';

  @override
  String get vendorId => 'ID del proveedor';

  @override
  String get verboseDartRustAndCrashLogs =>
      'Registros detallados de Dart, Rust y fallos';

  @override
  String get verified => 'Verificado';

  @override
  String version(Object kAppVersion) {
    return 'Versión $kAppVersion';
  }

  @override
  String version2(Object arg1) {
    return 'Versión $arg1';
  }

  @override
  String get verticalBarsClassicSpectrumAnalyzer =>
      'Barras verticales: analizador de espectro clásico';

  @override
  String get verticalBarsThatAnimateAcrossThe =>
      'Barras verticales que se animan por toda la pantalla.';

  @override
  String get verticalPosition => 'Posición vertical';

  @override
  String get vibrant => 'Intenso';

  @override
  String get viewAsGrid => 'Ver como cuadrícula';

  @override
  String get viewAsList => 'Ver como lista';

  @override
  String get viewMetadata => 'Ver metadatos';

  @override
  String get viewOnboarding => 'Ver bienvenida';

  @override
  String get viewQueue => 'Ver cola';

  @override
  String get visualizer => 'Visualizador';

  @override
  String get visualizerAlbumColorsDescription =>
      'Seguir los colores de la portada; usar monocromo si no están disponibles';

  @override
  String get visualizerAnimationsOffApp =>
      'Las animaciones están desactivadas en Flick. Actívalas en Ajustes → Interfaz → Animaciones para que el visualizador se mueva.';

  @override
  String get visualizerAnimationsOffSystem =>
      'La opción «Quitar animaciones» está activada en los ajustes de accesibilidad de Android. El visualizador permanecerá quieto hasta que vuelvas a activar las animaciones.';

  @override
  String get visualizerAnimationsOffTitle => 'Visualizador en pausa';

  @override
  String get visualizerUnavailableBitPerfectTitle =>
      'Visualizador no disponible en modo bit-perfect';

  @override
  String get visualizerUnavailableBitPerfectBody =>
      'El modo bit-perfect envía el audio original directamente a tu DAC, así que Flick no tiene un flujo procesado que analizar. Cambia al Motor de Alta Calidad para usar el visualizador en vivo.';

  @override
  String get visualizerSwitchToHighQuality =>
      'Cambiar al Motor de Alta Calidad';

  @override
  String get visualizerKeepBitPerfect => 'Mantener bit-perfect';

  @override
  String get visualizerSourceLiveFft => 'Fuente: FFT en vivo (Rust)';

  @override
  String get visualizerSourceRustBody =>
      'Se calcula a partir del flujo PCM del motor High Quality. No necesita permiso de micrófono.';

  @override
  String get visualizerSourceLiveAndroid => 'Fuente: En vivo (Android)';

  @override
  String get visualizerSourceUnavailable => 'Fuente: No disponible';

  @override
  String get visualizerSourceDsdUnavailable => 'Fuente: No disponible para DSD';

  @override
  String get visualizerStandardMicTitle => 'Se necesita permiso de micrófono';

  @override
  String get visualizerStandardMicBody =>
      'El visualizador de Android lee la mezcla de salida del Motor Estándar. Flick no graba ni almacena audio. El Motor de Alta Calidad usa la FFT propia de Flick y no necesita este permiso.';

  @override
  String get visualizerUnavailableDsdTitle =>
      'Visualizador no disponible para DSD';

  @override
  String get visualizerUnavailableDsdBody =>
      'El DSD nativo y DoP se envían directamente a tu DAC, así que no hay un flujo PCM que analizar. El visualizador vuelve con pistas PCM.';

  @override
  String get visualizerPermissionDenied =>
      'Se denegó el permiso de micrófono. El visualizador de Android no puede leer la salida del Motor Estándar sin él.';

  @override
  String get visualizerPausedBitPerfect =>
      'Visualizador pausado por la salida bit-perfect.';

  @override
  String get visualizerPausedDsd =>
      'Visualizador pausado durante la reproducción DSD.';

  @override
  String get visualizerBlocks => 'Bloques que se desvanecen';

  @override
  String get visualizerBlocksDescription =>
      'Barras segmentadas con estelas que se desvanecen suavemente';

  @override
  String get visualizerColors => 'Colores';

  @override
  String get visualizerMonochrome => 'Monocromático';

  @override
  String get visualizerMonochromeDescription =>
      'Blanco y gris, independientemente de la portada del álbum';

  @override
  String get visualizerRainbow => 'Arcoíris';

  @override
  String get visualizerRainbowDescription =>
      'Un espectro de colores en todo el visualizador';

  @override
  String get visuals => 'Visuales';

  @override
  String get volume => 'Volumen';

  @override
  String get volumeControl => 'Control de volumen';

  @override
  String get volumeDipsWhileNotificationSoundsPlay =>
      'El volumen baja mientras suenan las notificaciones';

  @override
  String get volumeIsFixedWhileBitPerfect =>
      'El volumen se mantiene fijo durante el paso directo bit perfecto porque Flick no puede controlar el volumen del hardware USB. Usa los controles del dispositivo o reproduce PCM con el modo bit perfecto desactivado para ajustar el volumen por software.';

  @override
  String get volumeIsFixedWhileBitPerfect2 =>
      'El volumen se mantiene fijo durante el paso directo bit perfecto porque Flick no puede controlar el volumen del hardware USB. Usa los controles del dispositivo o reproduce PCM con el modo bit perfecto desactivado para ajustar el volumen por software.';

  @override
  String get directUsbFormatNotice =>
      'Se detectó un DAC USB directo. La conexión USB directa omite el mezclador y el volumen del sistema Android. El formato mostrado es el formato de contenido solicitado, no una medición de la frecuencia de salida del DAC.';

  @override
  String get usbVolumeSafetyPaused =>
      'No se pudo confirmar el volumen del DAC. Pulsa Reproducir para volver a intentarlo con un nivel bajo. Si vuelve a fallar, reconecta el DAC.';

  @override
  String get usbHardwareVolumeUnavailable =>
      'Flick no puede controlar el volumen del hardware USB. Durante el paso directo bit perfecto, usa los controles físicos del dispositivo. Para ajustar el volumen por software, reproduce PCM con el modo bit perfecto desactivado.';

  @override
  String usbHardwareVolumeError(String reason) {
    return 'Volumen del hardware USB: $reason';
  }

  @override
  String wAgo(Object arg1) {
    return 'hace $arg1 sem';
  }

  @override
  String get waitingForBrowserAuthorization =>
      'Esperando la autorización del navegador…';

  @override
  String get waitingForPlayback => 'Esperando la reproducción';

  @override
  String was(Object arg1) {
    return 'era: $arg1';
  }

  @override
  String get wave => 'Onda';

  @override
  String get waveform => 'Forma de onda';

  @override
  String get waveformHeight => 'Altura de la forma de onda';

  @override
  String get waveformHeightDescription =>
      'Ajusta la altura de las barras de la forma de onda.';

  @override
  String get waveformSeekbar => 'Barra de reproducción con forma de onda';

  @override
  String weLlKeepTheBestQuality(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copias',
      one: '$count copia',
    );
    return 'Conservaremos la versión de mejor calidad de cada grupo (se prefiere la portada del álbum y luego la tasa de bits más alta) y quitaremos $_temp0. Los archivos del disco no se eliminarán.';
  }

  @override
  String weLlKeepYourCheckedVersion(int kept, int removed) {
    String _temp0 = intl.Intl.pluralLogic(
      kept,
      locale: localeName,
      other: '$kept versiones que marcaste',
      one: '$kept versión que marcaste',
    );
    String _temp1 = intl.Intl.pluralLogic(
      removed,
      locale: localeName,
      other: '$removed copias restantes',
      one: '$removed copia restante',
    );
    return 'Conservaremos $_temp0 y quitaremos de la biblioteca $_temp1. Los archivos de audio del disco no se eliminarán.';
  }

  @override
  String get webdav => 'WebDAV';

  @override
  String get weekly => 'Semanal';

  @override
  String get welcomeBackLetSStartA =>
      '¡Qué bueno tenerte de vuelta! Empecemos una racha.';

  @override
  String get welcomeToFlick => '¡Te damos la bienvenida a Flick!';

  @override
  String get whatItShows => 'Qué muestra';

  @override
  String get whatSNew => 'Novedades';

  @override
  String get whenBitPerfectOutputIs =>
      'Cuando la salida bit perfecta está activa, una cápsula muestra la frecuencia de muestreo y la profundidad de bits que se envían al DAC.';

  @override
  String get whenYouPlayOverBluetoothAndroid =>
      'Al reproducir por Bluetooth, Android negocia el códec con tus audífonos o bocina.';

  @override
  String get whereShouldTheLrcFileBe =>
      '¿Dónde quieres guardar el archivo .lrc?';

  @override
  String get whereTheFocalSongSitsVertically =>
      'Posición vertical de la canción destacada';

  @override
  String get whereYourMoneyGoes => 'A dónde va tu dinero';

  @override
  String get whisperWorld => 'Mundo susurrante';

  @override
  String get whisperedSecrets => 'Secretos susurrados';

  @override
  String get white => 'Blanco';

  @override
  String get wholeAlbum => 'Álbum completo';

  @override
  String get whyDonate => '¿Por qué donar?';

  @override
  String wide(Object amount) {
    return '$amount% de ancho';
  }

  @override
  String get widgets => 'Widgets';

  @override
  String get width => 'Ancho';

  @override
  String get wildWeather => 'Clima salvaje';

  @override
  String get willBeRemoved => 'Se quitará';

  @override
  String get willKeep => 'Se conservará';

  @override
  String get wiredOutput => 'Salida por cable';

  @override
  String word(Object arg1, Object arg2) {
    return 'Palabra $arg1 · «$arg2»';
  }

  @override
  String word2(Object arg1, Object token) {
    return 'Palabra $arg1 · «$token»';
  }

  @override
  String get wordSync => 'Sincronizar palabras';

  @override
  String get wordSyncModeKaraoke => 'Modo Sincronizar palabras (karaoke)';

  @override
  String wordTimelineLine(Object arg1) {
    return 'Línea de tiempo de palabras · Línea $arg1';
  }

  @override
  String get wrapAroundAndQueueBehavior =>
      'Repetición y comportamiento de la cola';

  @override
  String get wrapAroundQueue => 'Cola con repetición';

  @override
  String get writeADescription => 'Escribe una descripción';

  @override
  String x(Object min) {
    return '${min}x';
  }

  @override
  String x2(Object max) {
    return '${max}x';
  }

  @override
  String x3(Object currentSpeed) {
    return '${currentSpeed}x';
  }

  @override
  String yAgo(Object arg1) {
    return 'hace $arg1 años';
  }

  @override
  String get year => 'Año';

  @override
  String get yearly => 'Anual';

  @override
  String get yesterday => 'Ayer';

  @override
  String get youAlreadyHaveTheLatestFlick =>
      'Ya tienes la versión más reciente de Flick';

  @override
  String get youAlreadyHaveTheLatestPlay =>
      'Ya tienes la versión más reciente de Play Store';

  @override
  String get youCanAlsoChangeTheCodec =>
      'También puedes cambiar el códec en Opciones para desarrolladores de Android, en «Códec de audio Bluetooth».';

  @override
  String get youCustomizedWhichVersionsToKeep =>
      'Personalizaste cuáles versiones conservar. Bien: tú decides.';

  @override
  String get youHaveUnsavedChangesAreYou =>
      'Tienes cambios sin guardar. ¿Seguro que quieres descartarlos?';

  @override
  String get youHaveUnsavedLyricEditsLeave =>
      'Tienes cambios sin guardar en las letras. ¿Quieres salir del Estudio de sincronización sin guardarlos?';

  @override
  String get youReOffline => 'No tienes conexión';

  @override
  String get youReOfflineSomeOnlineFeatures =>
      'No tienes conexión. Es posible que algunas funciones en línea no estén disponibles.';

  @override
  String get youVeHitTheThresholdKeep => 'Llegaste al umbral: ¡sigue así!';

  @override
  String get yourCollectionAtAGlance => 'Tu colección de un vistazo';

  @override
  String get yourCustomCollections => 'Tus colecciones personalizadas';

  @override
  String get yourHeaviestRotationRightNow => 'Lo que más escuchas ahora';

  @override
  String get yourLatestLibraryScans =>
      'Tus análisis de biblioteca más recientes';

  @override
  String get yourLibrary => 'Tu biblioteca';

  @override
  String get yourLibraryAtAGlance => 'Tu biblioteca de un vistazo';

  @override
  String get yourLibraryIsTidyWeLl =>
      'Tu biblioteca está ordenada. Te avisaremos si aparecen nuevos duplicados después del próximo análisis.';

  @override
  String get yourListeningHistoryIsStillYours =>
      'Tu historial de escucha sigue siendo tuyo. Intenta cargarlo de nuevo.';

  @override
  String get yourListensWillRemainOnListenbrainz =>
      'Tus reproducciones seguirán en ListenBrainz, pero Flick dejará de enviarlas.';

  @override
  String get yourLogsAreUploadedToDpaste =>
      'Tus registros se suben a dpaste.com como un enlace no listado que vence en 30 días. Cualquier persona con el enlace podrá leerlos; los registros pueden incluir rutas de archivos y detalles del dispositivo.';

  @override
  String get yourMonthlyRecapNeedsABit =>
      'Tu resumen mensual necesita un poco más de tiempo de escucha este mes.';

  @override
  String get yourMostReplayedTrack => 'La pista que más repetiste';

  @override
  String get yourMusicIsBeingScrobbled =>
      'Se están registrando tus reproducciones';

  @override
  String get yourMusicIsBeingSubmitted =>
      'Se están enviando tus reproducciones';

  @override
  String get yourMusicOnRepeat => 'Tu música. Una y otra vez.';

  @override
  String get yourNewAudioEngineIsReady =>
      'Tu nuevo motor de audio está listo. Reinicia Flick para aplicarlo.';

  @override
  String get yourNextFavoriteIsWaiting => 'Tu próximo favorito te espera.';

  @override
  String get yourNextFavoriteNisWaiting => 'Tu próximo favorito\nte espera.';

  @override
  String get yourPlaylists => 'Tus listas de reproducción';

  @override
  String get yourScrobblingHistoryWillRemainOn =>
      'Tu historial de reproducciones seguirá en Last.fm, pero Flick dejará de enviar los registros.';

  @override
  String get yourSessionHistory => 'Tu historial de sesiones';

  @override
  String get yourWeeklyRecapAppearsOnceYou =>
      'Tu resumen semanal aparecerá cuando empieces a escuchar música esta semana.';

  @override
  String get yourYearlyRecapFillsInAs =>
      'Tu resumen anual se completa a medida que escuchas música durante el año.';
}
