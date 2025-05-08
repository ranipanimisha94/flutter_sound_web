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
import 'dart:math';
import 'package:flutter_sound_platform_interface/flutter_sound_platform_interface.dart';
import 'package:flutter_sound_platform_interface/flutter_sound_recorder_platform_interface.dart';
import 'dart:typed_data' as t
    show Float32List, Uint8List, Int16List, ByteBuffer;
import 'package:logger/logger.dart' show Level;
import 'package:web/web.dart' as web;
//import 'package:tau_web/tau_web.dart';
//import 'package:etau/etau.dart';
import 'dart:js_interop';
//import 'dart:js_util';
import 'package:web/web.dart';

typedef Message = dynamic;

class FlutterSoundMediaRecorderWeb {
  bool javascriptScriptLoaded = false;

  ///StreamSink<Uint8List>? streamSink;
  FlutterSoundRecorderCallback? callback;
  //Duration? _subscriptionDuration = Duration.zero;
  double maxAmplitude = 0;
  double previousAmplitude = 0;
  Timer? onProgressTimer;

  StreamSink<t.Uint8List>? toStream;
  StreamSink<List<t.Float32List>>? toStreamFloat32;
  StreamSink<List<t.Int16List>>? toStreamInt16;

  // The Audio Context
  AudioContext? audioCtx;

  MediaStreamAudioSourceNode? mic = null;

  void interleaves16(
    FlutterSoundRecorderCallback callBack,
    List<t.ByteBuffer> data,
  ) {
    int ln = data[0].asFloat32List().length;
    int channelCount = data.length;
    t.Int16List r = t.Int16List(data.length * ln);
    for (int channel = 0; channel < data.length; ++channel) {
      t.Float32List v = data[channel].asFloat32List();
      for (int i = 0; i < ln; ++i) {
        int x = (v[i] * 32767).round();
        r[i * channelCount + channel] = x;
      }
    }
    var rr = r.buffer.asUint8List();
    callBack.interleavedRecording(data: rr);
  }

  void interleaves32(
    FlutterSoundRecorderCallback callBack,
    List<t.ByteBuffer> data,
  ) {
    int ln = data[0].asFloat32List().length;
    int channelCount = data.length;
    t.Float32List r = t.Float32List(data.length * ln);
    for (int channel = 0; channel < data.length; ++channel) {
      t.Float32List v = data[channel].asFloat32List();
      for (int i = 0; i < ln; ++i) {
        r[i * channelCount + channel] = v[i];
      }
    }
    var rr = r.buffer.asUint8List();
    callBack.interleavedRecording(data: rr);
  }

  void planMode16(
    FlutterSoundRecorderCallback callBack,
    List<t.ByteBuffer> data,
  ) {
    int ln = data[0].asFloat32List().length;
    int channelCount = data.length;
    List<t.Int16List> r = [];
    for (int channel = 0; channel < data.length; ++channel) {
      t.Float32List v = data[channel].asFloat32List();
      t.Int16List rr = t.Int16List(ln);
      for (int i = 0; i < ln; ++i) {
        int x = (v[i] * 32767).round();
        rr[i] = x;
      }
      r.add(rr);
    }
    callBack.recordingDataInt16(data: r);
  }

  void planMode32(
    FlutterSoundRecorderCallback callBack,
    List<t.ByteBuffer> data,
  ) {
    int ln = data[0].asFloat32List().length;
    int channelCount = data.length;
    List<t.Float32List> r = [];
    for (int channel = 0; channel < data.length; ++channel) {
      t.Float32List v = data[channel].asFloat32List();
      r.add(v);
    }
    callBack.recordingDataFloat32(data: r);
  }

