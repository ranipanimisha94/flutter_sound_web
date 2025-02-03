/*
 * Copyright 2018, 2019, 2020 Dooboolab.
 * Copyright 2021, 2022, 2023, 2024 Canardoux.
 *
 * This file is part of Flutter-Sound.
 *
 * Flutter-Sound is free software: you can redistribute it and/or modify
 * it under the terms of the Mozilla Public License version 2 (MPL-2.0),
 * as published by the Mozilla organization.
 *
 * Flutter-Sound is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * MPL General Public License for more details.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

import 'dart:async';
import 'package:flutter_sound_platform_interface/flutter_sound_platform_interface.dart';
import 'package:flutter_sound_platform_interface/flutter_sound_player_platform_interface.dart';

//import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'dart:typed_data';
import 'package:logger/logger.dart' show Level;
import 'package:web/web.dart' as web;
//import 'dart:html';
//import 'package:js/js.dart' as js;
//import 'dart:html' as html;
//import 'dart:web_audio';
//import 'flutter_sound_recorder_web.dart';
//import 'dart:js';
import 'flutter_sound_web.dart' show mime_types;
import 'dart:js_interop';
//import 'flutter_sound_web.dart';
import 'package:tau_web/tau_web.dart';
import 'package:etau/etau.dart';

class FlutterSoundMediaPlayerWeb {
  AudioContext? audioCtx;
  AsyncWorkletNode? streamNode;
  FlutterSoundPlayerCallback? callback;

  Future<int> startPlayerFromStream(
    FlutterSoundPlayerCallback callback, {
    Codec codec = Codec.pcm16,
    bool interleaved = true,
    int numChannels = 1,
    int sampleRate = 16000,
    int bufferSize = 8192,
    //TWhenFinished? whenFinished,
  }) async {
    this.callback = callback;
    if (codec == Codec.pcmFloat32 && !interleaved) {
      // Actually this is the only case implemented {
      callback.log(Level.debug, 'Start startPlayerFromStream to Stream');
      await tau().init();
      assert(audioCtx == null);

      audioCtx = tau().newAudioContext();
      await audioCtx!.audioWorklet
          .addModule("./assets/packages/tau_web/assets/js/async_processor.js");
      //audioBuffer = await loadAudio();
      //ByteData asset = await rootBundle.load(pcmAsset);

      //var audioBuffer = await audioCtx!.decodeAudioData( asset.buffer);

      AudioWorkletNodeOptions opt = tau().newAudioWorkletNodeOptions(
        channelCountMode: 'explicit',
        channelCount: numChannels,
        numberOfInputs: 0,
        numberOfOutputs: 1,
        outputChannelCount: [numChannels],
      );
      streamNode =
          tau().newAsyncWorkletNode(audioCtx!, "async-processor-1", opt);
      streamNode!.onBufferUnderflow((int outputNo) {
        callback.needSomeFood(0);
        tau().logger().d('onBufferUnderflow($outputNo)');
      });

      streamNode!.connect(audioCtx!.destination);
      callback.startPlayerCompleted(1 /*PlayerState.playing.index*/, true, 0);
      return 1; //PlayerState.playing.index; // PlayerState.isPlaying;
    } else {
      return 0; // PlayerState.isStopped;
    }
  }

  Future<int> stopPlayer() async {
    //recordedChunks = [];
    //streamSink = null;
    //mediaRecorder = null;
    // mic.disconnect();
    streamNode?.stop();
    //streamNode?.disconnect();
    await audioCtx?.close();
    audioCtx = null;
    streamNode = null;
    callback!.log(Level.debug, 'stop');
    callback!.stopPlayerCompleted(0, true);
    return 0; // PlayerState.stopped.index; // PlayerState.isStopped;
  }

  Future<int> feed({
    required Uint8List data,
  }) async {
    return -1;
  }

  Future<int> feedFloat32({
    required List<Float32List> data,
  }) async {
    streamNode!.send(outputNo: 0, data: data);
    return 0; // Length written
  }

  Future<int> feedInt16({required List<Int16List> data}) async {
    return -1;
  }

  Future<int> pausePlayer() async {
    return -1;
  }

  Future<int> resumePlayer() async {
    return -1;
  }

  Future<int> setVolume({required double volume}) async {
    return -1;
  }

  Future<int> setVolumePan({double? volume, double? pan}) async {
    return -1;
  }

  Future<int> setSpeed({required double speed}) async {
    return -1;
  }
}
