// NamNilam – Farmer-First Digital Land Acquisition & Compensation Portal
// Theme: SAMRIDDH ANNADATA, SAMRIDDH BHARAT
//
// HOW TO USE
//   1. Replace  lib/main.dart  with this file (no pubspec changes, no packages).
//   2. flutter run -d chrome        (or any Android / iOS device)
//
// 3D / DEPTH EFFECTS IN THIS FILE
//   - Hero: 6 parallax layers (sky, sun, 3 hill rows, perspective crop field)
//     that move with the mouse AND with scrolling.
//   - Tilt3D cards: real perspective tilt + moving light glare on hover.
//   - IsoMap: isometric tile map. Switch National / State / District officer
//     and see how the visible area (and raised tiles) change per role.
//   - Reveal: sections fade / slide in as you scroll.
//
// All data is demo data. Replace the repositories / IsoMap with the real API
// and a GeoJSON map (e.g. flutter_map) in the production build.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const NamNilamApp());

// ───────────────────────────── Theme & constants ─────────────────────────────

const Color kGreen = Color(0xFF2E7D32);
const Color kDeep = Color(0xFF14532D);
const Color kSaffron = Color(0xFFF57C00);
const Color kCream = Color(0xFFF6F3EA);
const Color kInk = Color(0xFF1F2A24);

const List<String> _navItems = ['Home', 'About', 'Search', 'Map', 'Roles', 'Contact'];

bool isWide(BuildContext c) => MediaQuery.sizeOf(c).width >= 900;

class Status {
  final String label;
  final Color color;
  const Status(this.label, this.color);
}

const List<Status> kStatuses = [
  Status('Not affected', Color(0xFF9E9E9E)),
  Status('Notified', Color(0xFFFBC02D)),
  Status('Under valuation', Color(0xFFF57C00)),
  Status('Award passed', Color(0xFF1E88E5)),
  Status('Compensation paid', Color(0xFF2E7D32)),
  Status('Disputed', Color(0xFFD32F2F)),
];

const List<String> _steps = [
  'Proposed',
  'Impact assessment',
  'Notified',
  'Objections',
  'Declared',
  'Valuation',
  'Award',
  'Paid',
];

// state → district → taluk → villages
const Map<String, Map<String, Map<String, List<String>>>> _geo = {
  'Tamil Nadu': {
    'Erode': {
      'Perundurai': ['Perundurai', 'Chennimalai'],
      'Bhavani': ['Bhavani', 'Kavindapadi'],
    },
    'Coimbatore': {
      'Sulur': ['Sulur', 'Kannampalayam'],
    },
  },
  'Karnataka': {
    'Mysuru': {
      'Hunsur': ['Hunsur', 'Bilikere'],
    },
  },
  'Maharashtra': {
    'Nashik': {
      'Igatpuri': ['Igatpuri', 'Ghoti'],
    },
  },
};

class Stat {
  final String label;
  final double value;
  final String prefix;
  final String suffix;
  final int decimals;
  const Stat(this.label, this.value, {this.prefix = '', this.suffix = '', this.decimals = 0});
}

const List<Stat> _stats = [
  Stat('Villages onboarded', 4820),
  Stat('Parcels tracked', 12.4, suffix: ' L', decimals: 1),
  Stat('Compensation disbursed', 9240, prefix: '₹ ', suffix: ' Cr'),
  Stat('Grievances resolved', 94, suffix: '%'),
];

String _fmt(double v, int d) {
  final parts = v.toStringAsFixed(d).split('.');
  final ip = parts[0];
  final buf = StringBuffer();
  for (int i = 0; i < ip.length; i++) {
    if (i > 0 && (ip.length - i) % 3 == 0) buf.write(',');
    buf.write(ip[i]);
  }
  return d > 0 ? '$buf.${parts[1]}' : buf.toString();
}

class LinkInfo {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? target;
  const LinkInfo(this.title, this.subtitle, this.icon, [this.target]);
}

const List<LinkInfo> _links = [
  LinkInfo('Land Search', 'Find a parcel by survey number', Icons.travel_explore, 'Search'),
  LinkInfo('Jurisdiction Map', 'Role-based status map', Icons.map_outlined, 'Map'),
  LinkInfo('Compensation Tracker', 'Valuation, award & payment status', Icons.account_balance_wallet_outlined),
  LinkInfo('Public Grievances', 'File and track objections', Icons.support_agent),
  LinkInfo('Projects & Notices', 'Gazette notifications and hearings', Icons.campaign_outlined),
  LinkInfo('FAQs', 'Rights, process and timelines', Icons.help_outline),
];

class RoleInfo {
  final String title;
  final IconData icon;
  final String sees;
  final String powers;
  const RoleInfo(this.title, this.icon, this.sees, this.powers);
}

const List<RoleInfo> _roles = [
  RoleInfo('National Admin', Icons.public, 'Entire India map – every state, district and parcel',
      'Set national policy and rates, manage state admins, full audit access'),
  RoleInfo('State Commissioner', Icons.account_balance, 'Only their own state map and data',
      'Approve projects, set state multipliers, monitor districts, escalate delays'),
  RoleInfo('District Collector', Icons.gavel, 'Only their own district map and data',
      'Issue notifications, hold hearings, approve valuation and final award'),
  RoleInfo('Taluk / Village Officer', Icons.badge_outlined, 'Parcels in their taluk or village',
      'Field verification, survey upload, owner checks, first-level data entry'),
  RoleInfo('Farmer / Landowner', Icons.agriculture, 'Only their own parcels, notices and payments',
      'Track status, view compensation breakdown, file objections and grievances'),
  RoleInfo('Auditor', Icons.fact_check_outlined, 'Read-only view of the full audit trail',
      'Verify every action with officer name and timestamp – cannot edit data'),
];

// ───────────────────────────────── App shell ─────────────────────────────────

class NamNilamApp extends StatelessWidget {
  const NamNilamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NamNilam – Farmer-First Land Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kGreen, primary: kGreen, secondary: kSaffron),
        scaffoldBackgroundColor: kCream,
      ),
      home: const HomePage(),
    );
  }
}

/// Shares the page scroll offset without rebuilding the whole tree.
class ScrollScope extends InheritedNotifier<ValueNotifier<double>> {
  const ScrollScope({super.key, required ValueNotifier<double> notifier, required super.child})
      : super(notifier: notifier);

  static ValueNotifier<double> read(BuildContext c) =>
      c.getInheritedWidgetOfExactType<ScrollScope>()!.notifier!;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _controller = ScrollController();
  final ValueNotifier<double> _offset = ValueNotifier<double>(0);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Map<String, GlobalKey> _keys = {for (final n in _navItems) n: GlobalKey()};

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => _offset.value = _controller.offset);
  }

  @override
  void dispose() {
    _controller.dispose();
    _offset.dispose();
    super.dispose();
  }

  void _go(String name) {
    if (name == 'Home') {
      _controller.animateTo(0, duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic);
      return;
    }
    final ctx = _keys[name]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic);
    }
  }

 
