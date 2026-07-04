// Dev-only catalog generator. Not shipped; run by hand on version bumps.
//
//   dart run tool/gen_autoeq_catalog.dart
//
// Fetches curated headphone models from jaakkopasanen/AutoEq, parses their
// ParametricEQ.txt, and writes minified assets into assets/autoeq/.
// Stdlib only (no pub deps): dart:io HttpClient for API + raw fetches.
//

import 'dart:convert';
import 'dart:io';

const _owner = 'jaakkopasanen';
const _repo = 'AutoEq';
const _branch = 'master';

// Measurement-campaign preference, most reputable modern rigs first.
// First hit wins when a model exists under several campaigns.
const _campaignPriority = <String>[
  'HypetheSonics',
  'Kuulokenurkka',
  'Super Review',
  'Filk',
  'Regan Cipher',
  'RikudouGoku',
  'Jaytiss',
  'Auriculares Argentina',
  'Bakkwatan',
  'Fahryst',
  'Kazi',
  'Harpo',
  'Hi End Portable',
  'Rtings',
  'Crinacle',
  'Innerfidelity',
  'Headphone.com Legacy',
  'DHRME',
];

// Curated manifest: brand -> [models]. Model strings match by normalized
// "ends-with" against the AutoEq folder name, so the brand prefix is optional.
// Misses are reported and simply excluded from the output.
const _manifest = <String, List<String>>{
  // ---- Mainstream / TWS ----
  'Apple': [
    'EarPods', 'AirPods (1st generation)', 'AirPods (2nd generation)',
    'AirPods (3rd generation)', 'AirPods Pro', 'AirPods Pro 2', 'AirPods Max',
    'AirPods 4', 'AirPods 4 (ANC on)',
  ],
  'Sony': [
    'WH-1000XM2', 'WH-1000XM3', 'WH-1000XM4', 'WH-1000XM5', 'WH-1000XM6',
    'WF-1000XM3', 'WF-1000XM4', 'WF-1000XM5', 'MDR-7506', 'MDR-V6',
    'MDR-1AM2', 'MDR-1A', 'MDR-Z1R', 'MDR-Z7', 'WH-CH700N', 'WH-CH710N',
    'WH-XB900N', 'WH-H900N', 'MDR-EX1000', 'MDR-7520',
  ],
  'Bose': [
    'QuietComfort 35', 'QuietComfort 35 II', 'QuietComfort 45',
    'QuietComfort Ultra Headphones', 'Noise Cancelling Headphones 700',
    'QuietComfort Earbuds', 'QuietComfort Earbuds II',
    'QuietComfort Ultra Earbuds', 'SoundSport Free', 'SoundSport Wireless',
  ],
  'Samsung': [
    'Galaxy Buds Pro', 'Galaxy Buds2 Pro', 'Galaxy Buds2', 'Galaxy Buds3',
    'Galaxy Buds3 Pro', 'Galaxy Buds Live', 'Galaxy Buds FE', 'Galaxy Buds+',
    'Galaxy Buds',
  ],
  'Jabra': [
    'Elite 75t', 'Elite Active 75t', 'Elite 85t', 'Elite 4 Active',
    'Elite 5', 'Elite 8 Active', 'Elite 10', 'Elite Active 65t',
  ],
  'JBL': [
    'Tune 130NC', 'Tune 230NC', 'Live Free 2', 'Reflect Flow Pro',
    'Tune 720BT', 'Tune 510BT', 'Endurance Peak 3', 'Tune Flex',
  ],
  'Soundcore': [
    'Liberty 4 NC', 'Liberty 3 Pro', 'Liberty Air 2 Pro', 'Life Q30',
    'Life Q35', 'Life A2 NC', 'Space Q45', 'Space One', 'Liberty 4',
  ],
  // ---- Over-ear audiophile ----
  'Sennheiser': [
    'HD 600', 'HD 650', 'HD 660S', 'HD 660S2', 'HD 6XX', 'HD 800', 'HD 800S',
    'HD 598', 'HD 599', 'HD 599 SE', 'HD 280 Pro', 'HD 380 Pro', 'HD 569',
    'HD 579', 'HD 25', 'HD 25-1 II', 'HD 25 SP II', 'HD 26 PRO', 'HD 450BT',
    'HD 458BT', 'Momentum True Wireless 2', 'Momentum True Wireless 3',
    'Momentum 4 Wireless', 'Momentum Wireless', 'IE 200', 'IE 300', 'IE 600',
    'IE 900', 'CX 400BT', 'PC38X', 'GAME ZERO', 'GAME ONE', 'GSP 600',
  ],
  'Beyerdynamic': [
    'DT 770 Pro (80 Ohm)', 'DT 770 Pro (250 Ohm)', 'DT 770 Pro (600 Ohm)',
    'DT 880 (250 Ohm)', 'DT 880 (600 Ohm)', 'DT 990 Pro (250 Ohm)',
    'DT 990 (250 Ohm)', 'DT 1990 Pro', 'DT 1990 Pro (balanced earpads)',
    'DT 900 Pro X', 'DT 700 Pro X', 'TYGR 300 R', 'Custom One Pro',
    'T1 (3rd Gen)', 'T1', 'Amiron Home', 'Lagoon', 'DT 240 Pro', 'DTX 350p',
  ],
  'Audio-Technica': [
    'ATH-M40x', 'ATH-M50x', 'ATH-M50', 'ATH-M70x', 'ATH-M60x', 'ATH-AD700X',
    'ATH-AD900X', 'ATH-AD1000X', 'ATH-A900X', 'ATH-WS1100iS', 'ATH-AWKT',
    'ATH-R70x', 'ATH-ADX5000', 'ATH-LS400', 'ATH-CKR100IS', 'ATH-WS99BT',
    'ATH-EM7x', 'ATH-EW9',
  ],
  'AKG': [
    'K371', 'K361', 'K712 PRO', 'K701', 'K702', 'K7XX', 'K240 Studio',
    'K240 MK II', 'K240 Sextett', 'K501', 'K601', 'K267 Tiesto', 'Y50',
    'K361-BT', 'N60 NC Wireless', 'K280 Parabolic', 'K1000',
  ],
  'Hifiman': [
    'Sundara', 'Sundara (pre-2020 earpads)', 'HE400se', 'HE400i', 'HE-400i',
    'HE560', 'HE-5', 'Ananda', 'Ananda Stealth', 'Arya', 'Arya Stealth',
    'Arya Organic', 'Edition XS', 'Deva', 'Deva Pro', 'HE-X4', 'HE1000 V2',
    'HE-6', 'HE6se', 'Susvara', 'R9', 'RE400', 'RE2000', 'HE-4xx',
  ],
  'Focal': [
    'Elear', 'Elegia', 'Clear', 'Clear MG', 'Clear MG Professional', 'Stellia',
    'Radiance', 'Utopia', 'Utopia (2022)', 'Celestee', 'Listen Professional',
    'Scape', 'Utopia',
  ],
  'Audeze': [
    'LCD-2', 'LCD-2 Closed Back', 'LCD-X', 'LCD-XC', 'LCD-4', 'LCD-GX',
    'Mobius', 'Penrose', 'Maxwell', 'iSINE 10', 'iSINE 20', 'Euclid', 'Planar',
    'Sine', 'EL-8 Titanium',
  ],
  'FiiO': [
    'FT3', 'FT5', 'FH5s', 'FH7', 'FH9', 'FA9', 'FD5', 'FD7', 'FD11', 'FF5',
    'FF3', 'FW5', 'FHE Eclipse', 'EH3', 'JW-LA',
  ],
  'Grado': [
    'SR60e', 'SR80e', 'SR125e', 'SR225e', 'SR325e', 'SR325is', 'RS1x',
    'RS2x', 'GS3000x', 'PS500e', 'HF2', 'GS1000e', 'PS2000e',
  ],
  'Meze': [
    '99 Classics', '99 Neo', '99 Noir', 'Empyrean', 'Empyrean II', 'Elite',
    'Liric', 'Rai Penta', 'Rai Solo', 'Advar', '12 Classics V2', '109 Pro',
  ],
  'Fostex': [
    'TH-X00', 'TR-X00', 'TH-900', 'TH-610', 'TH-7', 'T50RP', 'T40RP',
    'T20RP', 'TM2',
  ],
  'Philips': [
    'SHP9600', 'SHP9500', 'Fidelio X2HR', 'Fidelio X3', 'SHP8000',
    'SHE3800', 'SHL5000', 'Fidelio M1',
  ],
  'Bowers & Wilkins': [
    'PX7', 'PX7 S2', 'PX5', 'PX8', 'Pi7 S2', 'Pi7', 'P9 Signature', 'PX',
  ],
  'Bang & Olufsen': [
    'Beoplay H9', 'Beoplay H95', 'Beoplay HX', 'Beoplay E8', 'Beoplay EX',
    'Beoplay H4', 'Beoplay H6',
  ],
  'Master & Dynamic': [
    'MW65', 'MW07', 'MW08', 'MW60', 'ME05', 'MH40',
  ],
  'Drop': [
    'Pandemon', 'Epos PC38X', '+ Meze 99 Noir', '+ Focal Elex',
  ],
  'AIAIAI': ['TMA-2 HD wireless', 'TMA-2 Studio', 'Tracks'],
  'SteelSeries': [
    'Arctis Nova Pro Wireless', 'Arctis 7', 'Arctis Pro GameDAC',
  ],
  'HyperX': ['Cloud Alpha', 'Cloud II', 'Cloud III', 'Cloud Orbit S'],
  'Razer': [
    'BlackShark V2', 'BlackShark V2 Pro', 'Kraken V3',
    'Kraken Tournament Edition', 'Nari Ultimate',
  ],
  // ---- In-ear: Chi-fi ----
  'Moondrop': [
    'Aria', 'Aria 2', 'Aria Snow Edition', 'BSP', 'Blessing', 'Blessing 2',
    'Blessing 2 Dusk', 'Blessing 3', 'Chu', 'Chu II', 'Kato', 'Quarks',
    'Quarks DSP', 'SSP', 'Starfield', 'Starfield 2', 'May', 'Nekocube',
    'Venus', 'Illumination', 'Voyager', 'Para', 'Joker', 'Discanza', 'Echo',
    'x Crinacle Blessing2 Dusk', 'x Crinacle Dusk', 'Dusk',
  ],
  'KZ': [
    'ZSN Pro', 'ZSN Pro X', 'ZS10 Pro', 'ZS10 Pro X', 'ZSX', 'ZEX', 'ZEX Pro',
    'ZEX CR', 'DQ6', 'DQ6S', 'EDA', 'EDA Balanced', 'Castor', 'Castor Bass',
    'Krila', 'AS06', 'ZS5', 'ZST', 'AN75', 'PR1', 'PR1 Pro', 'PR2', 'PR3',
    'x HBB PR2', 'x HBB PR3',
  ],
  'TRN': [
    'V90', 'V80', 'MT4', 'MT3', 'X7', 'TA2', 'Conch', 'Kirin',
    'Azure Dragon', 'BAX', 'ST5', 'Emerald', 'ORCA', 'BA5', 'MT1', 'MT1 Max',
  ],
  'BLON': ['BL-03', 'BL-05', 'BL-05 LT', 'BL-07', 'BL-Max', 'Mini', 'Fat Girl'],
  '7Hz': [
    'Salnotes Zero', 'Salnotes Zero 2', 'Dioko', 'Eternal', 'Timeless',
    'Timeless AE', 'Legato', 'Sonar', 'x Crinacle Zero 2',
  ],
  'Tangzu': [
    "Wan'er", "Wan'er S.G", 'Fudu', 'Wu', 'Zhu', 'Heyday', 'Yuan Li',
    'Shimin Li', 'Liyuan', 'Zetian Wu', 'Zetian Wu Bolt', 'Cadman', 'Wuyaz',
  ],
  'Simgot': ['EM6L', 'EA500', 'EA500LM', 'EW200', 'EM500', 'EM5H', 'EM3'],
  'Letshuoer': [
    'S12', 'S12 Pro', 'S15', 'EJ07', 'EJ07M', 'Galileo', 'Cadenza 4', 'DZ4',
    'Tape Pro', 'Tape', 'EQ21', 'EQ22',
  ],
  'QKZ': ['AK6', 'x HBB', 'QQ', 'SAS4', 'BB3', 'BB5', 'ZXD', 'JS1', 'JS3'],
  'CCA': [
    'CRA', 'CRA+', 'NRA', 'HS12', 'Rhapsody', 'Polaris', 'Hydro', 'Lyra',
    'CXS', 'CXM', 'Duo', 'Trio', 'Pianosarr',
  ],
  'Kiwi Ears': [
    'Quartet', 'Cadenza', 'Melody', 'Orchestra Lite', 'X-Crinkle', 'KE4',
    'Forteza', 'Orchestra', 'Singer',
  ],
  'EPZ': ['K5', 'Q1', 'Q1 Pro', 'Q5', 'G10', 'M100', 'M200', 'AC1', 'X1'],
  'DUNU': [
    'Titan S', 'Falcon Pro', 'Zen', 'SA6', 'SA6 Ultra', 'Glacier', 'Vulkan',
    'DK3001 Pro', 'DK4001', 'Luna', 'Falcon 2', 'Titan One', 'Mirai',
  ],
  'NiceHCK': [
    'DB1', 'DB2', 'DB3', 'Topuser', 'F1 Pro', 'B50', 'Original', 'Lofty',
    'N3', 'N7', 'Tracey',
  ],
  'Juzear': ['41T', '51T', 'Clear', 'Fire'],
  'AFUL': ['Performer 5', 'Performer 8', 'Performer 5+2', 'One', 'Explore'],
  'Artti': ['T10', 'R1', 'R2', 'T1'],
  'ISN': ['H40', 'Neo 5', 'Neo 1', 'Duo', 'H442', 'EST', 'B4'],
  'BGVP': [
    'DM6', 'DM7', 'DMG', 'VG4', 'D06', 'SCALE', 'NS9', 'ZERO', 'Melody 2',
  ],
  'Yanyin': ['Mahina', 'Canon 2', 'Aladdin', 'Moonlight', 'Canon'],
  'Celest': [
    'Pandemon', 'Guku', 'Ruyi', 'Wyvern', 'Phoenix', 'Devil', 'Vesper',
  ],
  'Binary': [
    'Acoustics x Dinang', 'Chopin', 'Xense', 'Natsuke', 'Kasen',
  ],
  'Oriveti': ['OD200', 'ODH', 'OD100', 'Traillii', 'Oding', 'Bronze'],
  'Hisenior': ['T2 U45', 'T4', 'Titan S', 'Okavango', 'Mega 5P', 'T4U', 'Odin'],
  'Tanchjim': [
    'Hana', 'Hana 2021', 'Oxygen', 'Darling', 'One', 'Zero', 'Echo', 'Origin',
    'Cora', 'Kara', 'ALTO', 'Bass',
  ],
  'Truthear': ['Hexa', 'Hola', 'Zero', 'Zero (blue)', 'Zero:Red', 'Nova'],
  'Thieaudio': [
    'Hype 4', 'Hype 10', 'V16 Divinity', 'Wraith', 'Legacy 2', 'Legacy 3',
    'Legacy 4', 'Legacy 9', 'Monarch Mk II', 'Monarch Mk III', 'Monarch',
    'Voyager 14', 'Clairvoyance', 'Excalibur', 'Elixir',
  ],
  'NF Audio': ['NM2', 'NM2+', 'NM2C', 'NA2+', 'NM3', 'RA10', 'R3'],
  // ---- In-ear: int'l audiophile ----
  'Campfire Audio': [
    'Andromeda', 'Andromeda 2020', 'Solaris', 'Solaris SE', 'Satsuma', 'Vega',
    'Dorado', 'Dorado 2020', 'Ara', 'Bonneville', 'Cascade', 'Supermoon',
  ],
  'Final Audio': [
    'E2000', 'E3000', 'E4000', 'E5000', 'A3000', 'A4000', 'A8000', 'Make 2',
    'VR3000', 'B3', 'A3', 'A4000', 'FI-DO',
  ],
  'Shure': [
    'SE215', 'SE215m+ SPE', 'SE315', 'SE425', 'SE535', 'SE846', 'Aonic 3',
    'Aonic 4', 'Aonic 5', 'Aonic 215',
  ],
  'Westone': [
    'UM Pro 30', 'W80', 'MACH 80', 'UM Pro X20', 'W40', 'Pro X50', 'B50',
  ],
  'Etymotic': [
    'ER2XR', 'ER2SE', 'ER3XR', 'ER3SE', 'ER4XR', 'ER4SR', 'ER4B', 'ER4PT',
    'EVO', 'ERX',
  ],
  '64 Audio': [
    'U12t', 'U18t', 'A12t', 'A18s', 'N8', 'Duo', 'Nio', 'Fourte',
    'Tia Fourte', 'U6t',
  ],
  'JH Audio': ['Roxanne', 'Layla', 'Athena', 'Billie Jean'],
  'JVC': [
    'HA-FW01', 'HA-FW02', 'HA-FW03', 'HA-FW10000', 'HA-FW1500', 'HA-FW1800',
    'HA-FD01', 'HA-FX1100', 'HA-FX1200',
  ],
  'Acoustune': [
    'HS1650', 'HS1670', 'HS1755', 'HS2000', 'HS1503', 'HS1300', 'HS1695',
  ],
  'Yamaha': ['EPH-100', 'EPH-200', 'MT8', 'HPH-MT7W', 'HPH-200', 'HPH-MT6'],
  'RHA': ['T20i', 'T10i', 'CL750', 'CL2 Planar', 'MA750'],
};

