/// Route paths. Tabs live inside a StatefulShellRoute (state of each tab is preserved).
abstract final class Routes {
  // auth
  static const welcome = '/welcome';
  static const phone = '/auth/phone';
  static const otp = '/auth/otp';
  static const profileSetup = '/auth/profile';
  // tabs
  static const chats = '/chats';
  static const contacts = '/contacts';
  static const discover = '/discover';
  static const me = '/me';
  // chat
  static const chat = '/chats/:id';
  static const chatInfo = '/chats/:id/info';
  static const newChat = '/chats/new';
  static const newGroup = '/chats/new-group';
  static const search = '/search';
  // calls
  static const call = '/call/:id'; // full-screen, outside the shell
  // discover
  static const moments = '/discover/moments';
  static const channels = '/discover/channels';
  static const officialAccounts = '/discover/official';
  static const officialAccount = '/discover/official/:id';
  static const miniProgram = '/discover/mini/:id';
  static const scan = '/scan';
  static const nearby = '/discover/nearby';
  // wallet
  static const wallet = '/wallet';
  static const send = '/wallet/send';
  static const receive = '/wallet/receive';
  static const topUp = '/wallet/top-up';
  static const bills = '/wallet/bills';
  static const redPacket = '/wallet/red-packet';
  static const transactions = '/wallet/transactions';
  static const setPin = '/wallet/pin';
  // me
  static const settings = '/me/settings';
  static const myQr = '/me/qr';
  static const editProfile = '/me/profile';
}
