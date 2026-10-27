// Typed view of assets/content/content.<lang>.json.
// Both language files keep the same guide/block/item order: checklist progress
// is stored by position and shared across languages.

class Content {
  Content({required this.updated, required this.featured, required this.personas});

  final String updated;
  final List<String> featured;
  final List<Persona> personas;

  factory Content.fromJson(Map<String, dynamic> json) => Content(
        updated: json['updated'] as String,
        featured: List<String>.from(json['featured'] as List),
        personas: (json['personas'] as List).map((p) => Persona.fromJson(p as Map<String, dynamic>)).toList(),
      );

  Iterable<Guide> get allGuides => personas.expand((p) => p.guides);

  /// Resolves a step id (`guide:block:item`) to its guide and checklist item.
  ({Guide guide, Map<String, dynamic> item})? findStep(String stepId) {
    final parts = stepId.split(':');
    if (parts.length != 3) return null;
    final guide = findGuide(parts[0])?.guide;
    final bi = int.tryParse(parts[1]), ii = int.tryParse(parts[2]);
    if (guide == null || bi == null || ii == null || bi >= guide.blocks.length) return null;
    final block = guide.blocks[bi];
    if (!block.hasSteps || ii >= block.items.length) return null;
    return (guide: guide, item: block.items[ii]);
  }

  ({Persona persona, Guide guide})? findGuide(String id) {
    for (final persona in personas) {
      for (final guide in persona.guides) {
        if (guide.id == id) return (persona: persona, guide: guide);
      }
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
  });

  final String id;
  final String emoji;
  final String title;
  final String summary;
  final int minutes;
  final List<Block> blocks;

  factory Guide.fromJson(Map<String, dynamic> json) => Guide(
        id: json['id'] as String,
        emoji: json['emoji'] as String,
        title: json['title'] as String,
        summary: json['summary'] as String,
        minutes: json['minutes'] as int,
        blocks: (json['blocks'] as List).map((b) => Block.fromJson(b as Map<String, dynamic>)).toList(),
      );

  /// Stable ids for every checklist item: `guide:block:item`.
  /// Checklists are either plain `checklist` blocks or the steps inside an `app` section.
  List<String> get checklistIds => [
        for (var bi = 0; bi < blocks.length; bi++)
          if (blocks[bi].hasSteps)
            for (var ii = 0; ii < blocks[bi].items.length; ii++) '$id:$bi:$ii',
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
      for (final region in b.items)
        for (final country in region['countries'] as List? ?? const []) (country as Map)['name'] as String,
    ],
  ].join(' ').toLowerCase();
}

/// One content block. `type` is one of:
/// text, tip, warning, checklist, phrases, links, apps (slider), app (one app + its steps), visa_regions.
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
      );
}