  Future<void> startRecorderToStream(
    FlutterSoundRecorderCallback callback, {
    required Codec codec,
    StreamSink<t.Uint8List>? toStream,
    StreamSink<List<t.Float32List>>? toStreamFloat32,
    StreamSink<List<t.Int16List>>? toStreamInt16,
    AudioSource? audioSource,
    Duration timeSlice = Duration.zero,
    int sampleRate = 16000,
    int numChannels = 1,
    int bitRate = 16000,
    int bufferSize = 8192,
    bool enableVoiceProcessing = false,
    required bool interleaved,
  }) async {
    this.callback = callback;
    this.toStream = toStream;
    this.toStreamFloat32 = toStreamFloat32;
    this.toStreamInt16 = toStreamInt16;

    callback.log(Level.debug, 'Start Recorder to Stream');
    //await AsyncWorkletNode.init();
    assert(audioCtx == null);
    AudioContextOptions audioCtxOptions = AudioContextOptions(
      sampleRate: sampleRate,
    );
    audioCtx = AudioContext(audioCtxOptions);

    /*
    var dest = audioCtx!.createMediaStreamDestination();
    const Map options = {
    'audioBitsPerSecond': 128000,
    'mimeType': "audio/pcm",};

    var mediaRecorder = MediaRecorder(dest.stream, );
    //mediaRecorder.mimeType = "audio/pcm";
    mediaRecorder.ondataavailable =
        (JSObject e) {
          Blob x = getProperty(e, 'data');
          var stream = x.stream();
          var xx = x.arrayBuffer().toDart;
          xx.then( ( v) {
            var xxx = v.toDart;
            var xxxx = xxx.asUint8List();
            var yyyy = xxx.asInt16List();
            var zzzz = xxx.asFloat32List();
            callback.interleavedRecording(data: xxxx);
            print ('xxx');
          });
          print('toto');
        }.toJS;
    ;
     */

    if (!javascriptScriptLoaded) {
      await audioCtx!.audioWorklet
          .addModule(
            "./assets/packages/flutter_sound_web/src/flutter_sound_stream_processor.js",
          )
          .toDart;
      javascriptScriptLoaded = true;
    }
    AudioWorkletNodeOptions options = AudioWorkletNodeOptions(
      channelCount: numChannels,
      numberOfInputs: 1,
      numberOfOutputs: 0,
    );
    var streamNode = AudioWorkletNode(
      audioCtx!,
      "flutter-sound-stream-processor",
      options,
    );

    var m = (Map<String, JSAny> e) {
      //print('titi');
      /*
        var msg = e['msg'].toJS;
        String msgType = msg.getProperty('messageType'.toJS);
        switch (msgType) {
          case 'AUDIO_BUFFER_UNDERFLOW':
            int outputNo =
                (msg.getProperty('outputNo'.toJS) as JSNumber).toDartInt;
            //_onAudioBufferUnderflow(outputNo);
            break;
          case 'RECEIVE_DATA': // Receive data from source to destination
            List<t.Float32List> data = msg.getProperty('data'.toJS);
            int inputNo = (msg.getProperty('inputNo'.toJS) as JSNumber).toDartInt;
            //_onReceiveData(inputNo, data);
            break;
        }

         */
    };
    //messagePort = tMessagePort.fromDelegate(workletNode.port);
    //messagePort.onmessage = m;

    //streamNode.port.onmessageerror =  (MessageEvent e) {
    //callback.log(Level.error, 'Error on receiving a message on streamNode port');
    //throw Exception('Error on receiving a message on streamNode port');
    //}.toJS;

    void receiveData(Map msg) {
      var xx = msg['data'];
      var k1 = msg['msgType'];
      var k2 = msg['inputNo'];
      var z = xx as JSArray;
      var zz = z.toDart;
      var bb = zz as List;
      if (bb.length > 0) {
        //for (Float32List ff in bb) {
        //Float32List pp = ff!.dartify();
        //Float32List ppp = ff!.toDart;
        //var jj = pp.buffer;
        //var g = ff.toDart;
        //var gg = ff.buffer;
        //print ('riri');
        //}
        List<t.ByteBuffer> r = [];
        for (int channel = 0; channel < bb.length; ++channel) {
          var c = bb[channel];
          var cc = c as t.Float32List;
          var ccc = cc.buffer;
          r.add(ccc);
          //var hhh = ccc.asUint8List();
          //callback.interleavedRecording(data: hhh);
          ///r.add(cc);
        }
        computeDbMaxLevel(r);
        if (interleaved) {
          if (codec == Codec.pcm16) {
            interleaves16(callback, r);
          } else {
            interleaves32(callback, r);
          }
        } else {
          if (codec == Codec.pcm16) {
            planMode16(callback, r);
          } else {
            planMode32(callback, r);
          }
        }
        //callback.interleavedRecording(data: r[0]);
        var c = bb[0];
        var cc = c as Float32List;
        //callback.interleavedRecording(data: cc);
        //var zzz = bb as List<Float32List>;
        //var ff = zz as List<Float32List>;
        //var ff = bb.dartify()  as List<Float32List>;
        //print ('mimi');
      }
    }

    streamNode.port.onmessage = (MessageEvent e) {
      var x = e.type;
      var y = e.origin;
      var d = e.data;
      var msg = d!.dartify() as Map;
      var msgType = msg['msgType'];
      switch (msgType) {
        case 'RECEIVE_DATA':
          receiveData(msg);
          break;
      }
      //int inputNo = (d!.getProperty('inputNo'.toJS) as JSNumber).toDartInt;
      //print('zozo');
    }.toJS;

    //List<t.Float32List> data = xx.getProperty('data'.toJS);
    //print('toto');

    var constrains = MediaStreamConstraints(
      audio: true.toJS,
      video: false.toJS,
    );
    MediaDevices mds = web.window.navigator.mediaDevices;
    var mediaStream = await mds.getUserMedia(constrains).toDart;
    mic = audioCtx!.createMediaStreamSource(mediaStream);
    setOnProgress();
    mic?.connect(streamNode);
    //mediaRecorder.start(1000);
    callback.startRecorderCompleted(RecorderState.isRecording.index, true);
  }

