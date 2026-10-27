import 'package:flutter/material.dart';

/// Local-first demo catalogue used until the Supabase content sync is enabled.
/// The same records are seeded by [supabase/seed.sql] for parity.
abstract final class DemoContent {
  static const channels = <DemoChannel>[
    DemoChannel(
      id: 'addis-daily',
      name: 'Addis Daily',
      handle: '@addisdaily',
      description: 'City stories, culture and the best of Addis Ababa.',
      verified: true,
      followers: '128K',
      accent: Color(0xFF8C5A2B),
      posts: [
        DemoPost(
          title: 'Sunrise over Entoto',
          caption: 'The city wakes up early. #Addis',
          duration: '0:42',
          views: '24K',
        ),
        DemoPost(
          title: 'A walk through Merkato',
          caption: 'Colour, spice and the sound of a thousand deals.',
          duration: '1:18',
          views: '18K',
        ),
      ],
    ),
    DemoChannel(
      id: 'ethio-tech',
      name: 'Ethio Tech',
      handle: '@ethiotech',
      description: 'Product, startups and the builders shaping Ethiopia.',
      verified: true,
      followers: '64K',
      accent: Color(0xFF2F6B6B),
      posts: [
        DemoPost(
          title: 'Building for 2G first',
          caption: 'Why offline-first is not a compromise.',
          duration: '0:56',
          views: '11K',
        ),
        DemoPost(
          title: 'The next fintech wave',
          caption: 'Three founders on payments in the Horn.',
          duration: '2:04',
          views: '9.6K',
        ),
      ],
    ),
    DemoChannel(
      id: 'habesha-kitchen',
      name: 'Habesha Kitchen',
      handle: '@habeshakitchen',
      description: 'Recipes, coffee ceremonies and food from home.',
      verified: false,
      followers: '92K',
      accent: Color(0xFFA5472F),
      posts: [
        DemoPost(
          title: 'Injera, step by step',
          caption: 'The perfect rise, every time.',
          duration: '1:36',
          views: '31K',
        ),
      ],
    ),
  ];

  static const officialAccounts = <DemoOfficialAccount>[
    DemoOfficialAccount(
      id: 'ethio-telecom',
      name: 'Ethio Telecom',
      handle: 'ethiotelecom',
      category: 'Telecom',
      description: 'Balance, bundles, airtime and service updates.',
      verified: true,
      followers: '1.2M',
      articles: [
        DemoArticle(
          title: 'VoLTE is now available in Addis Ababa',
          summary: 'Clearer calls on supported devices, at no extra cost.',
          body: 'VoLTE carries voice calls over the 4G network. To enable it, '
              'update your phone software and switch on VoLTE in network '
              'settings. Calls between VoLTE users connect faster and use '
              'less battery.',
          date: 'Today',
          category: 'Service update',
        ),
        DemoArticle(
          title: 'Weekend data bundles',
          summary: 'A 2 GB weekend bundle for ETB 50.',
          body: 'The bundle is valid from Friday 18:00 to Monday 06:00. Dial '
              '*999# or use the Ethio Telecom mini program to activate it.',
          date: 'Yesterday',
          category: 'Offers',
        ),
      ],
    ),
    DemoOfficialAccount(
      id: 'cbe',
      name: 'Commercial Bank of Ethiopia',
      handle: 'cbe',
      category: 'Banking',
      description: 'Account alerts, branch updates and CBE Birr.',
      verified: true,
      followers: '880K',
      articles: [
        DemoArticle(
          title: 'Protect your PIN',
          summary: 'CBE will never ask for your PIN or OTP.',
          body:
              'Never share your CBE Birr PIN, OTP or card details with anyone. '
              'If you receive a suspicious call, hang up and contact the '
              'official support line. You can report suspicious activity in '
              'the EthioChat wallet help centre.',
          date: '2 days ago',
          category: 'Security',
        ),
      ],
    ),
    DemoOfficialAccount(
      id: 'fana',
      name: 'Fana Broadcasting',
      handle: 'fanabroadcasting',
      category: 'News',
      description: 'Breaking news and analysis in Amharic and English.',
      verified: true,
      followers: '540K',
      articles: [
        DemoArticle(
          title: 'Morning briefing: what to know today',
          summary: 'Markets, weather and the stories shaping the day.',
          body: 'A quick five-minute briefing from the Fana newsroom. Follow '
              'the account for alerts and open the article reader for the '
              'full story.',
          date: '1 hour ago',
          category: 'News',
        ),
      ],
    ),
  ];

