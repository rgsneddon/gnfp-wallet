import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../copyable_address.dart';
import '../gnfp_ledger.dart';
import '../gnfp_qr.dart';
import '../gnfp_social.dart';
import '../gnfp_theme.dart';

const gnfpCreditAdded = 'mined coins added to your balance';
const gnfpCreditNone = 'this address has no mined coins to add';

/// Only two user-facing credit results. Errors map to [gnfpCreditNone].
String creditWalletPhrase({required bool added}) =>
    added ? gnfpCreditAdded : gnfpCreditNone;

class WalletScreen extends StatefulWidget {
  const WalletScreen({
    super.key,
    required this.ledger,
    required this.address,
    required this.version,
    this.onSpendable,
    this.openExternal,
  });

  final GnfpLedger ledger;
  final GnfpAddress address;
  final String version;
  final void Function(GnfpAddress address, double amount)? onSpendable;
  final Future<void> Function(Uri url)? openExternal;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final toCtrl = TextEditingController();
  final amtCtrl = TextEditingController();
  String status = '';
  double? networkBal;
  int? networkTip;
  String? networkError;
  Timer? _poll;
  Timer? _retry;
  bool _trustZero = false;

  static const double bannerHeight = 112;

  static String formatBalance(double value) => value.toStringAsFixed(8);

  @override
  void initState() {
    super.initState();
    networkTip = widget.ledger.lastTip;
    _pullNetwork();
    _retry = Timer(const Duration(milliseconds: 400), () {
      if (mounted && networkTip == null) _pullNetwork();
    });
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      _pullNetwork();
    });
  }

  Future<void> _pullNetwork() async {
    try {
      final n = await widget.ledger.pool.balance(widget.address.value);
      if (!mounted) return;
      setState(() {
        if (n > 0) {
          _trustZero = false;
          networkBal = n;
          widget.ledger.rememberSpendable(widget.address, n);
          widget.onSpendable?.call(widget.address, n);
        } else if (_trustZero) {
          networkBal = n;
        } else {
          final kept = widget.ledger.balance(widget.address);
          if (kept > 0) networkBal = kept;
        }
      });
    } catch (e) {
      if (mounted) setState(() => networkError = _shortNetworkError(e));
    }
    try {
      final tip = await widget.ledger.networkTip();
      if (mounted) {
        setState(() {
          networkTip = tip;
          networkError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => networkError = _shortNetworkError(e));
    }
  }

  static String _shortNetworkError(Object e) {
    final s = e.toString();
    if (s.contains('TimeoutException') ||
        s.toLowerCase().contains('timed out') ||
        s.toLowerCase().contains('timeout')) {
      return 'timeout';
    }
    final line = s.split('\n').first.trim();
    return line.length > 80 ? '${line.substring(0, 80)}…' : line;
  }

  Future<void> _openSocial(GnfpSocialChannel channel) async {
    final uri = Uri.parse(channel.url);
    final open = widget.openExternal;
    if (open != null) {
      await open(uri);
      return;
    }
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }

  Future<void> _send() async {
    try {
      await widget.ledger.send(
        from: widget.address,
        to: GnfpAddress(toCtrl.text.trim()),
        amount: double.parse(amtCtrl.text),
      );
      setState(() {
        status = 'sent';
        _trustZero = true;
      });
      await _pullNetwork();
    } catch (e) {
      setState(() => status = e.toString());
    }
  }

  Future<void> _openQr() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          key: const Key('gnfp-qr-popup'),
          backgroundColor: GnfpTheme.black,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GnfpQr(address: widget.address),
                const SizedBox(height: 12),
                CopyableAddress(
                  key: const Key('gnfp-qr-address'),
                  address: widget.address.value,
                  label: 'Address:',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('gnfp-qr-close'),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close', style: TextStyle(color: GnfpTheme.neonCyan)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _retry?.cancel();
    toCtrl.dispose();
    amtCtrl.dispose();
    super.dispose();
  }

  BoxDecoration get _boxDeco => BoxDecoration(
        color: GnfpTheme.blackCard,
        borderRadius: BorderRadius.circular(GnfpTheme.radius),
        border: Border.all(color: const Color(0xFF222222)),
      );

  Widget _identityBox() {
    return Container(
      key: const Key('gnfp-box-identity'),
      height: bannerHeight,
      decoration: _boxDeco,
      clipBehavior: Clip.hardEdge,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: bannerHeight,
            width: bannerHeight,
            child: Image.asset(
              'assets/logo.png',
              key: const Key('gnfp-logo'),
              height: bannerHeight,
              fit: BoxFit.fitHeight,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GNFP Wallet',
                  softWrap: false,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: GnfpTheme.cream,
                  ),
                ),
                Text(
                  'GNFPv${widget.version}',
                  key: const Key('gnfp-version'),
                  softWrap: false,
                  style: const TextStyle(
                    fontSize: 12,
                    color: GnfpTheme.neonCyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _holdingsBox(double bal) {
    return Container(
      key: const Key('gnfp-box-holdings'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: _boxDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance: ${formatBalance(bal)} $gnfpTicker',
            key: const Key('gnfp-balance'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: GnfpTheme.neonLime,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Network Tip: ${networkTip ?? '…'}${networkError == null || networkError!.isEmpty ? '' : ' — $networkError'}',
            key: const Key('gnfp-network-tip'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: GnfpTheme.neonYellow,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CopyableAddress(
                  key: const Key('gnfp-address'),
                  address: widget.address.value,
                ),
              ),
              TextButton(
                key: const Key('gnfp-show-qr'),
                onPressed: _openQr,
                child: const Text(
                  'show QR code',
                  style: TextStyle(color: GnfpTheme.neonCyan, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bal = networkBal ?? widget.ledger.balance(widget.address);
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return SafeArea(
      child: Padding(
        key: const Key('gnfp-wallet-facade'),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: SingleChildScrollView(
          child: Column(
        children: [
          if (narrow)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _identityBox(),
                const SizedBox(height: 8),
                _holdingsBox(bal),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _identityBox(),
                const SizedBox(width: 8),
                Expanded(child: _holdingsBox(bal)),
              ],
            ),
          const SizedBox(height: 8),
          Container(
            key: const Key('gnfp-box-send'),
            padding: const EdgeInsets.all(8),
            decoration: _boxDeco,
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 88,
                      child: FilledButton(
                        key: const Key('gnfp-send'),
                        onPressed: _send,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Send'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        children: [
                          TextField(
                            key: const Key('gnfp-send-to'),
                            controller: toCtrl,
                            style: const TextStyle(color: GnfpTheme.cream, fontSize: 13),
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'Send to GNFP address',
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            key: const Key('gnfp-send-amount'),
                            controller: amtCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: GnfpTheme.cream, fontSize: 13),
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'Amount GNFP',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (status.isNotEmpty) Text(status, key: const Key('gnfp-wallet-status')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            gnfpSocialHeading,
            key: Key('gnfp-social-heading'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: GnfpTheme.cream,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          for (final channel in gnfpSocialChannels)
            Center(
              child: TextButton(
                key: Key('gnfp-social-${channel.title}'),
                onPressed: () => _openSocial(channel),
                child: Text(
                  channel.title,
                  style: const TextStyle(
                    color: GnfpTheme.neonCyan,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
        ),
        ),
      ),
    );
  }
}
