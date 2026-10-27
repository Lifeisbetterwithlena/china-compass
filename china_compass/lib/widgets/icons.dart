import 'package:flutter/material.dart';

/// Each topic gets its own icon and a calm accent color, so guides are easy
/// to tell apart at a glance. Colors are used as soft tints, never as alarms.
const _blue = Color(0xFF2F7DF6);
const _sky = Color(0xFF1AA0D8);
const _teal = Color(0xFF12A594);
const _green = Color(0xFF2E9E5B);
const _amber = Color(0xFFE09A00);
const _orange = Color(0xFFF07A2B);
const _coral = Color(0xFFE5566B);
const _pink = Color(0xFFD9549B);
const _violet = Color(0xFF7C5CE0);
const _indigo = Color(0xFF4C5FD5);

const _topics = <String, (IconData, Color)>{
  // paths
  'travel': (Icons.flight_takeoff_rounded, _blue),
  'study': (Icons.school_rounded, _violet),
  'life': (Icons.temple_buddhist_rounded, _orange),
  // travel
  'entry': (Icons.airplane_ticket_rounded, _blue),
  'internet': (Icons.wifi_rounded, _sky),
  'payments': (Icons.qr_code_2_rounded, _teal),
  'apps': (Icons.apps_rounded, _indigo),
  'getting-around': (Icons.train_rounded, _amber),
  'phrases': (Icons.translate_rounded, _pink),
  'safety': (Icons.health_and_safety_rounded, _coral),
  // study
  'programs': (Icons.manage_search_rounded, _blue),
  'scholarships': (Icons.workspace_premium_rounded, _amber),
  'apply': (Icons.edit_document, _teal),
  'student-visa': (Icons.badge_rounded, _indigo),
  'residence-permit': (Icons.contact_mail_rounded, _violet),
  'campus-life': (Icons.apartment_rounded, _green),
  // life
  'reality': (Icons.location_city_rounded, _sky),
  'etiquette': (Icons.handshake_rounded, _violet),
  'food': (Icons.ramen_dining_rounded, _orange),
  'holidays': (Icons.celebration_rounded, _coral),
  'daily-life': (Icons.shopping_bag_rounded, _green),
};

IconData iconFor(String id) => _topics[id]?.$1 ?? Icons.article_rounded;
Color colorFor(String id) => _topics[id]?.$2 ?? _indigo;

/// Rounded tile with a soft tint of the topic color.
class IconTile extends StatelessWidget {
  const IconTile(this.id, {super.key, this.size = 42});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = colorFor(id);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(iconFor(id), size: size * 0.5, color: color),
    );
  }
}
