import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/demo/demo_content.dart';
import '../../../../core/design/design.dart';
import '../../../../core/utils/money_format.dart';

/// Mini program container with the three-dot capsule menu from the design.
class MiniProgramScreen extends StatefulWidget {
  const MiniProgramScreen({super.key, required this.programId});

  final String programId;

  @override
  State<MiniProgramScreen> createState() => _MiniProgramScreenState();
}

class _MiniProgramScreenState extends State<MiniProgramScreen> {
  var _refreshKey = 0;

  DemoMiniProgram get _program => DemoContent.miniProgram(widget.programId);

  Future<void> _share() async {
    await Clipboard.setData(
      ClipboardData(text: 'Open ${_program.name} on EthioChat.'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mini program link copied.')),
    );
  }

  void _menu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Refresh'),
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _refreshKey++);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mini program refreshed.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(sheetContext);
                _share();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About this mini program'),
              onTap: () {
                Navigator.pop(sheetContext);
                showAboutDialog(
                  context: context,
                  applicationName: _program.name,
                  applicationVersion: 'v1.0',
                  children: [Text(_program.description)],
                );
              },
            ),
            const SizedBox(height: Sp.x2),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          tooltip: 'Close mini program',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_program.icon, size: 20, color: _program.color),
            const SizedBox(width: Sp.x2),
            Flexible(
              child: Text(
                _program.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Mini program menu',
            icon: Container(
              padding: const EdgeInsets.all(Sp.x2),
              decoration: BoxDecoration(
                color: pal.chip,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(Icons.more_horiz_rounded, size: 20),
            ),
            onPressed: _menu,
          ),
          const SizedBox(width: Sp.x1),
        ],
      ),
      body: SafeArea(
        top: false,
        child: KeyedSubtree(
          key: ValueKey(_refreshKey),
          child: switch (_program.id) {
            'bills' => _MiniBills(program: _program),
            'airtime' => _MiniAirtime(program: _program),
            'shop' => _MiniShop(program: _program),
            _ => _MiniRide(program: _program),
          },
        ),
      ),
    );
  }
}

class _ProgramIntro extends StatelessWidget {
  const _ProgramIntro({required this.program});

  final DemoMiniProgram program;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sp.x4),
      decoration: BoxDecoration(
        color: program.color.withValues(alpha: 0.1),
        borderRadius: Rad.r18,
        border: Border.all(color: program.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          EthioMiniAppTile(
            label: program.name,
            icon: program.icon,
            color: program.color.withValues(alpha: 0.18),
            onTap: () {},
          ),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: Text(
              program.description,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: EthioPalette.of(context).textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBills extends StatefulWidget {
  const _MiniBills({required this.program});

  final DemoMiniProgram program;

  @override
  State<_MiniBills> createState() => _MiniBillsState();
}

class _MiniBillsState extends State<_MiniBills> {
  final _account = TextEditingController();
  final _amount = TextEditingController();
  var _biller = DemoContent.billers.first;
  var _busy = false;

  @override
  void dispose() {
    _account.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_account.text.trim().isEmpty || parseEtbToMinor(_amount.text) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an account number and amount.')),
      );
      return;
    }
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => _busy = false);
    final amount = formatEtb(parseEtbToMinor(_amount.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_biller.name} payment of $amount confirmed.')),
    );
    _account.clear();
    _amount.clear();
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: Sp.screen.copyWith(top: Sp.x3, bottom: Sp.x8),
      children: [
        _ProgramIntro(program: widget.program),
        const SizedBox(height: Sp.x4),
        Text('Choose a biller', style: text.titleMedium),
        const SizedBox(height: Sp.x2),
        EthioSectionCard(
          children: [
            for (final biller in DemoContent.billers)
              ListTile(
                leading: EthioIconTile(icon: Icons.receipt_long_outlined),
                title: Text(biller.name),
                subtitle: Text(biller.accountLabel),
                trailing: _biller == biller
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: EthioColors.goldDeep,
                      )
                    : null,
                onTap: () => setState(() => _biller = biller),
              ),
          ],
        ),
        const SizedBox(height: Sp.x4),
        Text(_biller.accountLabel, style: text.titleMedium),
        const SizedBox(height: Sp.x2),
        EthioTextField(
          controller: _account,
          hint: 'Enter ${_biller.accountLabel.toLowerCase()}',
        ),
        const SizedBox(height: Sp.x3),
        Text('Amount', style: text.titleMedium),
        const SizedBox(height: Sp.x2),
        EthioTextField(
          controller: _amount,
          hint: '0.00',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefix: const Icon(Icons.currency_exchange_rounded, size: 20),
        ),
        const SizedBox(height: Sp.x5),
        EthioButton(
          label: _busy ? 'Processing…' : 'Pay bill',
          icon: Icons.lock_outline_rounded,
          onPressed: _busy ? null : _submit,
        ),
        const SizedBox(height: Sp.x3),
        Center(
          child: Text(
            FeatureFlags.wallet
                ? 'Payments settle in the EthioChat wallet.'
                : 'Wallet payments are disabled in this release.',
            style: text.labelSmall?.copyWith(color: pal.textTertiary),
          ),
        ),
      ],
    );
  }
}

class _MiniAirtime extends StatefulWidget {
  const _MiniAirtime({required this.program});

  final DemoMiniProgram program;

  @override
  State<_MiniAirtime> createState() => _MiniAirtimeState();
}

