// Typed view of assets/content/content.<lang>.json.
// All language files keep the same guides, blocks and items in the same order:
// checklist progress uses block ids (or positions) and is shared across languages.

class Content {
  Content({required this.updated, required this.featured, required this.personas, this.extras = const []});

  final String updated;
  final List<String> featured;
  final List<Persona> personas;

  /// Detail pages that aren't listed under a path, opened from "explore" cards.
  final List<Guide> extras;

  factory Content.fromJson(Map<String, dynamic> json) => Content(
        updated: json['updated'] as String,
        featured: List<String>.from(json['featured'] as List),
        personas: (json['personas'] as List).map((p) => Persona.fromJson(p as Map<String, dynamic>)).toList(),
        extras: [for (final g in json['extras'] as List? ?? const []) Guide.fromJson(g as Map<String, dynamic>)],
      );

  Iterable<Guide> get allGuides => [...personas.expand((p) => p.guides), ...extras];

  /// Resolves a step id (`guide:block:item`) to its guide and checklist item.
  ({Guide guide, Map<String, dynamic> item})? findStep(String stepId) {
    final parts = stepId.split(':');
    if (parts.length != 3) return null;
    final guide = findGuide(parts[0])?.guide;
    final ii = int.tryParse(parts[2]);
    if (guide == null || ii == null) return null;
    final byId = guide.blocks.indexWhere((b) => b.id == parts[1]);
    final bi = byId >= 0 ? byId : int.tryParse(parts[1]);
    if (bi == null || bi >= guide.blocks.length || guide.blocks[bi].id != null && byId < 0) return null;
    final block = guide.blocks[bi];
    if (!block.hasSteps || ii >= block.items.length) return null;
    return (guide: guide, item: block.items[ii]);
  }

  /// The guide with [id] and the path it belongs to (null for detail pages).
  /// An app's data (name, description, labels, link) by id, wherever it's listed.
  Map<String, dynamic>? findApp(String id) {
    for (final g in allGuides) {
      for (final b in g.blocks) {
        for (final a in [?b.app, ...b.items, for (final c in b.categories) ...c['apps'] as List]) {
          if (a is Map && a['id'] == id && a['url'] != null) return Map<String, dynamic>.from(a);
        }
      }
    }
    return null;
  }

  ({Persona? persona, Guide guide})? findGuide(String id) {
    for (final persona in personas) {
      for (final guide in persona.guides) {
        if (guide.id == id) return (persona: persona, guide: guide);
      }
    }
    for (final guide in extras) {
      if (guide.id == id) return (persona: null, guide: guide);
    }
    return null;
  }
}

class Persona {
  Persona({
    required this.id,
    required this.emoji,
    required this.title,
    required this.tagline,
    required this.intro,
    required this.guides,
  });

  final String id;
  final String emoji;
  final String title;
  final String tagline;
  final String intro;
  final List<Guide> guides;

  factory Persona.fromJson(Map<String, dynamic> json) => Persona(
        id: json['id'] as String,
        emoji: json['emoji'] as String,
        title: json['title'] as String,
        tagline: json['tagline'] as String,
        intro: json['intro'] as String,
        guides: (json['guides'] as List).map((g) => Guide.fromJson(g as Map<String, dynamic>)).toList(),
      );
}

class Guide {
  Guide({
    required this.id,
    required this.emoji,
    required this.title,
    required this.summary,
    required this.minutes,
    required this.blocks,
    this.appIcon,
  });

  final String id;
  final String emoji;
  final String title;
  final String summary;
  final int minutes;
  final List<Block> blocks;

  /// Detail pages about one app show that app's icon instead of a topic icon.
  final String? appIcon;

  factory Guide.fromJson(Map<String, dynamic> json) => Guide(
        id: json['id'] as String,
        emoji: json['emoji'] as String,
        title: json['title'] as String,
        summary: json['summary'] as String,
        minutes: json['minutes'] as int,
        blocks: (json['blocks'] as List).map((b) => Block.fromJson(b as Map<String, dynamic>)).toList(),
        appIcon: json['appIcon'] as String?,
      );

