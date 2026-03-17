import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'led_display.dart';
import 'models/ledbanner_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabCtrl;

  // Display state
  final _textCtrl = TextEditingController(text: 'LEDSNAP  HELLO! ');
  Color  _color      = const Color(0xFFFF2200);
  bool   _rainbow    = false;
  double _speed      = 55;
  double _sizeRatio  = 0.42;
  bool   _flash      = false;
  double _flashRate  = 3;

  // Effect state
  String _effect      = 'none';
  double _waveAmp     = 4;
  double _waveSpeed   = 2.5;
  double _waveFreq    = 0.04;
  double _pulseRate   = 1.5;
  double _rippleSpeed = 4;
  double _rippleFreq  = 0.6;
  double _glitchInt   = 3;
  double _fireFlicker = 0.3;
  double _matrixSpd   = 2;

  // In/Out state
  String _inAnim    = 'none';
  String _outAnim   = 'none';
  double _zoneRatio = 0.15;

  // Plus state
  bool   _plusOn   = false;
  String _dotShape = 'circle';

  static Color _fromHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  static String _toHex(Color c) =>
      '#${c.red.toRadixString(16).padLeft(2,'0')}${c.green.toRadixString(16).padLeft(2,'0')}${c.blue.toRadixString(16).padLeft(2,'0')}'.toUpperCase();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  // Export .ledbanner
  Future<void> _export() async {
    final model = LEDBannerModel(
      text: _textCtrl.text, color: _toHex(_color), rainbow: _rainbow,
      sizeRatio: _sizeRatio, speed: _speed, flash: _flash, flashRate: _flashRate,
      effect: _effect, waveAmp: _waveAmp, waveSpeed: _waveSpeed, waveFreq: _waveFreq,
      pulseRate: _pulseRate, rippleSpeed: _rippleSpeed, rippleFreq: _rippleFreq,
      inAnim: _inAnim, outAnim: _outAnim, zoneRatio: _zoneRatio, dotShape: _dotShape,
      name: _textCtrl.text.substring(0, _textCtrl.text.length.clamp(0, 16)),
    );
    final dir  = await getTemporaryDirectory();
    final safe = _textCtrl.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final name = '${safe.substring(0, safe.length.clamp(0, 16))}.ledbanner';
    final file = File('${dir.path}/$name');
    await file.writeAsString(model.toFileContent());
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'LEDSnap - $name',
    );
  }

  // Import .ledbanner via share sheet
  Future<void> _import() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Open a .ledbanner file and share it to LEDSnap to import.'),
        backgroundColor: Color(0xFF1A1A1A),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildDisplay(),
          _buildTabBar(),
          Expanded(child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildDisplayTab(),
              _buildEffectTab(),
              _buildInOutTab(),
              _buildPlusTab(),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    final isFit = _effect != 'none';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF161616))),
      ),
      child: Row(children: [
        const Text('LED', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 6, color: Color(0xFFFF2200), fontFamily: 'Courier')),
        const Text('SNAP', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w100, letterSpacing: 6, color: Color(0xFF3A3A3A))),
        if (_plusOn) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF5C842), Color(0xFFE8A010)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('PLUS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.black)),
          ),
        ],
        const Spacer(),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: isFit ? const Color(0xFF1A0500) : Colors.transparent,
            border: Border.all(color: isFit ? const Color(0xFFFF2200) : const Color(0xFF1E1E1E)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isFit ? 'FIT' : 'SCROLL',
            style: TextStyle(fontSize: 8, letterSpacing: 3, color: isFit ? const Color(0xFFFF2200) : const Color(0xFF333333)),
          ),
        ),
        const SizedBox(width: 8),
        const Text('v2.3', style: TextStyle(fontSize: 9, color: Color(0xFF252525), letterSpacing: 2)),
      ]),
    );
  }

  Widget _buildDisplay() {
    return Container(
      color: const Color(0xFF020202),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: LEDDisplay(
        text: _textCtrl.text,
        ledColor: _color,
        rainbow: _rainbow,
        sizeRatio: _sizeRatio,
        speed: _speed,
        flash: _flash,
        flashRate: _flashRate,
        effect: _effect,
        waveAmp: _waveAmp,
        waveSpeed: _waveSpeed,
        waveFreq: _waveFreq,
        pulseRate: _pulseRate,
        rippleSpeed: _rippleSpeed,
        rippleFreq: _rippleFreq,
        glitchInt: _glitchInt,
        inAnim: _inAnim,
        outAnim: _outAnim,
        zoneRatio: _zoneRatio,
        dotShape: _dotShape,
        plusOn: _plusOn,
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF141414))),
      ),
      child: TabBar(
        controller: _tabCtrl,
        labelStyle: const TextStyle(fontSize: 9, letterSpacing: 2, fontFamily: 'Courier'),
        unselectedLabelStyle: const TextStyle(fontSize: 9, letterSpacing: 2),
        labelColor: const Color(0xFFFF2200),
        unselectedLabelColor: const Color(0xFF333333),
        indicatorColor: const Color(0xFFFF2200),
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: const [
          Tab(text: 'DISPLAY'),
          Tab(text: 'EFFECT'),
          Tab(text: 'IN / OUT'),
          Tab(text: 'PLUS'),
        ],
      ),
    );
  }

  Widget _buildDisplayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('Message'),
        TextField(
          controller: _textCtrl,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontFamily: 'Courier', letterSpacing: 1, fontSize: 14),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Color'),
            Row(children: [
              GestureDetector(
                onTap: _rainbow ? null : _showColorPicker,
                child: Opacity(
                  opacity: _rainbow ? 0.25 : 1,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFF1E1E1E)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _pill('Rainbow', _rainbow, () => setState(() => _rainbow = !_rainbow), gradient: true),
            ]),
          ])),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Flash'),
            Row(children: [
              _pill('Blink', _flash, () => setState(() => _flash = !_flash)),
              if (_flash) ...[
                const SizedBox(width: 8),
                Text('${_flashRate.round()}/s', style: const TextStyle(fontSize: 10, color: Color(0xFF555555))),
              ],
            ]),
            if (_flash) ...[
              const SizedBox(height: 8),
              _slider(_flashRate, 1, 12, (v) => setState(() => _flashRate = v)),
            ],
          ])),
        ]),
        const Divider(color: Color(0xFF111111), height: 32),
        _sliderRow('Scroll Speed', _speed, 10, 300, 'px/s', (v) => setState(() => _speed = v)),
        const SizedBox(height: 16),
        _sliderRow('Text Size', _sizeRatio * 100, 20, 100, '%', (v) => setState(() => _sizeRatio = v / 100)),
        const Divider(color: Color(0xFF111111), height: 32),
        Row(children: [
          Expanded(child: _outlineBtn('EXPORT .ledbanner', const Color(0xFFFF2200), _export)),
          const SizedBox(width: 10),
          Expanded(child: _outlineBtn('IMPORT .ledbanner', const Color(0xFF333333), _import)),
        ]),
      ]),
    );
  }

  Widget _buildEffectTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            border: Border.all(color: const Color(0xFF161616)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'Effects switch to FIT mode - dots shrink so all text fits on screen. Set to None to scroll.',
            style: TextStyle(fontSize: 9, letterSpacing: 1, color: Color(0xFF444444), height: 1.7),
          ),
        ),
        const SizedBox(height: 16),
        _label('LED Effect'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _pill('None',   _effect == 'none',   () => setState(() => _effect = 'none')),
          _pill('Wave',   _effect == 'wave',   () => setState(() => _effect = 'wave')),
          _pill('Pulse',  _effect == 'pulse',  () => setState(() => _effect = 'pulse')),
          _pill('Ripple', _effect == 'ripple', () => setState(() => _effect = 'ripple')),
          _lockedOrPill('Glitch', _effect == 'glitch', () => setState(() => _effect = 'glitch')),
          _lockedOrPill('Fire',   _effect == 'fire',   () => setState(() => _effect = 'fire')),
          _lockedOrPill('Bounce', _effect == 'bounce', () => setState(() => _effect = 'bounce')),
          _lockedOrPill('Matrix', _effect == 'matrix', () => setState(() => _effect = 'matrix')),
        ]),
        const SizedBox(height: 16),
        if (_effect == 'wave') ...[
          _sliderRow('Amplitude', _waveAmp, 1, 12, 'rows', (v) => setState(() => _waveAmp = v)),
          const SizedBox(height: 12),
          _sliderRow('Speed', _waveSpeed, 0.5, 10, 'x', (v) => setState(() => _waveSpeed = v)),
          const SizedBox(height: 12),
          _sliderRow('Frequency', _waveFreq * 100, 1, 20, '', (v) => setState(() => _waveFreq = v / 100)),
        ],
        if (_effect == 'pulse')
          _sliderRow('Rate', _pulseRate, 0.5, 6, 'Hz', (v) => setState(() => _pulseRate = v)),
        if (_effect == 'ripple') ...[
          _sliderRow('Speed', _rippleSpeed, 0.5, 10, 'x', (v) => setState(() => _rippleSpeed = v)),
          const SizedBox(height: 12),
          _sliderRow('Density', _rippleFreq * 10, 1, 20, '', (v) => setState(() => _rippleFreq = v / 10)),
        ],
        if (_effect == 'glitch')
          _sliderRow('Intensity', _glitchInt, 1, 10, '', (v) => setState(() => _glitchInt = v), gold: true),
        if (_effect == 'fire')
          _sliderRow('Flicker', _fireFlicker * 10, 1, 10, '', (v) => setState(() => _fireFlicker = v / 10), gold: true),
        if (_effect == 'matrix')
          _sliderRow('Drop Speed', _matrixSpd, 1, 10, 'x', (v) => setState(() => _matrixSpd = v), gold: true),
      ]),
    );
  }

  Widget _buildInOutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('Entrance Animation'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _pill('None', _inAnim == 'none', () => setState(() => _inAnim = 'none')),
          _pill('Fade', _inAnim == 'fade', () => setState(() => _inAnim = 'fade')),
          _lockedOrPill('Slide',      _inAnim == 'slide',      () => setState(() => _inAnim = 'slide')),
          _lockedOrPill('Zoom',       _inAnim == 'zoom',       () => setState(() => _inAnim = 'zoom')),
          _lockedOrPill('Typewriter', _inAnim == 'typewriter', () => setState(() => _inAnim = 'typewriter')),
        ]),
        const SizedBox(height: 20),
        _label('Exit Animation'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _pill('None', _outAnim == 'none', () => setState(() => _outAnim = 'none')),
          _pill('Fade', _outAnim == 'fade', () => setState(() => _outAnim = 'fade')),
          _lockedOrPill('Slide', _outAnim == 'slide', () => setState(() => _outAnim = 'slide')),
          _lockedOrPill('Zoom',  _outAnim == 'zoom',  () => setState(() => _outAnim = 'zoom')),
          _lockedOrPill('Wipe',  _outAnim == 'wipe',  () => setState(() => _outAnim = 'wipe')),
        ]),
        const Divider(color: Color(0xFF111111), height: 32),
        _sliderRow('Transition Zone', _zoneRatio * 100, 5, 40, '%', (v) => setState(() => _zoneRatio = v / 100)),
      ]),
    );
  }

  Widget _buildPlusTab() {
    if (!_plusOn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('LEDSNAP+', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 6, color: Color(0xFFF5C842))),
            const SizedBox(height: 8),
            const Text(
              'Unlock pro features for arcade-grade LED experiences.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Color(0xFF555555), letterSpacing: 2, height: 1.8),
            ),
            const SizedBox(height: 16),
            ...['Glitch, Fire, Bounce & Matrix effects', 'Slide, Zoom & Typewriter in/out', 'Dot shapes - Square, Diamond, Rounded'].map((f) =>
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('+ ', style: TextStyle(color: Color(0xFFF5C842))),
                  Text(f, style: const TextStyle(fontSize: 10, color: Color(0xFF555555), letterSpacing: 1)),
                ]),
              )),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => setState(() => _plusOn = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFF5C842)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'UNLOCK PLUS - FREE DEMO',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 3, color: Color(0xFFF5C842)),
                ),
              ),
            ),
          ]),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('Dot Shape'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _shapeCard('circle',  'Circle',  Icons.circle),
            _shapeCard('square',  'Square',  Icons.square),
            _shapeCard('diamond', 'Diamond', Icons.diamond),
            _shapeCard('rounded', 'Rounded', Icons.rounded_corner),
          ],
        ),
      ]),
    );
  }

  Widget _shapeCard(String shape, String label, IconData icon) {
    final active = _dotShape == shape;
    return GestureDetector(
      onTap: () => setState(() => _dotShape = shape),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0E0C00) : const Color(0xFF0D0D0D),
          border: Border.all(color: active ? const Color(0xFFF5C842) : const Color(0xFF1A1A1A)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: active ? const Color(0xFFF5C842) : const Color(0xFF333333), size: 20),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 8, letterSpacing: 1,
            color: active ? const Color(0xFFF5C842) : const Color(0xFF444444))),
        ]),
      ),
    );
  }

  void _showColorPicker() {
    const colors = [
      Color(0xFFFF2200), Color(0xFFFF6600), Color(0xFFFFCC00),
      Color(0xFF00FF44), Color(0xFF00FFFF), Color(0xFF0066FF),
      Color(0xFFCC00FF), Color(0xFFFF00AA), Color(0xFFFFFFFF),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label('Pick Color'),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: colors.map((c) => GestureDetector(
              onTap: () { setState(() => _color = c); Navigator.pop(context); },
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _color == c ? Colors.white : Colors.transparent, width: 2),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 9, letterSpacing: 3, color: Color(0xFF3A3A3A))),
  );

  Widget _pill(String label, bool active, VoidCallback onTap, {bool gradient = false}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? const Color(0xFFFF2200) : const Color(0xFF1C1C1C)),
          gradient: gradient && active
              ? const LinearGradient(colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple])
              : null,
          color: gradient && active ? null : active ? const Color(0xFF1A0500) : const Color(0xFF0C0C0C),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2,
          color: gradient && active ? Colors.black : active ? const Color(0xFFFF2200) : const Color(0xFF3A3A3A),
        )),
      ),
    );
  }

  Widget _lockedOrPill(String label, bool active, VoidCallback onTap) {
    if (!_plusOn) {
      return Opacity(
        opacity: 0.35,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1C1C1C)),
            color: const Color(0xFF0C0C0C),
          ),
          child: Text('$label +', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: Color(0xFF3A3A3A))),
        ),
      );
    }
    return _pill(label, active, onTap);
  }

  Widget _slider(double val, double min, double max, ValueChanged<double> onChange) =>
    SliderTheme(
      data: const SliderThemeData(trackHeight: 2, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6)),
      child: Slider(value: val, min: min, max: max, onChanged: onChange),
    );

  Widget _sliderRow(String label, double val, double min, double max, String unit, ValueChanged<double> onChange, {bool gold = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, letterSpacing: 3, color: Color(0xFF3A3A3A))),
        Text('${val.toStringAsFixed(val < 10 ? 1 : 0)}$unit', style: const TextStyle(fontSize: 11, color: Color(0xFF555555))),
      ]),
      SliderTheme(
        data: SliderThemeData(
          trackHeight: 2,
          activeTrackColor:   gold ? const Color(0xFFF5C842) : const Color(0xFFFF2200),
          thumbColor:         gold ? const Color(0xFFF5C842) : const Color(0xFFFF2200),
          inactiveTrackColor: const Color(0xFF181818),
          overlayColor:       (gold ? const Color(0xFFF5C842) : const Color(0xFFFF2200)).withAlpha(40),
          thumbShape:         const RoundSliderThumbShape(enabledThumbRadius: 6),
        ),
        child: Slider(value: val.clamp(min, max), min: min, max: max, onChanged: onChange),
      ),
    ]);
  }

  Widget _outlineBtn(String label, Color color, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color),
          color: const Color(0xFF0D0D0D),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: color, fontFamily: 'Courier')),
      ),
    );
}