  static const miniPrograms = <DemoMiniProgram>[
    DemoMiniProgram(
      id: 'bills',
      name: 'Bills',
      description: 'Pay electricity, water, TV and internet in one place.',
      icon: Icons.receipt_long_outlined,
      color: Color(0xFF2F6B6B),
    ),
    DemoMiniProgram(
      id: 'airtime',
      name: 'Airtime',
      description: 'Top up any Ethiopian mobile number instantly.',
      icon: Icons.phone_iphone_rounded,
      color: Color(0xFFB8860B),
    ),
    DemoMiniProgram(
      id: 'shop',
      name: 'Shop',
      description: 'Local merchants, delivered around Addis Ababa.',
      icon: Icons.storefront_outlined,
      color: Color(0xFF8C5A2B),
    ),
    DemoMiniProgram(
      id: 'ride',
      name: 'Ride',
      description: 'Book a ride across the city.',
      icon: Icons.local_taxi_outlined,
      color: Color(0xFF4A4034),
    ),
  ];

  static const nearby = <DemoPerson>[
    DemoPerson(
      name: 'Liya Tesfaye',
      distance: '250 m',
      bio: 'Coffee, books and city walks.',
      mutual: 4,
    ),
    DemoPerson(
      name: 'Dawit Bekele',
      distance: '600 m',
      bio: 'Startup builder in Bole.',
      mutual: 2,
    ),
    DemoPerson(
      name: 'Sara Mohammed',
      distance: '1.2 km',
      bio: 'Architect. Always sketching.',
      mutual: 7,
    ),
    DemoPerson(
      name: 'Yonas Girma',
      distance: '2.4 km',
      bio: 'Football and photography.',
      mutual: 1,
    ),
  ];

  static DemoChannel channel(String id) =>
      channels.firstWhere((c) => c.id == id, orElse: () => channels.first);

  static DemoOfficialAccount officialAccount(String id) => officialAccounts
      .firstWhere((a) => a.id == id, orElse: () => officialAccounts.first);

  static DemoMiniProgram miniProgram(String id) => miniPrograms
      .firstWhere((p) => p.id == id, orElse: () => miniPrograms.first);

  static const billers = <DemoBiller>[
    DemoBiller(name: 'Ethio Telecom', accountLabel: 'Phone number', fee: 0),
    DemoBiller(
        name: 'Ethiopian Electric', accountLabel: 'Meter number', fee: 200),
    DemoBiller(
        name: 'Addis Ababa Water', accountLabel: 'Customer number', fee: 0),
    DemoBiller(name: 'DStv Ethiopia', accountLabel: 'Smartcard number', fee: 0),
  ];
}

class DemoChannel {
  const DemoChannel({
    required this.id,
    required this.name,
    required this.handle,
    required this.description,
    required this.verified,
    required this.followers,
    required this.accent,
    required this.posts,
  });

  final String id, name, handle, description, followers;
  final bool verified;
  final Color accent;
  final List<DemoPost> posts;
}

class DemoPost {
  const DemoPost({
    required this.title,
    required this.caption,
    required this.duration,
    required this.views,
  });

  final String title, caption, duration, views;
}

class DemoOfficialAccount {
  const DemoOfficialAccount({
    required this.id,
    required this.name,
    required this.handle,
    required this.category,
    required this.description,
    required this.verified,
    required this.followers,
    required this.articles,
  });

  final String id, name, handle, category, description, followers;
  final bool verified;
  final List<DemoArticle> articles;
}

class DemoArticle {
  const DemoArticle({
    required this.title,
    required this.summary,
    required this.body,
    required this.date,
    required this.category,
  });

  final String title, summary, body, date, category;
}

class DemoMiniProgram {
  const DemoMiniProgram({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String id, name, description;
  final IconData icon;
  final Color color;
}

class DemoPerson {
  const DemoPerson({
    required this.name,
    required this.distance,
    required this.bio,
    required this.mutual,
  });

  final String name, distance, bio;
  final int mutual;
}

class DemoBiller {
  const DemoBiller({
    required this.name,
    required this.accountLabel,
    required this.fee,
  });

  final String name, accountLabel;
  final int fee;
}