class _MiniAirtimeState extends State<_MiniAirtime> {
  final _phone = TextEditingController();
  var _amount = 50;
  var _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _buy() async {
    if (_phone.text.trim().length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid phone number.')),
      );
      return;
    }
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'ETB $_amount airtime sent to ${_phone.text.trim()}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: Sp.screen.copyWith(top: Sp.x3, bottom: Sp.x8),
      children: [
        _ProgramIntro(program: widget.program),
        const SizedBox(height: Sp.x4),
        Text('Phone number', style: text.titleMedium),
        const SizedBox(height: Sp.x2),
        EthioTextField(
          controller: _phone,
          hint: '+251 9X XXX XXXX',
          keyboardType: TextInputType.phone,
          prefix: const Icon(Icons.phone_iphone_rounded, size: 20),
        ),
        const SizedBox(height: Sp.x4),
        Text('Choose airtime', style: text.titleMedium),
        const SizedBox(height: Sp.x2),
        Wrap(
          spacing: Sp.x2,
          runSpacing: Sp.x2,
          children: [
            for (final amount in const [25, 50, 100, 200])
              ChoiceChip(
                label: Text('ETB $amount'),
                selected: _amount == amount,
                showCheckmark: false,
                selectedColor: EthioColors.gold,
                onSelected: (_) => setState(() => _amount = amount),
              ),
          ],
        ),
        const SizedBox(height: Sp.x5),
        EthioButton(
          label: _busy ? 'Sending…' : 'Buy airtime',
          icon: Icons.bolt_rounded,
          onPressed: _busy ? null : _buy,
        ),
      ],
    );
  }
}

class _MiniShop extends StatefulWidget {
  const _MiniShop({required this.program});

  final DemoMiniProgram program;

  @override
  State<_MiniShop> createState() => _MiniShopState();
}

class _MiniShopState extends State<_MiniShop> {
  final _cart = <String, int>{};
  static const _items = [
    ('Ethiopian coffee, 1 kg', 48000),
    ('Handwoven basket', 125000),
    ('Leather notebook', 65000),
    ('Berbere spice mix', 18000),
  ];

  int get _total => _items.fold<int>(
        0,
        (sum, item) => sum + item.$2 * (_cart[item.$1] ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: Sp.screen.copyWith(top: Sp.x3, bottom: Sp.x4),
            children: [
              _ProgramIntro(program: widget.program),
              const SizedBox(height: Sp.x4),
              Text('Local favourites', style: text.titleMedium),
              const SizedBox(height: Sp.x2),
              for (final item in _items)
                Container(
                  margin: const EdgeInsets.only(bottom: Sp.x2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: Rad.r14,
                    border: Border.all(color: pal.line),
                  ),
                  child: ListTile(
                    leading: EthioIconTile(
                      icon: Icons.shopping_bag_outlined,
                      background: widget.program.color.withValues(alpha: 0.14),
                    ),
                    title: Text(item.$1),
                    subtitle: Text(formatEtb(item.$2)),
                    trailing: IconButton(
                      tooltip: 'Add to cart',
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      onPressed: () => setState(
                        () => _cart[item.$1] = (_cart[item.$1] ?? 0) + 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: Sp.screen.copyWith(top: Sp.x2, bottom: Sp.x2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_cart.values.fold(0, (a, b) => a + b)} items · '
                    '${formatEtb(_total)}',
                    style: text.titleMedium,
                  ),
                ),
                EthioButton(
                  label: 'Checkout',
                  size: EthioButtonSize.small,
                  expand: false,
                  onPressed: _total == 0
                      ? null
                      : () {
                          final total = _total;
                          setState(_cart.clear);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Order placed · ${formatEtb(total)}',
                              ),
                            ),
                          );
                        },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniRide extends StatefulWidget {
  const _MiniRide({required this.program});

  final DemoMiniProgram program;

  @override
  State<_MiniRide> createState() => _MiniRideState();
}

class _MiniRideState extends State<_MiniRide> {
  final _pickup = TextEditingController(text: 'Bole Medhanialem');
  final _dropOff = TextEditingController();
  var _searching = false;

  @override
  void dispose() {
    _pickup.dispose();
    _dropOff.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (_dropOff.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a destination.')),
      );
      return;
    }
    setState(() => _searching = true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _searching = false);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ride confirmed'),
        content: Text(
          'A driver is on the way to ${_pickup.text.trim()}.\n\n'
          'Destination: ${_dropOff.text.trim()}\n'
          'Estimated fare: ETB 180.00',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: Sp.screen.copyWith(top: Sp.x3, bottom: Sp.x8),
      children: [
        _ProgramIntro(program: widget.program),
        const SizedBox(height: Sp.x4),
        Text('Where are you going?', style: text.titleMedium),
        const SizedBox(height: Sp.x2),
        EthioTextField(
          controller: _pickup,
          hint: 'Pickup',
          prefix: const Icon(Icons.my_location_rounded, size: 20),
        ),
        const SizedBox(height: Sp.x2),
        EthioTextField(
          controller: _dropOff,
          hint: 'Drop-off',
          prefix: const Icon(Icons.place_outlined, size: 20),
        ),
        const SizedBox(height: Sp.x4),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: EthioPalette.of(context).chip,
            borderRadius: Rad.r18,
          ),
          child: const Center(
            child: Icon(
              Icons.map_outlined,
              size: 54,
              color: EthioColors.goldDeep,
            ),
          ),
        ),
        const SizedBox(height: Sp.x4),
        EthioButton(
          label: _searching ? 'Finding a driver…' : 'Find a ride',
          icon: Icons.local_taxi_outlined,
          onPressed: _searching ? null : _request,
        ),
      ],
    );
  }
}