void _login() {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const RoleSelectionPage(),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    return ScrollScope(
      notifier: _offset,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: kCream,
        drawer: wide
            ? null
            : Drawer(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const DrawerHeader(
                      decoration: BoxDecoration(color: kDeep),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Text('NamNilam',
                            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    for (final n in _navItems)
                      ListTile(
                        title: Text(n),
                        onTap: () {
                          Navigator.pop(context);
                          _go(n);
                        },
                      ),
                  ],
                ),
              ),
        body: Stack(
          children: [
            SingleChildScrollView(
              controller: _controller,
              child: Column(
                children: [
                  HeroSection(
                    scroll: _offset,
                    wide: wide,
                    onSearch: () => _go('Search'),
                    onMap: () => _go('Map'),
                  ),
                  Transform.translate(offset: const Offset(0, -56), child: const StatsStrip()),
                  AboutSection(key: _keys['About']),
                  LinksSection(onGo: _go),
                  SearchSection(key: _keys['Search'], onMap: () => _go('Map')),
                  MapSection(key: _keys['Map']),
                  RolesSection(key: _keys['Roles']),
                  ContactSection(key: _keys['Contact']),
                  Footer(onNav: _go),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SiteHeader(
                scroll: _offset,
                wide: wide,
                onNav: _go,
                onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                onLogin: _login,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────── Header ────────────────────────────────────

class SiteHeader extends StatelessWidget {
  final ValueListenable<double> scroll;
  final bool wide;
  final ValueChanged<String> onNav;
  final VoidCallback onMenu;
  final VoidCallback onLogin;

  const SiteHeader({
    super.key,
    required this.scroll,
    required this.wide,
    required this.onNav,
    required this.onMenu,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: scroll,
      builder: (context, s, _) {
        final solid = s > 60;
        final fg = solid ? kInk : Colors.white;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 72,
          padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 12),
          decoration: BoxDecoration(
            color: solid ? Colors.white.withOpacity(.96) : Colors.transparent,
            boxShadow: solid
                ? [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 18, offset: const Offset(0, 4))]
                : const [],
          ),
          child: Row(
            children: [
              if (!wide) IconButton(icon: Icon(Icons.menu, color: fg), onPressed: onMenu),
              InkWell(
                onTap: () => onNav('Home'),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [kSaffron, Color(0xFFFFB74D)]),
                      ),
                      child: const Icon(Icons.eco, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('NamNilam',
                            style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: .3)),
                        if (wide)
                          Text('Farmer-first land acquisition',
                              style: TextStyle(color: fg.withOpacity(.75), fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (wide)
                for (final n in _navItems)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: TextButton(
                      onPressed: () => onNav(n),
                      style: TextButton.styleFrom(foregroundColor: fg),
                      child: Text(n, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onLogin,
                style: FilledButton.styleFrom(backgroundColor: kSaffron, foregroundColor: Colors.white),
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Login'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ───────────────────────────────── Hero (3D) ─────────────────────────────────

class HeroSection extends StatefulWidget {
  final ValueListenable<double> scroll;
  final bool wide;
  final VoidCallback onSearch;
  final VoidCallback onMap;

  const HeroSection({
    super.key,
    required this.scroll,
    required this.wide,
    required this.onSearch,
    required this.onMap,
  });

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> {
  final ValueNotifier<Offset> _pointer = ValueNotifier<Offset>(Offset.zero);

  @override
  void dispose() {
    _pointer.dispose();
    super.dispose();
  }

  Widget _content() {
    final wide = widget.wide;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.14),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(.35)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.agriculture, size: 16, color: Color(0xFFFFCC80)),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'SAMRIDDH ANNADATA, SAMRIDDH BHARAT',
                  style: TextStyle(color: Colors.white, fontSize: 11.5, letterSpacing: 1.4, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text.rich(
          TextSpan(
            children: const [
              TextSpan(text: 'Transparent land acquisition.\n'),
              TextSpan(text: 'Fair pay for every farmer.', style: TextStyle(color: Color(0xFFFFCC80))),
            ],
          ),
          style: TextStyle(
            color: Colors.white,
            fontSize: wide ? 46 : 32,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'Track every parcel — from notification to payment — in real time. '
            'From village to nation, one transparent platform.',
            style: TextStyle(color: Colors.white.withOpacity(.88), fontSize: wide ? 17 : 15, height: 1.5),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: widget.onSearch,
              style: FilledButton.styleFrom(
                backgroundColor: kSaffron,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              ),
              icon: const Icon(Icons.search),
              label: const Text('Find my land'),
            ),
            OutlinedButton.icon(
              onPressed: widget.onMap,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              ),
              icon: const Icon(Icons.map_outlined),
              label: const Text('View jurisdiction map'),
            ),
          ],
        ),
        SizedBox(height: wide ? 26 : 22),
        const WhatsNewCard(),
      ],
    );

    if (!wide) {
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 100, 20, 0),
        child: text,
      );
    }
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(56, 120, 56, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: text),
              const Expanded(
                flex: 5,
                child: Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Center(child: IsoMap(scope: 0, tile: 36, showPin: true)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.wide ? 720.0 : 840.0;
    const topExt = 260.0;
    const bottomExt = 300.0;
    final total = height + topExt + bottomExt;
    double f(double heroFrac) => (heroFrac * height + topExt) / total;

    return MouseRegion(
      onHover: (e) {
        final s = MediaQuery.sizeOf(context);
        _pointer.value = Offset((e.position.dx / s.width - .5) * 2, (e.position.dy / s.height - .5) * 2);
      },
      onExit: (_) => _pointer.value = Offset.zero,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: ClipRect(
          child: ColoredBox(
            color: kDeep,
            child: ValueListenableBuilder<Offset>(
              valueListenable: _pointer,
              builder: (context, p, _) => TweenAnimationBuilder<Offset>(
                tween: Tween<Offset>(begin: p, end: p),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (context, sp, _) => AnimatedBuilder(
                  animation: widget.scroll,
                  builder: (context, _) {
                    final y = widget.scroll.value.clamp(0.0, height).toDouble();

                    Widget layer({required double depth, required double par, required Widget child}) {
                      return Positioned(
                        left: -90,
                        right: -90,
                        top: -topExt,
                        bottom: -bottomExt,
                        child: Transform.translate(
                          offset: Offset(-sp.dx * depth, y * par - sp.dy * depth * .6),
                          child: child,
                        ),
                      );
                    }

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // sky
                        layer(
                          depth: 4,
                          par: .10,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: const [
                                  Color(0xFF123F35),
                                  Color(0xFF2E7D6B),
                                  Color(0xFFF6B25E),
                                  Color(0xFFF6B25E),
                                ],
                                stops: [0.0, f(.30), f(.62), 1.0],
                              ),
                            ),
                          ),
                        ),
                        // sun
                        layer(
                          depth: 7,
                          par: .12,
                          child: Stack(
                            children: [
                              Positioned(
                                right: 220,
                                top: topExt + height * .20,
                                child: Container(
                                  width: 150,
                                  height: 150,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [Color(0xFFFFF8E1), Color(0xFFFFD54F), Color(0x00FFB74D)],
                                      stops: [0.0, .45, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // hills (far → near)
                        layer(
                          depth: 10,
                          par: .16,
                          child: CustomPaint(
                            painter: HillsPainter(
                                color: const Color(0xFF7BB87E), base: f(.60), amp: 30, freq: 1.3, phase: .4),
                          ),
                        ),
                        layer(
                          depth: 22,
                          par: .26,
                          child: CustomPaint(
                            painter: HillsPainter(
                                color: const Color(0xFF3F9B4B), base: f(.70), amp: 36, freq: 1.0, phase: 1.8),
                          ),
                        ),
                        layer(
                          depth: 36,
                          par: .36,
                          child: CustomPaint(
                            painter: HillsPainter(
                                color: const Color(0xFF2E7D32), base: f(.79), amp: 26, freq: 1.6, phase: 3.1),
                          ),
                        ),
                        // perspective crop field
                        layer(
                          depth: 56,
                          par: .46,
                          child: CustomPaint(painter: FieldPainter(top: f(.86))),
                        ),
                        // foreground content
                        Positioned.fill(
                          child: Transform.translate(
                            offset: Offset(0, y * .22),
                            child: Opacity(
                              opacity: (1 - y / (height * .75)).clamp(0.0, 1.0).toDouble(),
                              child: _content(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HillsPainter extends CustomPainter {
  final Color color;
  final double base;
  final double amp;
  final double freq;
  final double phase;

  const HillsPainter({
    required this.color,
    required this.base,
    required this.amp,
    required this.freq,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 6) {
      final t = x / size.width * math.pi * 2 * freq;
      final y = size.height * base + math.sin(t + phase) * amp + math.sin(t * 2.7 + phase * 2) * amp * .35;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(HillsPainter old) => old.color != color || old.base != base;
}

class FieldPainter extends CustomPainter {
  final double top;
  const FieldPainter({required this.top});

  @override
  void paint(Canvas canvas, Size size) {
    final y0 = size.height * top;
    final rect = Rect.fromLTRB(0, y0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2E7D32), Color(0xFF14532D)],
        ).createShader(rect),
    );
    final cx = size.width / 2;
    final rowPaint = Paint()
      ..color = const Color(0x44A5D6A7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (int i = -16; i <= 16; i++) {
      canvas.drawLine(Offset(cx + i * 14.0, y0), Offset(cx + i * size.width / 9, size.height), rowPaint);
    }
    final bandPaint = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..strokeWidth = 1.5;
    for (int k = 1; k < 7; k++) {
      final t = math.pow(k / 7, 2).toDouble();
      final y = y0 + (size.height - y0) * t;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), bandPaint);
    }
  }

  @override
  bool shouldRepaint(FieldPainter old) => old.top != top;
}

// What's New (auto-scrolling ticker, like the reference portal)

class WhatsNewCard extends StatelessWidget {
  const WhatsNewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.28),
          border: Border.all(color: Colors.white.withOpacity(.28)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.campaign, color: Color(0xFFFFCC80), size: 20),
                SizedBox(width: 8),
                Text("What's New",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
            Divider(color: Colors.white24, height: 16),
            WhatsNewTicker(),
          ],
        ),
      ),
    );
  }
}

class WhatsNewTicker extends StatefulWidget {
  const WhatsNewTicker({super.key});

  @override
  State<WhatsNewTicker> createState() => _WhatsNewTickerState();
}

class _WhatsNewTickerState extends State<WhatsNewTicker> with SingleTickerProviderStateMixin {
  static const List<String> _items = [
    'Gazette notification published for the Perundurai–Chennimalai corridor (demo)',
    '₹ 42.6 Cr released to 318 farmers in Nashik district (demo)',
    'Objection window closes in 6 days for 3 villages in Hunsur (demo)',
    'New: SMS alerts in Tamil, Hindi and English',
  ];
  static const double _itemH = 44;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(seconds: _items.length * 5),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _row(String t) {
    return SizedBox(
      height: _itemH,
      child: Row(
        children: [
          const Icon(Icons.circle, size: 7, color: kSaffron),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _itemH * 2.6,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final dy = -_c.value * _items.length * _itemH;
            return OverflowBox(
              alignment: Alignment.topLeft,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [for (final t in _items) _row(t), for (final t in _items) _row(t)],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────── Stats strip ────────────────────────────────

class StatsStrip extends StatelessWidget {
  const StatsStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 40, offset: const Offset(0, 18))],
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                final cols = box.maxWidth > 700 ? 4 : 2;
                final w = box.maxWidth / cols;
                return Wrap(
                  children: [for (final s in _stats) SizedBox(width: w, child: StatTile(stat: s))],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final Stat stat;
  const StatTile({super.key, required this.stat});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: stat.value),
            duration: const Duration(milliseconds: 2000),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${stat.prefix}${_fmt(v, stat.decimals)}${stat.suffix}',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: kGreen),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(stat.label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 13)),
        ],
      ),
    );
  }
}

// ───────────────────────────── Reusable building blocks ─────────────────────

class Section extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Gradient? gradient;
  const Section({super.key, required this.child, this.color, this.gradient});

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: color, gradient: gradient),
      padding: EdgeInsets.fromLTRB(wide ? 40 : 20, 88, wide ? 40 : 20, 72),
      child: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1200), child: child),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final bool light;
  const SectionTitle({super.key, required this.eyebrow, required this.title, this.subtitle, this.light = false});

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    return Column(
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(color: kSaffron, letterSpacing: 2.4, fontWeight: FontWeight.w700, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: wide ? 36 : 26,
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: light ? Colors.white : kInk,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15.5, height: 1.5, color: light ? Colors.white70 : Colors.black54),
            ),
          ),
        ],
      ],
    );
  }
}

/// Fades / slides its child in the first time it scrolls into view.
class Reveal extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const Reveal({super.key, required this.child, this.delayMs = 0});

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> {
  late final ValueNotifier<double> _scroll;
  bool _triggered = false;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollScope.read(context);
    _scroll.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_triggered || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final h = MediaQuery.sizeOf(context).height;
    if (top < h * .92) {
      _triggered = true;
      _scroll.removeListener(_check);
      Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, .08),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Card that tilts in 3D toward the pointer, lifts up and shows a light glare.
class Tilt3D extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double maxTilt;
  final double radius;
  final Color color;

  const Tilt3D({
    super.key,
    required this.child,
    this.onTap,
    this.maxTilt = .16,
    this.radius = 20,
    this.color = Colors.white,
  });

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> {
  Offset _t = Offset.zero;
  bool _hover = false;

  void _update(PointerEvent e) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final l = box.globalToLocal(e.position);
    final s = box.size;
    setState(() {
      _hover = true;
      _t = Offset(((l.dx / s.width) - .5) * 2, ((l.dy / s.height) - .5) * 2);
    });
  }

  void _reset() => setState(() {
        _hover = false;
        _t = Offset.zero;
      });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.radius);
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: _update,
      onHover: _update,
      onExit: (_) => _reset(),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: TweenAnimationBuilder<Offset>(
          tween: Tween<Offset>(begin: _t, end: _t),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          builder: (context, t, _) {
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0011)
                ..rotateX(-t.dy * widget.maxTilt)
                ..rotateY(t.dx * widget.maxTilt)
                ..translate(0.0, _hover ? -8.0 : 0.0, 0.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: r,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(_hover ? .22 : .08),
                      blurRadius: _hover ? 38 : 16,
                      offset: Offset(-t.dx * 16, _hover ? 26 : 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: r,
                  child: Stack(
                    children: [
                      widget.child,
                      if (_hover)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment(t.dx, t.dy),
                                  radius: .9,
                                  colors: [Colors.white.withOpacity(.28), Colors.white.withOpacity(0)],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ────────────────────────────── Isometric map (3D) ──────────────────────────

/// Illustrative 8×8 parcel grid drawn as a tilted 3D plane.
/// scope 0 = National (everything), 1 = State (one quadrant), 2 = District (2×2 block).
class IsoMap extends StatefulWidget {
  final int scope;
  final double tile;
  final bool showPin;
  const IsoMap({super.key, this.scope = 0, this.tile = 38, this.showPin = false});

  @override
  State<IsoMap> createState() => _IsoMapState();
}

class _IsoMapState extends State<IsoMap> {
  static const int n = 8;
  Offset _t = Offset.zero;

  bool _inScope(int r, int c) {
    switch (widget.scope) {
      case 1:
        return r < 4 && c < 4;
      case 2:
        return r >= 1 && r <= 2 && c >= 1 && c <= 2;
      default:
        return true;
    }
  }

  Widget _tile(int r, int c) {
    final s = kStatuses[(r * 7 + c * 3 + r * c) % 6];
    final inS = _inScope(r, c);
    final raised = widget.scope != 0 && inS;
    final z = inS ? (widget.scope == 0 ? ((r + c) % 3) * 3.0 : 14.0) : 0.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.all(widget.tile * .04),
      transformAlignment: Alignment.center,
      transform: Matrix4.translationValues(0, 0, z),
      decoration: BoxDecoration(
        color: inS ? s.color : s.color.withOpacity(.14),
        borderRadius: BorderRadius.circular(4),
        boxShadow: raised ? [BoxShadow(color: s.color.withOpacity(.55), blurRadius: 10, offset: const Offset(0, 4))] : const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tile = widget.tile;
    final size = tile * n;
    return MouseRegion(
      onHover: (e) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        final l = box.globalToLocal(e.position);
        final s = box.size;
        setState(() => _t = Offset(((l.dx / s.width) - .5) * 2, ((l.dy / s.height) - .5) * 2));
      },
      onExit: (_) => setState(() => _t = Offset.zero),
      child: SizedBox(
        width: size * 1.55,
        height: size * 1.05,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: TweenAnimationBuilder<Offset>(
                tween: Tween<Offset>(begin: _t, end: _t),
                duration: const Duration(milliseconds: 200),
                builder: (context, t, _) => Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0008)
                    ..rotateX(.95 - t.dy * .12)
                    ..rotateZ(-.72 + t.dx * .12),
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (int r = 0; r < n; r++)
                          for (int c = 0; c < n; c++)
                            Positioned(left: c * tile, top: r * tile, width: tile, height: tile, child: _tile(r, c)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (widget.showPin)
              Positioned(
                right: 0,
                top: size * .08,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 16, offset: const Offset(0, 8))],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, color: Color(0xFFD32F2F), size: 22),
                      SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Survey 123/4A', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kInk)),
                          Text('Award passed · ₹ 18.4 L (demo)', style: TextStyle(fontSize: 11, color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────── About ────────────────────────────────────

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    const pillars = [
      ('Transparent by design', 'Every action is time-stamped with the officer’s name.', Icons.visibility_outlined),
      ('Real-time tracking', 'Parcel status updates from village to nation instantly.', Icons.bolt),
      ('Farmer-first', 'Simple language, regional languages and SMS alerts.', Icons.volunteer_activism_outlined),
    ];
    return Section(
      child: Column(
        children: [
          const Reveal(
            child: SectionTitle(
              eyebrow: 'About',
              title: 'One platform for the entire acquisition journey',
              subtitle: 'NamNilam brings impact assessment, notification, objections, valuation, award and payment '
                  'onto one real-time platform. Farmers see exactly where their land stands and what they will be paid. '
                  'Officers see only their own jurisdiction. Auditors see everything, read-only.',
            ),
          ),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (context, box) {
              final cols = wide ? 3 : 1;
              const gap = 22.0;
              final w = (box.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (int i = 0; i < pillars.length; i++)
                    SizedBox(
                      width: w,
                      child: Reveal(
                        delayMs: i * 120,
                        child: Tilt3D(
                          child: Padding(
                            padding: const EdgeInsets.all(26),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(pillars[i].$3, size: 34, color: kGreen),
                                const SizedBox(height: 14),
                                Text(pillars[i].$1,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kInk)),
                                const SizedBox(height: 8),
                                Text(pillars[i].$2, style: const TextStyle(color: Colors.black54, height: 1.45)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Important links ────────────────────────────

class LinksSection extends StatelessWidget {
  final ValueChanged<String> onGo;
  const LinksSection({super.key, required this.onGo});

  @override
  Widget build(BuildContext context) {
    return Section(
      color: Colors.white,
      child: Column(
        children: [
          const Reveal(child: SectionTitle(eyebrow: 'Our', title: 'Important Links')),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (context, box) {
              final cols = box.maxWidth >= 900 ? 3 : (box.maxWidth >= 560 ? 2 : 1);
              const gap = 22.0;
              final w = (box.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (int i = 0; i < _links.length; i++)
                    SizedBox(
                      width: w,
                      child: Reveal(
                        delayMs: (i % cols) * 120,
                        child: Tilt3D(
                          color: const Color(0xFFF7FAF6),
                          onTap: () {
                            final t = _links[i].target;
                            if (t != null) {
                              onGo(t);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${_links[i].title} – coming soon (demo)')),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [kGreen, Color(0xFF66BB6A)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Icon(_links[i].icon, color: Colors.white, size: 28),
                                ),
                                const SizedBox(height: 16),
                                Text(_links[i].title,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kInk)),
                                const SizedBox(height: 6),
                                Text(_links[i].subtitle, style: const TextStyle(color: Colors.black54)),
                                const SizedBox(height: 16),
                                const Align(
                                  alignment: Alignment.centerRight,
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: kSaffron,
                                    child: Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Survey-number search ─────────────────────────

class _Result {
  final String survey;
  final String path;
  final String owner;
  final String area;
  final String amount;
  final int step;
  const _Result(this.survey, this.path, this.owner, this.area, this.amount, this.step);
}

class SearchSection extends StatefulWidget {
  final VoidCallback onMap;
  const SearchSection({super.key, required this.onMap});

  @override
  State<SearchSection> createState() => _SearchSectionState();
}

class _SearchSectionState extends State<SearchSection> {
  String? _state;
  String? _district;
  String? _taluk;
  String? _village;
  final TextEditingController _survey = TextEditingController();
  _Result? _result;
  String? _error;

  List<String> get _districts => _state == null ? [] : _geo[_state]!.keys.toList();
  List<String> get _taluks => _district == null ? [] : _geo[_state]![_district]!.keys.toList();
  List<String> get _villages => _taluk == null ? [] : _geo[_state]![_district]![_taluk]!;

  @override
  void dispose() {
    _survey.dispose();
    super.dispose();
  }

  void _search() {
    final sn = _survey.text.trim();
    if (_village == null) {
      setState(() {
        _error = 'Please choose State → District → Taluk → Village first.';
        _result = null;
      });
      return;
    }
    if (!RegExp(r'^\d{1,4}(/\d{1,3}[A-Za-z]?)?$').hasMatch(sn)) {
      setState(() {
        _error = 'Enter a survey number like 123 or 123/4A.';
        _result = null;
      });
      return;
    }
    final h = (sn + _village!).hashCode.abs();
    const owners = ['R. Muthusamy', 'S. Lakshmi', 'K. Venkatesh', 'A. Fatima Begum', 'P. Gowda'];
    final area = 0.4 + (h % 300) / 100;
    setState(() {
      _error = null;
      _result = _Result(
        sn,
        '$_state › $_district › $_taluk › $_village',
        '${owners[h % owners.length]} (demo)',
        '${area.toStringAsFixed(2)} ha',
        '₹ ${(area * 45).toStringAsFixed(1)} L',
        h % 8,
      );
    });
  }

  Status _statusFor(int step) =>
      step <= 2 ? kStatuses[1] : (step <= 5 ? kStatuses[2] : (step == 6 ? kStatuses[3] : kStatuses[4]));

  Widget _drop(String label, String? value, List<String> items, ValueChanged<String?> onChanged, double w) {
    return SizedBox(
      width: w,
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            isDense: true,
            value: value,
            hint: Text(items.isEmpty ? '—' : 'Select', style: const TextStyle(color: Colors.black38)),
            items: [for (final i in items) DropdownMenuItem<String>(value: i, child: Text(i))],
            onChanged: items.isEmpty ? null : onChanged,
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(k, style: const TextStyle(color: Colors.black45, fontSize: 12)),
        const SizedBox(height: 2),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: kInk)),
      ],
    );
  }

  Widget _resultCard(_Result r) {
    final st = _statusFor(r.step);
    return Container(
      key: ValueKey('${r.survey}-${r.path}'),
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Survey No. ${r.survey}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kInk)),
                  const SizedBox(height: 4),
                  Text(r.path, style: const TextStyle(color: Colors.black54)),
                ],
              ),
              Chip(
                label: Text(st.label),
                backgroundColor: st.color.withOpacity(.15),
                side: BorderSide(color: st.color),
                labelStyle: TextStyle(color: st.color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Divider(height: 28),
          Wrap(
            spacing: 36,
            runSpacing: 14,
            children: [
              _kv('Owner', r.owner),
              _kv('Area', r.area),
              _kv('Estimated compensation', r.amount),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < _steps.length; i++)
                Chip(
                  avatar: Icon(
                    i <= r.step ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: i <= r.step ? kGreen : Colors.grey,
                  ),
                  label: Text(_steps[i]),
                  backgroundColor: i <= r.step ? kGreen.withOpacity(.08) : Colors.grey.withOpacity(.08),
                  side: BorderSide.none,
                ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: widget.onMap,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Locate on jurisdiction map'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Section(
      child: Column(
        children: [
          const Reveal(
            child: SectionTitle(
              eyebrow: 'Land search',
              title: 'Find your land by survey number',
              subtitle: 'Choose the location step by step, then enter the exact survey number '
                  '(for example 123 or 123/4A) to see the parcel status.',
            ),
          ),
          const SizedBox(height: 36),
          Reveal(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2E6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  final cols = box.maxWidth >= 900 ? 5 : (box.maxWidth >= 560 ? 2 : 1);
                  const gap = 14.0;
                  final w = (box.maxWidth - gap * (cols - 1)) / cols;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: gap,
                        runSpacing: 18,
                        children: [
                          _drop('State', _state, _geo.keys.toList(), (v) {
                            setState(() {
                              _state = v;
                              _district = null;
                              _taluk = null;
                              _village = null;
                            });
                          }, w),
                          _drop('District', _district, _districts, (v) {
                            setState(() {
                              _district = v;
                              _taluk = null;
                              _village = null;
                            });
                          }, w),
                          _drop('Taluk', _taluk, _taluks, (v) {
                            setState(() {
                              _taluk = v;
                              _village = null;
                            });
                          }, w),
                          _drop('Village', _village, _villages, (v) => setState(() => _village = v), w),
                          SizedBox(
                            width: w,
                            child: TextField(
                              controller: _survey,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _search(),
                              decoration: InputDecoration(
                                labelText: 'Survey number',
                                hintText: 'e.g. 123/4A',
                                floatingLabelBehavior: FloatingLabelBehavior.always,
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: _search,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                            ),
                            icon: const Icon(Icons.search),
                            label: const Text('Search land record'),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _state = _district = _taluk = _village = null;
                              _survey.clear();
                              _result = null;
                              _error = null;
                            }),
                            child: const Text('Reset'),
                          ),
                          if (_error != null)
                            Text(_error!, style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _result == null ? const SizedBox.shrink(key: ValueKey('none')) : _resultCard(_result!),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Role-scoped map section ──────────────────────

class MapSection extends StatefulWidget {
  const MapSection({super.key});

  @override
  State<MapSection> createState() => _MapSectionState();
}

class _MapSectionState extends State<MapSection> {
  int _scope = 0;

  static const List<String> _labels = ['National officer', 'State officer', 'District officer'];
  static const List<String> _visible = [
    'All India · every state and district',
    'Tamil Nadu only',
    'Erode district only',
  ];
  static const List<String> _desc = [
    'Sees the entire India map and can compare every state. Can drill down State → District → Taluk → Village → Parcel.',
    'The map is locked to one state. Other states are invisible and their data is never sent to the device.',
    'The map is locked to one district. The officer can act only on parcels inside this district.',
  ];

  @override
  Widget build(BuildContext context) {
    return Section(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [kDeep, Color(0xFF0B3321)],
      ),
      child: Column(
        children: [
          const Reveal(
            child: SectionTitle(
              eyebrow: 'Jurisdiction map',
              title: 'Every officer sees only their own area',
              subtitle: 'Switch the role to see how the visible map changes. The server sends only the data '
                  'each role is allowed to see.',
              light: true,
            ),
          ),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 900;
              final mapW = wide ? box.maxWidth * .5 : box.maxWidth;
              final tile = math.min(46.0, mapW / 1.6 / 8);

              final info = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (int i = 0; i < _labels.length; i++)
                        ChoiceChip(
                          label: Text(_labels[i]),
                          selected: _scope == i,
                          showCheckmark: false,
                          selectedColor: kSaffron,
                          backgroundColor: Colors.white.withOpacity(.10),
                          side: BorderSide(color: Colors.white.withOpacity(.3)),
                          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          onSelected: (_) => setState(() => _scope = i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      key: ValueKey(_scope),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: kSaffron.withOpacity(.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kSaffron),
                          ),
                          child: Text('Visible: ${_visible[_scope]}',
                              style: const TextStyle(color: Color(0xFFFFCC80), fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 14),
                        Text(_desc[_scope], style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.55)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Wrap(
                    spacing: 18,
                    runSpacing: 10,
                    children: [
                      for (final s in kStatuses)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3)),
                            ),
                            const SizedBox(width: 8),
                            Text(s.label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Illustrative grid – replace with GeoJSON boundaries (e.g. flutter_map) in the production app.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              );

              final map = Center(child: IsoMap(key: ValueKey(tile), scope: _scope, tile: tile));

              return Reveal(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: info),
                          const SizedBox(width: 24),
                          Expanded(child: map),
                        ],
                      )
                    : Column(children: [info, const SizedBox(height: 28), map]),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────── Roles ─────────────────────────────────────

class RolesSection extends StatelessWidget {
  const RolesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Section(
      child: Column(
        children: [
          const Reveal(
            child: SectionTitle(
              eyebrow: 'Roles & powers',
              title: 'Right access for every level',
              subtitle: 'National → State → District → Taluk → Village. Every action is logged for the auditor.',
            ),
          ),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (context, box) {
              final cols = box.maxWidth >= 900 ? 3 : (box.maxWidth >= 560 ? 2 : 1);
              const gap = 22.0;
              final w = (box.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (int i = 0; i < _roles.length; i++)
                    SizedBox(
                      width: w,
                      child: Reveal(
                        delayMs: (i % cols) * 120,
                        child: Tilt3D(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: kGreen.withOpacity(.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(_roles[i].icon, color: kGreen),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(_roles[i].title,
                                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kInk)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text('SEES',
                                    style: TextStyle(fontSize: 11, letterSpacing: 1.6, color: kSaffron, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(_roles[i].sees, style: const TextStyle(color: Colors.black87, height: 1.4)),
                                const SizedBox(height: 12),
                                const Text('CAN',
                                    style: TextStyle(fontSize: 11, letterSpacing: 1.6, color: kSaffron, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(_roles[i].powers, style: const TextStyle(color: Colors.black87, height: 1.4)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Contact & footer ───────────────────────────

class ContactSection extends StatelessWidget {
  const ContactSection({super.key});

  Widget _field(String label, {int lines = 1}) {
    return TextField(
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _info(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: kGreen.withOpacity(.12), child: Icon(icon, color: kGreen, size: 20)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.black45, fontSize: 12)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: kInk)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final info = Tilt3D(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            _info(Icons.location_on_outlined, 'Address', 'Department of Land Resources (demo address)'),
            _info(Icons.phone_outlined, 'Call us now', '+91 00000 00000'),
            _info(Icons.mail_outline, 'Mail us now', 'support@namnilam.example'),
          ],
        ),
      ),
    );
    final form = Column(
      children: [
        Row(
          children: [
            Expanded(child: _field('Your name')),
            const SizedBox(width: 12),
            Expanded(child: _field('Your email')),
          ],
        ),
        const SizedBox(height: 12),
        _field('Message', lines: 4),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: Builder(
            builder: (context) => FilledButton.icon(
              onPressed: () => ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Message sent (demo)'))),
              style: FilledButton.styleFrom(
                backgroundColor: kSaffron,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
              ),
              icon: const Icon(Icons.send),
              label: const Text('Send message'),
            ),
          ),
        ),
      ],
    );
    return Section(
      color: Colors.white,
      child: Column(
        children: [
          const Reveal(
            child: SectionTitle(eyebrow: 'Contact us', title: 'Have a query? Get in touch'),
          ),
          const SizedBox(height: 36),
          Reveal(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: info),
                      const SizedBox(width: 28),
                      Expanded(flex: 6, child: form),
                    ],
                  )
                : Column(children: [info, const SizedBox(height: 22), form]),
          ),
        ],
      ),
    );
  }
}

class Footer extends StatelessWidget {
  final ValueChanged<String> onNav;
  const Footer({super.key, required this.onNav});

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    return Container(
      width: double.infinity,
      color: const Color(0xFF0B2216),
      padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 20, vertical: 44),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 64,
                runSpacing: 28,
                children: [
                  SizedBox(
                    width: 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.eco, color: kSaffron),
                            SizedBox(width: 8),
                            Text('NamNilam',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'A farmer-first digital platform for transparent land acquisition and fair compensation.',
                          style: TextStyle(color: Colors.white.withOpacity(.6), height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quick links', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      for (final n in _navItems)
                        InkWell(
                          onTap: () => onNav(n),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(n, style: TextStyle(color: Colors.white.withOpacity(.7))),
                          ),
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Hierarchy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      for (final n in ['National', 'State', 'District', 'Taluk', 'Village / City'])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('› $n', style: TextStyle(color: Colors.white.withOpacity(.7))),
                        ),
                    ],
                  ),
                ],
              ),
              Divider(color: Colors.white.withOpacity(.12), height: 44),
              Text(
                '© 2026 NamNilam · Prototype UI – all figures and records shown are demo data',
                style: TextStyle(color: Colors.white.withOpacity(.5), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════
//  FARMER LOGIN  (guest → mobile number + captcha → OTP → my land details)
//
//  DEMO ONLY: captcha and OTP are generated on the device so the flow can be
//  shown without a backend. In production:
//    • captcha is created and verified on the SERVER (never on the device)
//    • server sends the OTP by SMS gateway, stores only a hash, expires it in
//      ~5 minutes, rate-limits per number / IP, and locks after 3 wrong tries
//    • server returns a short-lived token; the land API returns only parcels
//      linked to that verified mobile number (that is what keeps data private)
// ═══════════════════════════════════════════════════════════════════════════

Status statusForStep(int step) =>
    step <= 2 ? kStatuses[1] : (step <= 5 ? kStatuses[2] : (step == 6 ? kStatuses[3] : kStatuses[4]));

String maskMobile(String m) =>
    m.length == 10 ? '+91 ${m.substring(0, 2)}••••••${m.substring(8)}' : m;

String _newCaptcha() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I confusion
  final r = math.Random.secure();
  return List.generate(5, (_) => chars[r.nextInt(chars.length)]).join();
}

class LandParcel {
  final String survey;
  final String village;
  final String taluk;
  final String district;
  final String state;
  final double area;
  final int step; // 0..7 → index into _steps
  final bool disputed;
  final String project;
  final double amountLakh;

  const LandParcel({
    required this.survey,
    required this.village,
    required this.taluk,
    required this.district,
    required this.state,
    required this.area,
    required this.step,
    required this.disputed,
    required this.project,
    required this.amountLakh,
  });

  bool get paid => step == 7 && !disputed;
  bool get inProcess => step < 7 && !disputed;
  Status get status => disputed ? kStatuses[5] : statusForStep(step);
}

/// Demo data: the same mobile number always gives the same lands.
/// Replace with: GET /farmer/lands  (token of the OTP-verified mobile).
List<LandParcel> mockLandsFor(String mobile) {
  final rnd = math.Random(int.tryParse(mobile) ?? mobile.hashCode);
  final places = <List<String>>[];
  _geo.forEach((s, ds) => ds.forEach((d, ts) => ts.forEach((t, vs) {
        for (final v in vs) {
          places.add([s, d, t, v]);
        }
      })));
  const projects = [
    'Highway widening (demo)',
    'Irrigation canal (demo)',
    'Rail corridor (demo)',
    'Industrial park (demo)',
  ];
  final count = 2 + rnd.nextInt(4);
  return List.generate(count, (i) {
    final p = places[rnd.nextInt(places.length)];
    final area = 0.3 + rnd.nextInt(280) / 100;
    return LandParcel(
      survey: '${100 + rnd.nextInt(800)}/${1 + rnd.nextInt(9)}${String.fromCharCode(65 + rnd.nextInt(4))}',
      state: p[0],
      district: p[1],
      taluk: p[2],
      village: p[3],
      area: area,
      step: rnd.nextInt(8),
      disputed: rnd.nextInt(9) == 0,
      project: projects[rnd.nextInt(projects.length)],
      amountLakh: area * 45,
    );
  });
}

Widget _kvBlock(String k, String v) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(k, style: const TextStyle(color: Colors.black45, fontSize: 12)),
      const SizedBox(height: 2),
      Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kInk)),
    ],
  );
}

// ───────────────────────────── Captcha image ────────────────────────────────

class CaptchaPainter extends CustomPainter {
  final String text;
  const CaptchaPainter(this.text);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(text.hashCode);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFFE8F5E9), Color(0xFFFFF3E0)]).createShader(rect),
    );
    for (int i = 0; i < 7; i++) {
      canvas.drawLine(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        Paint()
          ..color = Color.fromARGB(110, rnd.nextInt(180), rnd.nextInt(180), rnd.nextInt(180))
          ..strokeWidth = 1.5,
      );
    }
    for (int i = 0; i < 34; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        1.2,
        Paint()..color = Colors.black.withOpacity(.25),
      );
    }
    double x = 14;
    for (int i = 0; i < text.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: text[i],
          style: TextStyle(
            fontSize: 26.0 + rnd.nextInt(8),
            fontWeight: FontWeight.w800,
            fontStyle: rnd.nextBool() ? FontStyle.italic : FontStyle.normal,
            color: Color.fromARGB(255, rnd.nextInt(120), rnd.nextInt(120), rnd.nextInt(120)),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(x, size.height / 2 + (rnd.nextDouble() - .5) * 8);
      canvas.rotate((rnd.nextDouble() - .5) * .6);
      tp.paint(canvas, Offset(0, -tp.height / 2));
      canvas.restore();
      x += tp.width + 8;
    }
    final wave = Path()..moveTo(0, size.height * .55);
    for (double px = 0; px <= size.width; px += 6) {
      wave.lineTo(px, size.height * .55 + math.sin(px / 9) * 5);
    }
    canvas.drawPath(
      wave,
      Paint()
        ..color = Colors.black.withOpacity(.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(CaptchaPainter old) => old.text != text;
}

// ────────────────────────────── Login page ──────────────────────────────────

enum _LoginStep { mobile, otp }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _mobile = TextEditingController();
  final TextEditingController _captchaCtl = TextEditingController();
  final TextEditingController _otpCtl = TextEditingController();

  _LoginStep _step = _LoginStep.mobile;
  String _captcha = _newCaptcha();
  String _otp = '';
  String? _error;
  bool _busy = false;
  int _attempts = 0;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _mobile.dispose();
    _captchaCtl.dispose();
    _otpCtl.dispose();
    super.dispose();
  }

  void _refreshCaptcha() {
    setState(() {
      _captcha = _newCaptcha();
      _captchaCtl.clear();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
        if (_secondsLeft == 0) t.cancel();
      });
    });
  }

  String _generateOtp() {
    final r = math.Random.secure();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  Future<void> _sendOtp() async {
    final m = _mobile.text.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(m)) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }
    if (_captchaCtl.text.trim().toUpperCase() != _captcha) {
      _refreshCaptcha();
      setState(() => _error = 'Captcha did not match. Please try the new one.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700)); // simulates the SMS gateway call
    if (!mounted) return;
    setState(() {
      _busy = false;
      _otp = _generateOtp();
      _step = _LoginStep.otp;
      _attempts = 0;
      _otpCtl.clear();
    });
    _startTimer();
  }

  void _verify() {
    final code = _otpCtl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP.');
      return;
    }
    if (code == _otp) {
      _timer?.cancel();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => FarmerDashboard(mobile: _mobile.text.trim())),
      );
      return;
    }
    _attempts++;
    if (_attempts >= 3) {
      _timer?.cancel();
      setState(() {
        _step = _LoginStep.mobile;
        _error = 'Too many wrong attempts. Please start again.';
        _captcha = _newCaptcha();
        _captchaCtl.clear();
        _otpCtl.clear();
      });
      return;
    }
    setState(() {
      _error = 'Wrong OTP. ${3 - _attempts} attempt(s) left.';
      _otpCtl.clear();
    });
  }

  void _resend() {
    setState(() {
      _otp = _generateOtp();
      _attempts = 0;
      _error = null;
      _otpCtl.clear();
    });
    _startTimer();
  }

  Widget _dot(int n, String label, bool active, bool done) {
    final color = (active || done) ? kGreen : Colors.black26;
    return Column(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: (active || done) ? kGreen : Colors.black12,
          child: done
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text('$n', style: TextStyle(color: active ? Colors.white : Colors.black45, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _line(bool done) => Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.only(bottom: 18, left: 6, right: 6),
          color: done ? kGreen : Colors.black12,
        ),
      );

  Widget _mobileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _mobile,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          decoration: InputDecoration(
            labelText: 'Mobile number',
            prefixText: '+91  ',
            prefixIcon: const Icon(Icons.phone_android),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 18),
        const Text('Type the characters shown', style: TextStyle(color: Colors.black54, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(width: 170, height: 56, child: CustomPaint(painter: CaptchaPainter(_captcha))),
            ),
            IconButton(
              tooltip: 'New captcha',
              onPressed: _refreshCaptcha,
              icon: const Icon(Icons.refresh, color: kGreen),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _captchaCtl,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [LengthLimitingTextInputFormatter(5)],
          onSubmitted: (_) => _sendOtp(),
          decoration: InputDecoration(
            labelText: 'Captcha',
            prefixIcon: const Icon(Icons.shield_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : _sendOtp,
            style: FilledButton.styleFrom(
              backgroundColor: kSaffron,
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sms_outlined),
            label: Text(_busy ? 'Sending OTP…' : 'Send OTP'),
          ),
        ),
      ],
    );
  }

  Widget _otpStep() {
    final m = _mobile.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter the 6-digit OTP sent to ${maskMobile(m)}',
            style: const TextStyle(color: Colors.black87, height: 1.4)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFCC80)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: kSaffron),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Demo mode – your OTP is $_otp. In the real app it arrives by SMS.',
                  style: const TextStyle(fontSize: 12.5, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _otpCtl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          onSubmitted: (_) => _verify(),
          style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••••',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _verify,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('Verify & view my land'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                _timer?.cancel();
                setState(() {
                  _step = _LoginStep.mobile;
                  _error = null;
                  _captcha = _newCaptcha();
                  _captchaCtl.clear();
                });
              },
              child: const Text('Change number'),
            ),
            TextButton(
              onPressed: _secondsLeft == 0 ? _resend : null,
              child: Text(_secondsLeft == 0 ? 'Resend OTP' : 'Resend in 0:${_secondsLeft.toString().padLeft(2, '0')}'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final onOtp = _step == _LoginStep.otp;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kDeep, kGreen],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to home'),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(.3), blurRadius: 40, offset: const Offset(0, 20)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(colors: [kSaffron, Color(0xFFFFB74D)]),
                                ),
                                child: const Icon(Icons.agriculture, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text('Farmer Login',
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kInk)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Guest access – verify your registered mobile number to see only your own land records.',
                            style: TextStyle(color: Colors.black54, height: 1.4),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _dot(1, 'Mobile', !onOtp, onOtp),
                              _line(onOtp),
                              _dot(2, 'OTP', onOtp, false),
                              _line(false),
                              _dot(3, 'My land', false, false),
                            ],
                          ),
                          const SizedBox(height: 22),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: KeyedSubtree(
                              key: ValueKey(_step),
                              child: onOtp ? _otpStep() : _mobileStep(),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline, size: 18, color: Color(0xFFD32F2F)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(_error!,
                                      style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 18),
                          const Divider(),
                          const SizedBox(height: 6),
                          const Row(
                            children: [
                              Icon(Icons.lock_outline, size: 16, color: Colors.black45),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Your land details are shown only after OTP verification and only for your number.',
                                  style: TextStyle(fontSize: 12, color: Colors.black45),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Farmer dashboard ─────────────────────────────

class FarmerDashboard extends StatefulWidget {
  final String mobile;
  const FarmerDashboard({super.key, required this.mobile});

  @override
  State<FarmerDashboard> createState() => _FarmerDashboardState();
}

class _FarmerDashboardState extends State<FarmerDashboard> {
  late final List<LandParcel> _lands = mockLandsFor(widget.mobile);
  int _filter = 0;
  static const List<String> _filters = ['All', 'In process', 'Paid', 'Disputed'];

  List<LandParcel> get _shown {
    switch (_filter) {
      case 1:
        return _lands.where((l) => l.inProcess).toList();
      case 2:
        return _lands.where((l) => l.paid).toList();
      case 3:
        return _lands.where((l) => l.disputed).toList();
      default:
        return _lands;
    }
  }

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Tilt3D(
      maxTilt: .08,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(.14), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
                  Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _landCard(LandParcel l) {
    final st = l.status;
    final next = l.disputed
        ? 'Grievance under review'
        : (l.step >= 7 ? 'Compensation credited' : _steps[l.step + 1]);
    return Tilt3D(
      maxTilt: .04,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Survey No. ${l.survey}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kInk)),
                    const SizedBox(height: 2),
                    Text('${l.village}, ${l.taluk}, ${l.district}, ${l.state}',
                        style: const TextStyle(color: Colors.black54)),
                  ],
                ),
                Chip(
                  label: Text(st.label),
                  backgroundColor: st.color.withOpacity(.15),
                  side: BorderSide(color: st.color),
                  labelStyle: TextStyle(color: st.color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Project: ${l.project}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (l.step + 1) / _steps.length,
                minHeight: 8,
                color: st.color,
                backgroundColor: Colors.black12,
              ),
            ),
            const SizedBox(height: 6),
            Text('Stage ${l.step + 1} of ${_steps.length} · ${_steps[l.step]}',
                style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 32,
              runSpacing: 12,
              children: [
                _kvBlock('Area', '${l.area.toStringAsFixed(2)} ha'),
                _kvBlock('Est. compensation', '₹ ${l.amountLakh.toStringAsFixed(1)} L'),
                _kvBlock('Next step', next),
              ],
            ),
            if (!l.paid) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) => TextButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Grievance form for survey ${l.survey} – coming soon (demo)')),
                  ),
                  icon: const Icon(Icons.report_gmailerrorred_outlined, size: 18),
                  label: const Text('Raise objection / grievance'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _lands.length;
    final inProcess = _lands.where((l) => l.inProcess).length;
    final paid = _lands.where((l) => l.paid).length;
    final disputed = _lands.where((l) => l.disputed).length;
    final area = _lands.fold<double>(0, (a, l) => a + l.area);
    final est = _lands.fold<double>(0, (a, l) => a + l.amountLakh);
    final received = _lands.where((l) => l.paid).fold<double>(0, (a, l) => a + l.amountLakh);
    final wide = isWide(context);
    final shown = _shown;

    return Scaffold(
      backgroundColor: kCream,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(wide ? 40 : 16, 48, wide ? 40 : 16, 56),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kDeep, kGreen],
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.person, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Namaste, Farmer',
                                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text('${maskMobile(widget.mobile)} · verified by OTP',
                                style: TextStyle(color: Colors.white.withOpacity(.8))),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Logout'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, box) {
                            final cols = box.maxWidth >= 760 ? 4 : 2;
                            const gap = 16.0;
                            final w = (box.maxWidth - gap * (cols - 1)) / cols;
                            return Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: [
                                SizedBox(width: w, child: _statCard(Icons.landscape_outlined, 'Total lands', '$total', kGreen)),
                                SizedBox(width: w, child: _statCard(Icons.hourglass_bottom, 'In process', '$inProcess', kSaffron)),
                                SizedBox(width: w, child: _statCard(Icons.check_circle_outline, 'Compensation paid', '$paid', const Color(0xFF1E88E5))),
                                SizedBox(width: w, child: _statCard(Icons.report_outlined, 'Disputed', '$disputed', const Color(0xFFD32F2F))),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Total area ${area.toStringAsFixed(2)} ha · Estimated compensation ₹ ${est.toStringAsFixed(1)} L '
                          '· Received ₹ ${received.toStringAsFixed(1)} L',
                          style: const TextStyle(color: Colors.black54, height: 1.4),
                        ),
                        const SizedBox(height: 26),
                        const Text('My lands',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kInk)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            for (int i = 0; i < _filters.length; i++)
                              ChoiceChip(
                                label: Text(_filters[i]),
                                selected: _filter == i,
                                selectedColor: kGreen.withOpacity(.18),
                                onSelected: (_) => setState(() => _filter = i),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (shown.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: Text('No lands in this category.', style: TextStyle(color: Colors.black45))),
                          )
                        else
                          for (final l in shown)
                            Padding(padding: const EdgeInsets.only(bottom: 18), child: _landCard(l)),
                        const SizedBox(height: 24),
                        const Text(
                          'Demo data – in the live portal this list comes from the land records linked to your verified mobile number.',
                          style: TextStyle(color: Colors.black38, fontSize: 12),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  static const List<Map<String, dynamic>> roles = [
    {
      'title': 'Farmer / Landowner',
      'subtitle': 'View land records and compensation',
      'icon': Icons.agriculture,
      'color': Color(0xFF2E7D32),
      'role': 'Farmer / Landowner',
    },
    {
      'title': 'National Admin',
      'subtitle': 'National-level administration',
      'icon': Icons.public,
      'color': Color(0xFF1565C0),
      'role': 'National Admin',
    },
    {
      'title': 'State Commissioner',
      'subtitle': 'Manage state-level projects',
      'icon': Icons.account_balance,
      'color': Color(0xFF6A1B9A),
      'role': 'State Commissioner',
    },
    {
      'title': 'District Collector',
      'subtitle': 'Manage district acquisition',
      'icon': Icons.gavel,
      'color': Color(0xFFEF6C00),
      'role': 'District Collector',
    },
    {
      'title': 'Taluk / Village Officer',
      'subtitle': 'Verify land and survey records',
      'icon': Icons.location_city,
      'color': Color(0xFF00838F),
      'role': 'Taluk / Village Officer',
    },
    {
      'title': 'Auditor',
      'subtitle': 'Review records and audit history',
      'icon': Icons.fact_check,
      'color': Color(0xFF455A64),
      'role': 'Auditor',
    },
  ];

  void _openLogin(BuildContext context, String role) {
    if (role == 'Farmer / Landowner') {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const LoginPage(),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => OfficerLoginPage(role: role),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCream,
      appBar: AppBar(
        backgroundColor: kDeep,
        foregroundColor: Colors.white,
        title: const Text(
          'NamNilam | Select Role',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.verified_user_outlined,
                    size: 55, color: kGreen),
                const SizedBox(height: 16),
                const Text(
                  'Who are you logging in as?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Select your role to continue to the appropriate login page.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black54),
                ),
                const SizedBox(height: 32),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 850
                        ? 3
                        : constraints.maxWidth >= 520
                            ? 2
                            : 1;
                    const gap = 16.0;
                    final width =
                        (constraints.maxWidth - gap * (columns - 1)) /
                            columns;

                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final item in roles)
                          SizedBox(
                            width: width,
                            child: Card(
                              elevation: 2,
                              color: Colors.white,
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: BorderSide(
                                  color: (item['color'] as Color)
                                      .withOpacity(0.18),
                                ),
                              ),
                              child: InkWell(
                                onTap: () => _openLogin(
                                  context,
                                  item['role'] as String,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(22),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 27,
                                        backgroundColor:
                                            (item['color'] as Color)
                                                .withOpacity(0.12),
                                        child: Icon(
                                          item['icon'] as IconData,
                                          color: item['color'] as Color,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Text(
                                        item['title'] as String,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: kInk,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item['subtitle'] as String,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Continue',
                                            style: TextStyle(
                                              color: item['color'] as Color,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(
                                            Icons.arrow_forward,
                                            size: 18,
                                            color: item['color'] as Color,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Separate login screen for government officers and auditors.
// Authentication must be connected to a secure backend in production.

class OfficerLoginPage extends StatefulWidget {
  final String role;

  const OfficerLoginPage({
    super.key,
    required this.role,
  });

  @override
  State<OfficerLoginPage> createState() => _OfficerLoginPageState();
}

class _OfficerLoginPageState extends State<OfficerLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _hidePassword = true;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
void _submit() {
  if (!_formKey.currentState!.validate()) return;

  const credentials = <String, Map<String, String>>{
    'National Admin': {
      'username': 'national.admin',
      'password': 'Admin@123',
    },
    'State Commissioner': {
      'username': 'state.commissioner',
      'password': 'State@123',
    },
    'District Collector': {
      'username': 'district.collector',
      'password': 'District@123',
    },
    'Taluk / Village Officer': {
      'username': 'taluk.officer',
      'password': 'Taluk@123',
    },
    'Auditor': {
      'username': 'auditor',
      'password': 'Audit@123',
    },
  };

  final account = credentials[widget.role];
  final username = _idController.text.trim();
  final password = _passwordController.text;

  if (account != null &&
      username == account['username'] &&
      password == account['password']) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => OfficerDashboardPage(role: widget.role),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invalid username or password. Please try again.'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: kCream,
      appBar: AppBar(
        backgroundColor: kDeep,
        foregroundColor: Colors.white,
        title: const Text('NamNilam | Official Login'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 460 : 420),
            child: Card(
              color: Colors.white,
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: Color(0xFFE8F5E9),
                          child: Icon(
                            Icons.admin_panel_settings,
                            color: kGreen,
                            size: 35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: Text(
                          widget.role,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: kInk,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Secure government portal access',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _idController,
                        decoration: InputDecoration(
                          labelText: 'Official ID / Username',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter your official ID'
                                : null,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _hidePassword = !_hidePassword,
                            ),
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty
                                ? 'Enter your password'
                                : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: kGreen,
                            padding: const EdgeInsets.symmetric(
                              vertical: 17,
                            ),
                          ),
                          icon: const Icon(Icons.login),
                          label: const Text('Secure Login'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Authorized personnel only. Your role and '
                        'permissions must be verified by the server.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Change role'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OfficerDashboardPage extends StatefulWidget {
  final String role;

  const OfficerDashboardPage({
    super.key,
    required this.role,
  });

  @override
  State<OfficerDashboardPage> createState() =>
      _OfficerDashboardPageState();
}

class _OfficerDashboardPageState extends State<OfficerDashboardPage> {
  int selectedIndex = 0;

  static const Map<String, Map<String, dynamic>> portalData = {
    'National Admin': {
      'subtitle': 'National-level oversight',
      'icon': Icons.public,
      'menu': [
        'Overview',
        'All Projects',
        'State Performance',
        'Compensation',
        'Reports',
        'User Management',
      ],
      'stats': [
        ['Total Projects', '248', Icons.apartment],
        ['Land Acquired', '18,450 ha', Icons.landscape],
        ['Compensation', '₹842 Cr', Icons.account_balance_wallet],
        ['Pending Cases', '1,284', Icons.pending_actions],
      ],
      'rows': [
        ['Tamil Nadu', '64', '78%', '₹186 Cr'],
        ['Karnataka', '48', '72%', '₹142 Cr'],
        ['Maharashtra', '71', '84%', '₹224 Cr'],
        ['Kerala', '32', '68%', '₹96 Cr'],
      ],
      'headers': ['State', 'Projects', 'Progress', 'Compensation'],
    },
    'State Commissioner': {
      'subtitle': 'State administration and monitoring',
      'icon': Icons.account_balance,
      'menu': [
        'Overview',
        'District Progress',
        'Projects',
        'Compensation',
        'Escalations',
        'Reports',
      ],
      'stats': [
        ['Districts', '38', Icons.location_city],
        ['Active Projects', '64', Icons.apartment],
        ['Compensation', '₹186 Cr', Icons.payments],
        ['Escalations', '27', Icons.warning_amber],
      ],
      'rows': [
        ['Erode', '12', '78%', '8'],
        ['Coimbatore', '15', '86%', '4'],
        ['Salem', '9', '62%', '7'],
        ['Madurai', '11', '71%', '5'],
      ],
      'headers': ['District', 'Projects', 'Progress', 'Escalations'],
    },
    'District Collector': {
      'subtitle': 'District-level acquisition coordination',
      'icon': Icons.gavel,
      'menu': [
        'Overview',
        'Land Records',
        'Notices & Hearings',
        'Ownership Disputes',
        'Compensation Review',
        'Reports',
      ],
      'stats': [
        ['Active Projects', '12', Icons.apartment],
        ['Land Parcels', '1,460', Icons.landscape],
        ['Hearings Pending', '38', Icons.event_note],
        ['Payment Pending', '126', Icons.payments],
      ],
      'rows': [
        ['ERD-1024', 'Perundurai', 'Verification', 'Pending'],
        ['ERD-1025', 'Bhavani', 'Valuation', 'Review'],
        ['ERD-1026', 'Chennimalai', 'Notice', 'In Progress'],
        ['ERD-1027', 'Kavindapadi', 'Compensation', 'Pending'],
      ],
      'headers': ['Project ID', 'Village', 'Stage', 'Status'],
    },
    'Taluk / Village Officer': {
      'subtitle': 'Field verification and land records',
      'icon': Icons.location_city,
      'menu': [
        'Overview',
        'Land Parcels',
        'Survey Records',
        'Landowners',
        'Document Uploads',
        'Verification',
      ],
      'stats': [
        ['Assigned Villages', '12', Icons.location_city],
        ['Land Parcels', '460', Icons.landscape],
        ['Verification Pending', '42', Icons.fact_check],
        ['Reports Submitted', '118', Icons.upload_file],
      ],
      'rows': [
        ['TN-ER-1001', 'Perundurai', 'Survey', 'Pending'],
        ['TN-ER-1002', 'Bhavani', 'Ownership', 'Verified'],
        ['TN-ER-1003', 'Chennimalai', 'Documents', 'Pending'],
        ['TN-ER-1004', 'Kavindapadi', 'Field Visit', 'In Progress'],
      ],
      'headers': ['Parcel ID', 'Village', 'Task', 'Status'],
    },
    'Auditor': {
      'subtitle': 'Independent financial oversight',
      'icon': Icons.fact_check,
      'menu': [
        'Overview',
        'Payment Records',
        'Award Verification',
        'Audit Observations',
        'Missing Documents',
        'Audit Reports',
      ],
      'stats': [
        ['Records Reviewed', '1,284', Icons.fact_check],
        ['Payments Audited', '₹86 Cr', Icons.payments],
        ['Discrepancies', '23', Icons.warning_amber],
        ['Open Observations', '14', Icons.assignment_late],
      ],
      'rows': [
        ['PAY-2041', '₹4,50,000', 'Amount mismatch', 'Flagged'],
        ['PAY-2042', '₹2,10,000', 'Documents', 'Pending'],
        ['PAY-2043', '₹3,80,000', 'Verified', 'Complete'],
        ['PAY-2044', '₹1,75,000', 'Duplicate check', 'Review'],
      ],
      'headers': ['Reference', 'Amount', 'Audit Finding', 'Status'],
    },
  };

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Tilt3D(
      maxTilt: .08,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = portalData[widget.role]!;

    final menu = data['menu'] as List<String>;
    final stats = data['stats'] as List<List<dynamic>>;
    final rows = data['rows'] as List<List<String>>;
    final headers = data['headers'] as List<String>;
    final icon = data['icon'] as IconData;
    final subtitle = data['subtitle'] as String;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        backgroundColor: kDeep,
        foregroundColor: Colors.white,
        title: const Text(
          'NamNilam',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: _buildSidebar(menu, icon),
      ),
      body: Row(
        children: [
          if (MediaQuery.sizeOf(context).width >= 850)
            SizedBox(
              width: 255,
              child: _buildSidebar(menu, icon),
            ),
          Expanded(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: kGreen.withOpacity(0.12),
                          child: Icon(icon, color: kGreen, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.role,
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  color: kInk,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      menu[selectedIndex],
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 900
                            ? 4
                            : constraints.maxWidth >= 550
                                ? 2
                                : 1;

                        const gap = 12.0;
                        final cardWidth =
                            (constraints.maxWidth - gap * (columns - 1)) /
                                columns;

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final stat in stats)
                              SizedBox(
                                width: cardWidth,
                                child: _statCard(
                                  stat[2] as IconData,
                                  stat[0] as String,
                                  stat[1] as String,
                                  kGreen,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    Card(
                      color: Colors.white,
                      elevation: 1,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Records & Activities',
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                      color: kInk,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.filter_list,
                                  color: kGreen,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor:
                                    WidgetStateProperty.all(
                                  const Color(0xFFEAF2EB),
                                ),
                                columns: [
                                  for (final header in headers)
                                    DataColumn(
                                      label: Text(
                                        header,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                                rows: [
                                  for (final row in rows)
                                    DataRow(
                                      cells: [
                                        for (final value in row)
                                          DataCell(
                                            Text(value),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Demonstration data for prototype purposes.',
                              style: TextStyle(
                                color: Colors.black45,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.security,
                              color: kGreen,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Access scope: ${widget.role}. '
                                'Production systems must enforce permissions '
                                'and data access on the server.',
                                style: const TextStyle(height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(List<String> menu, IconData roleIcon) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            color: kDeep,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(roleIcon, color: Colors.white, size: 36),
                const SizedBox(height: 12),
                const Text(
                  'NamNilam Portal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.role,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                for (int i = 0; i < menu.length; i++)
                  ListTile(
                    selected: selectedIndex == i,
                    selectedColor: kGreen,
                    selectedTileColor: kGreen.withOpacity(0.09),
                    leading: Icon(_menuIcon(i)),
                    title: Text(menu[i]),
                    onTap: () {
                      setState(() => selectedIndex = i);
                      if (MediaQuery.sizeOf(context).width < 850) {
                        Navigator.pop(context);
                      }
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  IconData _menuIcon(int index) {
    const icons = [
      Icons.dashboard_outlined,
      Icons.landscape_outlined,
      Icons.assignment_outlined,
      Icons.payments_outlined,
      Icons.fact_check_outlined,
      Icons.bar_chart_outlined,
    ];

    return icons[index % icons.length];
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const HomePage(),
      ),
      (route) => false,
    );
  }
}
