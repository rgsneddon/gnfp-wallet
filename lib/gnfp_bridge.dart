/// Mix / bridge Restore Privacy coins across wallets (sidechain lock + mint).
///
/// PERC and GNFP (and any later RP ticker) move through one hop: lock on the
/// source book, credit on the dest book. No PERC spendable balance is left on
/// the GNFP address — the dest credit is always the dest ticker.
library;

import 'gnfp_ledger.dart';

const rpMixableCoins = ['GNFP', 'PERC'];

class RpBook {
  RpBook(this.ticker);
  final String ticker;
  final Map<String, double> balances = {};

  double of(String address) => balances[address] ?? 0;

  void credit(String address, double amount) {
    balances[address] = of(address) + amount;
  }

  void debit(String address, double amount) {
    if (of(address) < amount) {
      throw StateError('insufficient $ticker');
    }
    balances[address] = of(address) - amount;
  }
}

class MixHop {
  const MixHop({
    required this.id,
    required this.fromCoin,
    required this.toCoin,
    required this.fromAddress,
    required this.toAddress,
    required this.amount,
  });

  final String id;
  final String fromCoin;
  final String toCoin;
  final String fromAddress;
  final String toAddress;
  final double amount;
}

class RpMixer {
  RpMixer({GnfpLedger? gnfp}) : gnfp = gnfp ?? GnfpLedger() {
    books[gnfpTicker] = RpBook(gnfpTicker);
    books['PERC'] = RpBook('PERC');
  }

  final GnfpLedger gnfp;
  final Map<String, RpBook> books = {};
  final List<MixHop> hops = [];

  Future<void> fund(String coin, String address, double amount) async {
    _book(coin).credit(address, amount);
    if (coin == gnfpTicker) {
      await gnfp.receive(to: GnfpAddress(address), amount: amount, memo: 'fund');
    }
  }

  Future<MixHop> mix({
    required String fromCoin,
    required String toCoin,
    required String fromAddress,
    required String toAddress,
    required double amount,
  }) async {
    if (fromCoin == toCoin) {
      throw ArgumentError('mix needs two coins');
    }
    if (!rpMixableCoins.contains(fromCoin) || !rpMixableCoins.contains(toCoin)) {
      throw ArgumentError('unknown coin');
    }
    if (amount <= 0) {
      throw ArgumentError('amount must be positive');
    }
    if (toCoin == gnfpTicker) {
      throw StateError('self_mint_forbidden');
    }
    if (toCoin == gnfpTicker && !GnfpAddress(toAddress).isValid) {
      throw ArgumentError('dest must be a GNFP address');
    }
    _book(fromCoin).debit(fromAddress, amount);
    _book(toCoin).credit(toAddress, amount);
    final hop = MixHop(
      id: 'mix-${hops.length + 1}',
      fromCoin: fromCoin,
      toCoin: toCoin,
      fromAddress: fromAddress,
      toAddress: toAddress,
      amount: amount,
    );
    hops.add(hop);
    return hop;
  }

  RpBook _book(String coin) {
    final b = books[coin];
    if (b == null) {
      throw ArgumentError('no book for $coin');
    }
    return b;
  }
}