// Canonical band-type codes stored in the catalog. AutoEq's LSC/HSC collapse
// to LS/HS here so the app only ever sees the 8 standard codes.
const _typeNormalize = {'LSC': 'LS', 'HSC': 'HS'};

final _apiBase = 'api.github.com';
final _rawBase = 'raw.githubusercontent.com';

final _preampRe = RegExp(r'^Preamp:\s*([+-]?\d+(?:\.\d+)?)\s*dB', caseSensitive: false);
final _filterRe = RegExp(
  r'^Filter\s+\d+:\s+(ON|OFF)\s+([A-Za-z]+)\s+Fc\s+([+-]?\d+(?:\.\d+)?)\s+Hz'
  r'(?:\s+Gain\s+([+-]?\d+(?:\.\d+)?)\s+dB)?\s+Q\s+([+-]?\d+(?:\.\d+)?)',
  caseSensitive: false,
);
const _validTypes = {'PK', 'LS', 'HS', 'LP', 'HP', 'BP', 'NO', 'AP'};

Future<String> _httpGet(
  String host,
  String path, {
  Map<String, dynamic>? query,
}) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.https(host, path, query));
    req.headers.contentType = ContentType.json;
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} for $host$path');
    }
    return body;
  } finally {
    client.close(force: true);
  }
}

