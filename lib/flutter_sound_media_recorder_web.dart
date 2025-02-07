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
import 'package:flutter_sound_platform_interface/flutter_sound_recorder_platform_interface.dart';
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
//import 'flutter_sound_web.dart' show mime_types;
//import 'dart:js_interop';
//import 'flutter_sound_web.dart';
import 'package:tau_web/tau_web.dart';
import 'package:etau/etau.dart';

class FlutterSoundMediaRecorderWeb {
  ///StreamSink<Uint8List>? streamSink;
  FlutterSoundRecorderCallback? callback;

  StreamSink<Uint8List>? toStream;
  StreamSink<List<Float32List>>? toStreamFloat32;
  StreamSink<List<Int16List>>? toStreamInt16;

  // The Audio Context
  AudioContext? audioCtx;

  Future<void> startRecorderToStream(
    FlutterSoundRecorderCallback callback, {
    required Codec codec,
    StreamSink<Uint8List>? toStream,
    StreamSink<List<Float32List>>? toStreamFloat32,
    StreamSink<List<Int16List>>? toStreamInt16,
    AudioSource? audioSource,
    Duration timeSlice = Duration.zero,
    int sampleRate = 16000,
    int numChannels = 1,
    int bitRate = 16000,
    int bufferSize = 8192,
    bool enableVoiceProcessing = false,
  }) async {
    this.callback = callback;
    this.toStream = toStream;
    this.toStreamFloat32 = toStreamFloat32;
    this.toStreamInt16 = toStreamInt16;

    callback.log(Level.debug, 'Start Recorder to Stream');
    await tau().init();
    assert(audioCtx == null);

    audioCtx = tau().newAudioContext();
    await audioCtx!.audioWorklet
        .addModule("./assets/packages/tau_web/assets/js/async_processor.js");

    AudioWorkletNodeOptions opt = tau().newAudioWorkletNodeOptions(
      channelCountMode: 'explicit',
      channelCount: numChannels,
      numberOfInputs: 1,
      numberOfOutputs: 0,
      outputChannelCount: [],
    );
    var streamNode =
        tau().newAsyncWorkletNode(audioCtx!, "async-processor-1", opt);
    streamNode.onReceiveData((int inputNo, List<Float32List> data) {
      if (data.length > 0) {
        toStreamFloat32!.add(data);
      }
    });
    streamNode.onBufferUnderflow((int outputNo) {
      tau().logger().d('onBufferUnderflow($outputNo)');
    });

    var mediaStream = await tau().getDevices().getUserMedia();
    var mic = audioCtx!.createMediaStreamSource(mediaStream);
    mic.connect(streamNode);

    callback.startRecorderCompleted(RecorderState.isRecording.index, true);
  }

  void requestData() {
    callback!.log(Level.debug, 'requestData');
  }

  void error(web.Event event) {
    callback!.log(Level.debug, 'error');
  }

  Future<void> stopRecorder() async {
    callback!.log(Level.debug, 'stop');
    callback!.stopRecorderCompleted(0, true, '');
    audioCtx?.close();
    audioCtx = null;
  }

  Future<void> pauseRecorder() async {
    callback!.log(Level.debug, 'pauseRecorder');
  }

  Future<void> resumeRecorder() async {
    callback!.log(Level.debug, 'pauseRecorder');
  }
}