  /// Id of one checklist item: `guide:block:item`. The block part is the block's own
  /// `id` if it has one (stable when blocks move), otherwise its position.
  String stepId(int blockIndex, int itemIndex) => '$id:${blocks[blockIndex].id ?? blockIndex}:$itemIndex';

  /// Ids of every checklist item. Checklists are plain `checklist` blocks
  /// or the steps inside an `app` section.
  List<String> get checklistIds => [
        for (var bi = 0; bi < blocks.length; bi++)
          if (blocks[bi].hasSteps)
            for (var ii = 0; ii < blocks[bi].items.length; ii++) stepId(bi, ii),
      ];

  /// Lower-cased text of the whole guide, used by search.
  late final String searchText = [
    title,
    summary,
    for (final b in blocks) ...[
      b.heading ?? '',
      b.text ?? '',
      b.intro ?? '',
      ...b.paragraphs,
      ...b.bullets,
      for (final item in b.items) item.values.whereType<String>().join(' '),
      if (b.app != null) b.app!.values.whereType<String>().join(' '),
      for (final c in b.categories) ...[
        c['name'] as String,
        for (final a in c['apps'] as List) '${(a as Map)['name']} ${a['desc']}',
      ],
      for (final sec in b.sections) ...[
        sec['heading'] as String? ?? '',
        ...List<String>.from(sec['paragraphs'] as List? ?? const []),
        ...List<String>.from(sec['bullets'] as List? ?? const []),
        (sec['note'] as Map?)?['text'] as String? ?? '',
      ],
      for (final region in b.items)
        for (final country in region['countries'] as List? ?? const []) (country as Map)['name'] as String,
    ],
  ].join(' ').toLowerCase();
}

/// One content block. `type` is one of:
/// text, tip, warning, checklist, phrases, links, apps (slider), app (one app + its steps),
/// visa_regions, info (all of a guide's explanations in one card).
class Block {
  Block({
    required this.type,
    this.heading,
    this.text,
    this.paragraphs = const [],
    this.bullets = const [],
    this.items = const [],
    this.app,
    this.intro,
    this.source,
    this.id,
    this.popular = const [],
    this.sections = const [],
    this.categories = const [],
    this.appIds = const [],
    this.guide,
  });

  final String type;
  final String? heading;
  final String? text;
  final List<String> paragraphs;
  final List<String> bullets;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? app;

  /// visa_regions only: short note shown above the search, and the official source link.
  final String? intro;
  final String? source;

  /// Optional stable id, used in checklist progress keys instead of the position.
  final String? id;

  /// visa_regions only: country codes shown before searching.
  final List<String> popular;

  /// info only: sections with heading, paragraphs, bullets and an optional note
  /// (`{type: tip|warning, text}`).
  final List<Map<String, dynamic>> sections;

  /// app_directory only: `{id, name, apps: [...]}` per category.
  final List<Map<String, dynamic>> categories;

  /// related_apps only: app ids, and the guide that lists them.
  final List<String> appIds;
  final String? guide;

  bool get hasSteps => type == 'checklist' || type == 'app';

  factory Block.fromJson(Map<String, dynamic> json) => Block(
        type: json['type'] as String,
        heading: json['heading'] as String?,
        text: json['text'] as String?,
        paragraphs: List<String>.from(json['paragraphs'] as List? ?? const []),
        bullets: List<String>.from(json['bullets'] as List? ?? const []),
        items: List<Map<String, dynamic>>.from(json['items'] as List? ?? const []),
        app: json['app'] as Map<String, dynamic>?,
        intro: json['intro'] as String?,
        source: json['source'] as String?,
        id: json['id'] as String?,
        popular: List<String>.from(json['popular'] as List? ?? const []),
        sections: List<Map<String, dynamic>>.from(json['sections'] as List? ?? const []),
        categories: List<Map<String, dynamic>>.from(json['categories'] as List? ?? const []),
        appIds: json['type'] == 'related_apps' ? List<String>.from(json['apps'] as List) : const [],
        guide: json['guide'] as String?,
      );
}