class _ModelPaths {
  final String type; // in-ear | earbud | over-ear
  final String campaign;
  final String path; // repo path to ParametricEQ.txt
  _ModelPaths(this.type, this.campaign, this.path);
}

/// folderName (exact) -> all (type, campaign, path) hits across campaigns.
final Map<String, List<_ModelPaths>> _index = {};

Future<void> _buildIndex() async {
  final campaignsBody = await _httpGet(
    _apiBase,
    '/repos/$_owner/$_repo/contents/results',
    query: {'ref': _branch},
  );
  final campaigns = (jsonDecode(campaignsBody) as List)
      .whereType<Map>()
      .where((m) => m['type'] == 'dir')
      .toList();

  for (final c in campaigns) {
    final name = c['name'] as String;
    final gitUrl = c['git_url'] as String;
    final sha = Uri.parse(gitUrl).pathSegments.last;
    stderr.writeln('  campaign: $name');
    final treeBody = await _httpGet(
      _apiBase,
      '/repos/$_owner/$_repo/git/trees/$sha',
      query: {'recursive': '1'},
    );
    final tree = jsonDecode(treeBody) as Map<String, dynamic>;
    final entries = (tree['tree'] as List).whereType<Map>();
    for (final e in entries) {
      final p = e['path'] as String?;
      if (p == null || !p.endsWith('ParametricEQ.txt')) continue;
      // path: <type>/<Model>/<Model> ParametricEQ.txt  (relative to campaign)
      final segs = p.split('/');
      if (segs.length < 3) continue;
      final type = segs[0]; // in-ear | earbud | over-ear
      final folder = segs[segs.length - 2];
      _index.putIfAbsent(folder, () => []).add(
        _ModelPaths(type, name, 'results/$name/$p'),
      );
    }
  }
}

