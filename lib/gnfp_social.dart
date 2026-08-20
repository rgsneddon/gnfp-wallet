/// Wallet-tab social channels. Titles only — URLs stay off the page.
library;

class GnfpSocialChannel {
  const GnfpSocialChannel({required this.title, required this.url});
  final String title;
  final String url;
}

const gnfpSocialHeading = 'SOCIAL CHANNELS';

const gnfpSocialChannels = <GnfpSocialChannel>[
  GnfpSocialChannel(
    title: 'DISCORD',
    url: 'https://discord.com/invite/H9TdGyCUCa',
  ),
  GnfpSocialChannel(
    title: 'TELEGRAM',
    url: 'https://t.me/gnfpchat',
  ),
  GnfpSocialChannel(
    title: 'BitcoinTalk',
    url: 'https://bitcointalk.org/index.php?topic=5591310',
  ),
];

Uri gnfpSocialLaunchUri(String title) {
  for (final c in gnfpSocialChannels) {
    if (c.title == title) return Uri.parse(c.url);
  }
  throw ArgumentError('unknown social channel');
}
