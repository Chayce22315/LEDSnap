import 'dart:convert';

/// .ledbanner file format — JSON, readable by LEDSnap and ledsnap_pi.py
class LEDBannerModel {
  String text;
  String color;
  bool rainbow;
  double sizeRatio;
  double speed;
  bool flash;
  double flashRate;
  String effect;
  double waveAmp;
  double waveSpeed;
  double waveFreq;
  double pulseRate;
  double rippleSpeed;
  double rippleFreq;
  String inAnim;
  String outAnim;
  double zoneRatio;
  String dotShape;
  String name;

  LEDBannerModel({
    this.text = 'LEDSNAP',
    this.color = '#FF2200',
    this.rainbow = false,
    this.sizeRatio = 0.42,
    this.speed = 55,
    this.flash = false,
    this.flashRate = 3,
    this.effect = 'none',
    this.waveAmp = 4,
    this.waveSpeed = 2.5,
    this.waveFreq = 0.04,
    this.pulseRate = 1.5,
    this.rippleSpeed = 4,
    this.rippleFreq = 0.6,
    this.inAnim = 'none',
    this.outAnim = 'none',
    this.zoneRatio = 0.15,
    this.dotShape = 'circle',
    this.name = 'My Banner',
  });

  Map<String, dynamic> toJson() => {
        'version': '1.0',
        'format': 'ledbanner',
        'app': 'LEDSnap',
        'created': DateTime.now().toIso8601String(),
        'name': name,
        'text': text,
        'display': {'rows': 32, 'dotSize': 8, 'gap': 2},
        'style': {
          'color': rainbow ? 'rainbow' : color,
          'rainbow': rainbow,
          'sizeRatio': sizeRatio,
          'dotShape': dotShape,
        },
        'animation': {
          'type': flash ? 'flash_scroll' : 'scroll',
          'speed': speed,
          'flash': flash,
          'flashRate': flashRate,
        },
        'effects': {
          'effect': effect,
          'inAnim': inAnim,
          'outAnim': outAnim,
          'zoneRatio': zoneRatio,
          'waveAmp': waveAmp,
          'waveSpeed': waveSpeed,
          'waveFreq': waveFreq,
          'pulseRate': pulseRate,
          'rippleSpeed': rippleSpeed,
          'rippleFreq': rippleFreq,
        },
      };

  factory LEDBannerModel.fromJson(Map<String, dynamic> json) {
    if (json['format'] != 'ledbanner') {
      throw const FormatException('Not a valid .ledbanner file');
    }
    final style = (json['style'] as Map?)?.cast<String, dynamic>() ?? {};
    final anim  = (json['animation'] as Map?)?.cast<String, dynamic>() ?? {};
    final fx    = (json['effects'] as Map?)?.cast<String, dynamic>() ?? {};
    return LEDBannerModel(
      name:        json['name'] ?? 'My Banner',
      text:        json['text'] ?? '',
      rainbow:     style['rainbow'] == true,
      color:       style['rainbow'] == true ? '#FF2200' : (style['color'] ?? '#FF2200'),
      sizeRatio:   (style['sizeRatio'] ?? 0.42).toDouble(),
      dotShape:    style['dotShape'] ?? 'circle',
      speed:       (anim['speed'] ?? 55).toDouble(),
      flash:       anim['flash'] == true,
      flashRate:   (anim['flashRate'] ?? 3).toDouble(),
      effect:      fx['effect'] ?? 'none',
      inAnim:      fx['inAnim'] ?? 'none',
      outAnim:     fx['outAnim'] ?? 'none',
      zoneRatio:   (fx['zoneRatio'] ?? 0.15).toDouble(),
      waveAmp:     (fx['waveAmp'] ?? 4).toDouble(),
      waveSpeed:   (fx['waveSpeed'] ?? 2.5).toDouble(),
      waveFreq:    (fx['waveFreq'] ?? 0.04).toDouble(),
      pulseRate:   (fx['pulseRate'] ?? 1.5).toDouble(),
      rippleSpeed: (fx['rippleSpeed'] ?? 4).toDouble(),
      rippleFreq:  (fx['rippleFreq'] ?? 0.6).toDouble(),
    );
  }

  String toFileContent() => const JsonEncoder.withIndent('  ').convert(toJson());
}