String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

int _campaignRank(String campaign) {
  final i = _campaignPriority.indexOf(campaign);
  return i < 0 ? _campaignPriority.length : i;
}

_ModelPaths? _resolve(String brand, String model) {
  final b = _norm(brand);
  final m = _norm(model);
  if (m.isEmpty || b.isEmpty) return null;
  // Require brand prefix so short model strings ("A3") don't match unrelated
  // headphones ("TRN TA3"). Two tiers:
  //   1. exact:  norm(folder) == brand+model
  //   2. prefix+suffix: folder starts with brand AND ends with model
  //      (handles collab names like "Moondrop x Crinacle Dusk").
  final exact = b + m;
  final candidates = <MapEntry<String, _ModelPaths>>[];
  for (final entry in _index.entries) {
    final fn = _norm(entry.key);
    final tier = fn == exact
        ? 0
        : (fn.startsWith(b) && fn.endsWith(m) && fn.length >= exact.length
            ? 1
            : -1);
    if (tier < 0) continue;
    entry.value.sort(
      (a, b2) => _campaignRank(a.campaign).compareTo(_campaignRank(b2.campaign)),
    );
    candidates.add(MapEntry(entry.key, entry.value.first));
  }
  if (candidates.isEmpty) return null;
  // Prefer exact match; tie-break by shortest folder (base model, not a variant).
  candidates.sort((a, b2) {
    final aExact = _norm(a.key) == exact ? 0 : 1;
    final bExact = _norm(b2.key) == exact ? 0 : 1;
    final c = aExact.compareTo(bExact);
    return c != 0 ? c : a.key.length.compareTo(b2.key.length);
  });
  return candidates.first.value;
}

