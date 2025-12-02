import 'package:flutter/material.dart';
import '../constants.dart';
import '../widgets/table_card.dart';
import '../widgets/bottom_chat_pill.dart';
import '../widgets/play_sheet.dart';
import '../widgets/pay_modal.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({Key? key}) : super(key: key);
  @override
  _LobbyScreenState createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
  bool playSheetOpen = false;
  bool bgChatVisible = true;

  // small controller to animate floating chat messages
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController =
        AnimationController(vsync: this, duration: Duration(seconds: 8))
          ..repeat();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  void openPlaySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF14161b),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => PlayOptionsSheet(onSelect: (mode) {
        Navigator.of(context).pop();
        // Open Pay modal as per prototype
        showDialog(
            context: context,
            builder: (_) => PayModal(
                entryText: mode == '2p' ? '500 Gold' : '2.5k Gold',
                onJoin: () {
                  Navigator.of(context).pop();
                  // For demo: navigate to game screen with dummy id
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => GameScreen(gameId: 'demo-game')));
                }));
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final appWidth = w > 420 ? 390.0 : w;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Center(
        child: Container(
          width: appWidth,
          height: 844,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: AppColors.bgDark,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                  color: AppColors.neonPurple.withOpacity(0.12), blurRadius: 50)
            ],
          ),
          child: Stack(
            children: [
              // BG Chat Layer (floating faded messages)
              Positioned.fill(child: _buildBgChat()),
              // content
              Column(
                children: [
                  SizedBox(height: 20),
                  _topBar(),
                  Expanded(child: _lobbyContent()),
                ],
              ),
              // Play button fixed
              Positioned(
                  bottom: 120,
                  left: 0,
                  right: 0,
                  child: Center(child: _playBtn())),
              // bottom pill
              Positioned(bottom: 0, left: 0, right: 0, child: BottomChatPill()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBgChat() {
    // three floating messages; use animated builder to float up
    return IgnorePointer(
      child: Stack(
        children: [
          _floatingMsg(
              left: 20,
              delay: 0,
              avatar: 'assets/avatars/a1.png',
              text: '10k?'),
          _floatingMsg(
              right: 20,
              delay: 2.5,
              avatar: 'assets/avatars/a2.png',
              text: 'Join 4',
              reverse: true),
          _floatingMsg(
              left: 50, delay: 5, avatar: 'assets/avatars/a3.png', text: 'GG!'),
        ],
      ),
    );
  }

  Widget _floatingMsg(
      {double? left,
      double? right,
      required double delay,
      required String avatar,
      required String text,
      bool reverse = false}) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (_, __) {
        final t = (_bgController.value + (delay / 8)) % 1.0;
        final startY = 820.0;
        final endY = 120.0;
        final y = startY - (startY - endY) * t;
        final opacity = (t < 0.1)
            ? (t * 10)
            : (t > 0.8)
                ? (1 - (t - 0.8) * 5)
                : 0.8;
        return Positioned(
          left: left,
          right: right,
          top: y,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 9, backgroundImage: AssetImage(avatar)),
                  SizedBox(width: 8),
                  Text(text,
                      style: TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _topBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Stack(children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset('assets/avatars/a1.png',
                      width: 48, height: 48, fit: BoxFit.cover)),
              Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                        gradient: AppColors.primaryGrad,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                    child: Center(
                        child: Text('12',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white))),
                  ))
            ]),
            SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Alex',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text('Mumbai, India',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ])
          ]),
          Row(children: [
            _currencyPill(icon: Icons.games, value: '450'),
            SizedBox(width: 8),
            _currencyPill(icon: Icons.insights, value: '24k'),
          ])
        ],
      ),
    );
  }

  Widget _currencyPill({required IconData icon, required String value}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder)),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.neonBlue),
        SizedBox(width: 6),
        Text(value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        SizedBox(width: 6),
        Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
                gradient: AppColors.primaryGrad, shape: BoxShape.circle),
            child: Icon(Icons.add, size: 12, color: Colors.white))
      ]),
    );
  }

  Widget _lobbyContent() {
    return Padding(
      padding: EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 16),
      child: Column(
        children: [
          _clubHeader(),
          SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(bottom: 160),
              children: [
                TableCard(
                    mode: '2P',
                    winText: 'WIN 900 GOLD',
                    entry: 'Entry: 500 Gold',
                    onTap: () {
                      // open pay modal
                      showDialog(
                          context: context,
                          builder: (_) => PayModal(
                              entryText: '500 Gold',
                              onJoin: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) =>
                                        GameScreen(gameId: 'demo-game')));
                              }));
                    }),
                SizedBox(height: 12),
                TableCard(
                    mode: 'TEAM',
                    winText: 'WIN 5K GOLD',
                    entry: 'Entry: 2.5k Gold',
                    onTap: () {
                      showDialog(
                          context: context,
                          builder: (_) => PayModal(
                              entryText: '2.5k Gold',
                              onJoin: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) =>
                                        GameScreen(gameId: 'demo-team')));
                              }));
                    }),
                SizedBox(height: 12),
                TableCard(
                    mode: '2P',
                    winText: 'WIN 100 GEMS',
                    entry: 'Entry: 50 Gems',
                    onTap: () {
                      showDialog(
                          context: context,
                          builder: (_) => PayModal(
                              entryText: '50 Gems',
                              onJoin: () {
                                Navigator.of(context).pop();
                              }));
                    }),
                SizedBox(height: 12),
                // more cards...
                TableCard(
                    mode: '2P',
                    winText: 'WIN 200 GOLD',
                    entry: 'Entry: 100 Gold',
                    onTap: () {
                      showDialog(
                          context: context,
                          builder: (_) => PayModal(
                              entryText: '100 Gold',
                              onJoin: () {
                                Navigator.of(context).pop();
                              }));
                    }),
                SizedBox(height: 50),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _playBtn() {
    return GestureDetector(
      onTap: openPlaySheet,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
            gradient: AppColors.primaryGrad,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                  color: AppColors.neonPurple.withOpacity(0.28),
                  blurRadius: 40,
                  offset: Offset(0, 10))
            ],
            border:
                Border.all(color: Colors.white.withOpacity(0.12), width: 3)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.play_arrow, color: Colors.white, size: 32),
          SizedBox(height: 4),
          Text('PLAY',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  color: Colors.white))
        ]),
      ),
    );
  }
}
