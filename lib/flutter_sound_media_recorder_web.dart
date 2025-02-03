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
  //StreamSubscription<Event>? sub;
  //web.MediaRecorder? mediaRecorder;
  ///StreamSink<Uint8List>? streamSink;
  FlutterSoundRecorderCallback? callback;
  //var recordedChunks = [];

  StreamSink<Uint8List>? toStream;
  StreamSink<List<Float32List>>? toStreamFloat32;
  StreamSink<List<Int16List>>? toStreamInt16;

  // The Audio Context
  AudioContext? audioCtx;

  Future<void> startRecorderToStream(
    FlutterSoundRecorderCallback callback, {
    //String? path,
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
    /*
    if (codec != Codec.pcm16 && codec != Codec.pcmFloat32) {
      return _startRecorderToStreamCodec(
        callback,
        codec: codec,
        toStream: toStream,
        //toStreamFloat32: toStreamFloat32,
        //toStreamInt16: toStreamInt16,
        audioSource: audioSource,
        timeSlice: timeSlice,
        bitRate: bitRate,
        //sampleRate: sampleRate,
        numChannels: numChannels,
        bufferSize: bufferSize,
      );
    }

     */

    //if (toStream != null) {
    //numChannels = 1;
    //}
    callback.log(Level.debug, 'Start Recorder to Stream');
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
      numberOfInputs: 1,
      numberOfOutputs: 0,
      outputChannelCount: [],
    );
    var streamNode =
        tau().newAsyncWorkletNode(audioCtx!, "async-processor-1", opt);
    //source = audioCtx!.createBufferSource();
    //source!.buffer = audioBuffer;
    streamNode.onReceiveData((int inputNo, List<Float32List> data) {
      //streamNode.send(outputNo: inputNo, data: data);
      // Add to stream sink!
      if (data.length > 0) {
        toStreamFloat32!.add(data);
      }
    });
    streamNode.onBufferUnderflow((int outputNo) {
      //hitStopButton();
      tau().logger().d('onBufferUnderflow($outputNo)');
    });
    //source!.onended = hitStopButton;
    //streamNode.connect(audioCtx!.destination);

    var mediaStream = await tau().getDevices().getUserMedia();
    var mic = audioCtx!.createMediaStreamSource(mediaStream);
    //pannerNode = audioCtx!.createStereoPanner();
    //pannerNode!.pan.value = pannerValue;
    mic.connect(streamNode);
    //pannerNode!.connect(dest!);

    //streamNode!.start();

    /*
    AudioDestinationNode dest = audioCtx!.destination!;
    final html.MediaStream stream = await html.window.navigator.mediaDevices!
        .getUserMedia({'video': false, 'audio': true});
    source = audioCtx!.createMediaStreamSource(stream);
    audioProcessor =
        audioCtx!.createScriptProcessor(bufferSize, numChannels, 1);
    Stream<AudioProcessingEvent> audioStream = audioProcessor!.onAudioProcess;
    sub = audioStream.listen(
      (AudioProcessingEvent event) {
        List<Int16List> bi = [];
        List<Float32List> bf = [];
        for (int channel = 0; channel < numChannels; ++channel) {
          Float32List buf = event!.inputBuffer!.getChannelData(channel);
          int ln = buf.length;
          if (codec ==
              Codec
                  .pcmFloat32) // Actually, we do not handle the case where toStream is specified. This can be done if necessary
          {
            assert(toStreamFloat32 != null);
            bf.add(buf);
          } else if (codec == Codec.pcm16 && toStreamInt16 != null) {
            Int16List bufi = Int16List(ln);
            for (int i = 0; i < ln; ++i) {
              bufi[i] = (buf[i] * 32768).floor();
            }
            bi.add(bufi);
            //toStreamInt16.add(bufi);
          } else if (codec == Codec.pcm16 && toStream != null) {
            Uint8List bufu = Uint8List(ln * 2);
            for (int i = 0; i < ln; ++i) {
              int x = (buf[i] * 32768).floor();
              bufu[2 * i + 1] = x >> 8;
              bufu[2 * i] = x & 0xff;
            }
            toStream.add(bufu);
          }
        }
        if (codec ==
            Codec
                .pcmFloat32) // Actually, we do not handle the case where toStream is specified. This can be done if necessary
        {
          toStreamFloat32!.add(bf);
        } else if (codec == Codec.pcm16 && toStreamInt16 != null) {
          toStreamInt16.add(bi);
        }
      },
    );
//    callback.log(Level.debug, 'audio event ');
    source!.connectNode(audioProcessor!);
    audioProcessor!.connectNode(dest); // Why is it necessary ?
     */
    callback.startRecorderCompleted(RecorderState.isRecording.index, true);
  }

  void requestData(
      //FlutterSoundRecorderCallback callback,
      ) {
    callback!.log(Level.debug, 'requestData');
  }

  void error(web.Event event) {
    callback!.log(Level.debug, 'error');
  }

  /*
  void stop(web.Event event) {
    callback!.log(Level.debug, 'stop');
    callback!.stopRecorderCompleted(0, true, '');
    //recordedChunks = [];
    //streamSink = null;
    //mediaRecorder = null;
    // mic.disconnect();
    audioCtx?.close();
    audioCtx = null;
  }
*/

  /*
  void start(web.Event event) {
    callback!.log(Level.debug, 'start');
  }

  void pause(web.Event event) {
    callback!.log(Level.debug, 'pause');
  }

  void resume(web.Event event) {
    callback!.log(Level.debug, 'resume');
  }
  
   */

  /*
  void dataAvailable(web.Event event) async {
    if (event is web.BlobEvent) {
      callback!.log(Level.debug, 'BlobEvent');
      var jsArrayBuffer = await event.data.arrayBuffer().toDart;
      var byteBuffer = jsArrayBuffer.toDart.asUint8List(0);
      //streamSink!.add(byteBuffer);
    } else {
      callback!.log(Level.debug, 'Unexpected event');
    }
  }
  
   */

  /*
  Future<void> _startRecorderToStreamCodec(
    FlutterSoundRecorderCallback cb, {
    required Codec codec,
    StreamSink<Uint8List>? toStream,
    AudioSource? audioSource,
    Duration timeSlice = Duration.zero,
    int numChannels = 1,
    int bitRate = 16000,
    int bufferSize = 8192,
  }) async {
    callback = cb;
    callback!.log(Level.debug, 'Start Recorder to Stream-Codec');
    var t = true.toJS;
    web.MediaStreamConstraints contraints =
        web.MediaStreamConstraints(audio: t);
    final web.MediaStream stream = await web.window.navigator.mediaDevices
        .getUserMedia(contraints)
        .toDart; // The mic
    web.MediaRecorderOptions options = web.MediaRecorderOptions(
      mimeType: mime_types[codec.index],
      audioBitsPerSecond: bitRate,
    );
    mediaRecorder = new web.MediaRecorder(stream, options);
    streamSink = toStream;
    //int toto = mediaRecorder!.audioBitsPerSecond!;
    //String titi = mediaRecorder!.mimeType!;

    mediaRecorder!.ondataavailable = dataAvailable.toJS;
    mediaRecorder!.onstart = start.toJS;
    mediaRecorder!.onpause = pause.toJS;
    mediaRecorder!.onresume = resume.toJS;
    mediaRecorder!.onerror = error.toJS;
    mediaRecorder!.onstop = stop.toJS;

    //if (timeSlice == Duration.zero)
    //timeSlice = null;
    if (timeSlice != Duration.zero) {
      mediaRecorder!.start(timeSlice.inMilliseconds);
    } else {
      mediaRecorder!.start();
    }
    callback!.startRecorderCompleted(RecorderState.isRecording.index, true);
  }

   */

  Future<void> stopRecorder(
      //FlutterSoundRecorderCallback callback,
      ) async {
    //mediaRecorder!.requestData();
    //mediaRecorder!.stop();
    callback!.log(Level.debug, 'stop');
    callback!.stopRecorderCompleted(0, true, '');
    //recordedChunks = [];
    //streamSink = null;
    //mediaRecorder = null;
    // mic.disconnect();
    audioCtx?.close();
    audioCtx = null;
  }

  Future<void> pauseRecorder(
      //FlutterSoundRecorderCallback callback,
      ) async {
    //mediaRecorder!.pause();
    callback!.log(Level.debug, 'pauseRecorder');
  }

  Future<void> resumeRecorder(
      //FlutterSoundRecorderCallback callback,
      ) async {
    //mediaRecorder!.resume();
    callback!.log(Level.debug, 'pauseRecorder');
  }
}
/*
void start(web.Event event) {
  callback!.log(Level.debug, 'start');
}

void pause(web.Event event) {
  callback!.log(Level.debug, 'pause');
}

void resume(web.Event event) {
  callback!.log(Level.debug, 'resume');
}
*/