class _Band {
  final double f, g, q;
  final String t;
  _Band(this.f, this.g, this.q, this.t);
  List<dynamic> toJson() => [
        double.parse(f.toStringAsFixed(1)),
        double.parse(g.toStringAsFixed(2)),
        double.parse(q.toStringAsFixed(3)),
        t,
      ];
}

class _Entry {
  final String id, brand, model, type, source;
  final double preamp;
  final List<_Band> bands;
  _Entry(this.id, this.brand, this.model, this.type, this.source, this.preamp, this.bands);
  Map<String, dynamic> toJson() => {
        'id': id,
        'b': brand,
        'm': model,
        't': type,
        's': source,
        'pa': double.parse(preamp.toStringAsFixed(2)),
        'g': bands.map((b) => b.toJson()).toList(),
      };
}

String _slug(String s) => _norm(s);

_Entry? _parse({
  required String brand,
  required String model,
  required _ModelPaths mp,
  required String text,
}) {
  double preamp = 0;
  var sawPreamp = false;
  final bands = <_Band>[];
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final pm = _preampRe.firstMatch(line);
    if (pm != null) {
      preamp = double.parse(pm.group(1)!);
      sawPreamp = true;
      continue;
    }
    final fm = _filterRe.firstMatch(line);
    if (fm == null) continue;
    final on = fm.group(1)!.toUpperCase() == 'ON';
    if (!on) continue;
    var code = fm.group(2)!.toUpperCase();
    code = _typeNormalize[code] ?? code;
    if (!_validTypes.contains(code)) continue;
    final f = double.parse(fm.group(3)!);
    final g = fm.group(4) != null ? double.parse(fm.group(4)!) : 0.0;
    final q = double.parse(fm.group(5)!);
    bands.add(_Band(f, g, q, code));
  }
  if (!sawPreamp || bands.isEmpty) return null;
  final id = _slug('${brand}_$model');
  return _Entry(id, brand, model, mp.type, mp.campaign, preamp, bands);
}