  void requestData() {
    // TODO
    callback!.log(Level.debug, 'requestData');
  }

  /*
  void error(web.Event event) {
    callback!.log(Level.debug, 'error');
  }

 */

  Future<void> stopRecorder() async {
    callback!.log(Level.debug, 'stop');
    callback!.stopRecorderCompleted(0, true, '');
    if (audioCtx != null && audioCtx!.state == 'running') {
      closeOnProgress();
    }
    await audioCtx?.close().toDart;
    audioCtx = null;
    if(mic!=null){
      mic?.mediaStream.getTracks().toDart.forEach((track)=>track.stop());
      mic = null;
    }
    //streamNode = null;
  }

  Future<void> pauseRecorder() async {
    closeOnProgress();
    audioCtx!.suspend();
    callback!.log(Level.debug, 'pauseRecorder');
  }

  Future<void> resumeRecorder() async {
    setOnProgress();
    audioCtx!.resume();
    callback!.log(Level.debug, 'resumeRecorder');
  }

  void closeOnProgress() {
    if (onProgressTimer != null) {
      onProgressTimer!.cancel();
      onProgressTimer = null;
    }
  }

  void setOnProgress() {
    closeOnProgress();
    if (audioCtx != null &&
        audioCtx!.state == 'running' &&
        callback!.getSubscriptionDuration() != null &&
        callback!.getSubscriptionDuration() != Duration.zero) {
      maxAmplitude = 0;
      onProgressTimer = Timer.periodic(callback!.getSubscriptionDuration(), (
        Timer timer,
      ) {
        callback?.updateRecorderProgress(
          duration: 0,
          dbPeakLevel: toDB(previousAmplitude),
        );
        previousAmplitude = maxAmplitude;
        maxAmplitude = 0;
      });
    }
  }

  void setSubscriptionDuration(Duration? duration) {
    //_subscriptionDuration = duration;
    setOnProgress();
  }

  void computeDbMaxLevel(List<t.ByteBuffer> buffer) {
    if (onProgressTimer == null) {
      return;
    }
    double m = 0;
    for (int channel = 0; channel < buffer.length; ++channel) {
      t.Float32List v = buffer[channel].asFloat32List();
      for (int i = 0; i < v.length; ++i) {
        double curSample = v[i].abs();

        if (curSample > 1.0 || curSample < -1.0) {
          curSample = 0;
        }
        if (curSample > m) {
          m = curSample;
        }
      }
    }
    if (m > maxAmplitude) {
      maxAmplitude = m;
    }
  }

  double toDB(double amplitude) {
    double max = amplitude.abs();
    if (max == 0) {
      // if the microphone is off we get 0 for the amplitude which causes
      // db to be infinite.
      return 0;
    }
    max *= 32768;
    // Calculate db based on the following article.
    // https://stackoverflow.com/questions/10655703/what-does-androids-getmaxamplitude-function-for-the-mediarecorder-actually-gi
    //
    double ref_pressure = 51805.5336;
    double p = max / ref_pressure;
    double p0 = 0.0002;
    double l = log(p / p0) / 2.30258509299;

    double db = 20.0 * l;

    return db;
  }
}

/*
//20 log (P/Pref)
20*log10(x) = log2(x) / log2(10)

ln(10) = 2.30258509299
------
float rms(float* samples, int num_samples) {

float sum = 0;

for (int i = 0; i < num_samples; i++) {

sum += samples[i] * samples[i];

}

return sqrt(sum / num_samples);

}

You can then use the RMS value to convert the sound intensity level to decibels (dB) using the following formula:

float intensity_level_dB = 20.0f * log10(rms / reference_level);

*/