Future<void> main() async {
  stderr.writeln('Building AutoEq index from per-campaign subtrees…');
  await _buildIndex();
  stderr.writeln('Index has ${_index.length} unique models.');

  final entries = <_Entry>[];
  final misses = <String>[];
  for (final item in _manifest.entries) {
    final brand = item.key;
    for (final model in item.value) {
      final mp = _resolve(brand, model);
      if (mp == null) {
        misses.add('$brand: $model');
        continue;
      }
      try {
        final text = await _safeRawGet(mp.path);
        final e = _parse(brand: brand, model: model, mp: mp, text: text);
        if (e == null) {
          misses.add('$brand: $model (parse failed)');
        } else {
          entries.add(e);
        }
      } catch (ex) {
        misses.add('$brand: $model ($ex)');
      }
    }
  }

  // Dedupe by id (keep first / best source).
  final seen = <String>{};
  entries.removeWhere((e) => !seen.add(e.id));
  entries.sort(
    (a, b) => a.brand.compareTo(b.brand) == 0
        ? a.model.toLowerCase().compareTo(b.model.toLowerCase())
        : a.brand.compareTo(b.brand),
  );
  final brands = (entries.map((e) => e.brand).toSet().toList()..sort());

  final catalogJson = jsonEncode(entries.map((e) => e.toJson()).toList());
  final brandsJson = jsonEncode(brands);
  await File('assets/autoeq/autoeq_catalog.json').writeAsString(catalogJson);
  await File('assets/autoeq/autoeq_brands.json').writeAsString(brandsJson);

  stderr.writeln('');
  stderr.writeln('Resolved: ${entries.length} models, ${brands.length} brands.');
  stderr.writeln('Catalog: ${catalogJson.length} bytes, '
      'brands: ${brandsJson.length} bytes.');
  if (misses.isNotEmpty) {
    stderr.writeln('Misses (${misses.length}):');
    for (final m in misses) {
      stderr.writeln('  - $m');
    }
  }
}

Future<String> _safeRawGet(String repoPath) async {
  // Uri.https percent-encodes the path itself, so pass it raw (unencoded).
  return _httpGet(_rawBase, '/$_owner/$_repo/$_branch/$repoPath');
}
