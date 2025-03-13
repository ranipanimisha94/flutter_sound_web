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

import 'package:web/web.dart';
//import 'dart:typed_data';
import 'dart:typed_data' as t show Float32List;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

class ToStreamNode {
  late AudioWorkletNode workletNode;
  late tMessagePort messagePort;
  static bool alreadyInited = false;

  AudioWorkletNode delegate() => workletNode;

  /* ctor */
  AsyncWorkletNode(
    BaseAudioContext context,
    String name, {
    required int channelCount,
    required int numberOfInputs,
    required int numberOfOutputs,
  }) {
    workletNode = AudioWorkletNode(context, name);
    var m = (Message e) {
      var msg = e['msg'].toJS;
      String msgType = msg.getProperty('messageType'.toJS);
      switch (msgType) {
        case 'AUDIO_BUFFER_UNDERFLOW':
          int outputNo =
              (msg.getProperty('outputNo'.toJS) as JSNumber).toDartInt;
          _onAudioBufferUnderflow(outputNo);
          break;
        case 'RECEIVE_DATA': // Receive data from source to destination
          List<t.Float32List> data = msg.getProperty('data'.toJS);
          int inputNo = (msg.getProperty('inputNo'.toJS) as JSNumber).toDartInt;
          _onReceiveData(inputNo, data);
          break;
      }
    };
    messagePort = tMessagePort.fromDelegate(workletNode.port);
    messagePort.onmessage = m;
    //workletNode.port.onmessage = m;
  }

  void Function(int outputNo) _onAudioBufferUnderflow = (int outputNo) {};

  void Function(int outputNo, List<t.Float32List> data) _onReceiveData = (
    int outputNo,
    List<t.Float32List> data,
  ) {
    // Dummy
  };

  void connect(AudioNode node) {
    workletNode.connect(node);
  }

  //@override
  void onBufferUnderflow(void Function(int outputNo) f) =>
      _onAudioBufferUnderflow = f;

  ///@override
  void onReceiveData(void Function(int outputNo, List<t.Float32List> data) f) {
    _onReceiveData = f;
  }

  ///@override
  void send({int outputNo = 0, required List<t.Float32List> data}) {
    JSObject obj = JSObject();
    obj.setProperty('msgType'.toJS, 'SEND_DATA'.toJS);
    obj.setProperty('outputNo'.toJS, outputNo.toJS);
    JSFloat32Array d = _toJS(
      data,
    ); // Cannot use `data.toJS`. Don't know it does not compile
    obj.setProperty('data'.toJS, d);
    workletNode.port.postMessage(obj);
  }

  JSFloat32Array _toJS(List<t.Float32List> data) {
    JSFloat32Array r = JSFloat32Array();
    for (int i = 0; i < data.length; ++i) {
      r.add(data[i].toJS);
    }
    return r;
  }

  //@override
  void stop() {
    JSObject obj = JSObject();
    obj.setProperty('msgType'.toJS, 'STOP'.toJS);
    workletNode.port.postMessage(obj);
  }
}

// --------------------------------------------------------------------------------------------------

typedef MessageFn = void Function(Message msg);

typedef Message = dynamic;

class tMessagePort {
  MessagePort delegate;
  MessagePort getDelegate() => delegate;
  MessageFn f = (e) {
    //print('Dummy');
  };
  /* ctor */
  tMessagePort.fromDelegate(this.delegate);
  /* ctor */ // MessagePort() : delegate = w.MessagePort();

  //@override
  MessageFn get onmessage => f;

  //@override
  void postMessage(Message msg) => delegate.postMessage(msg);

  //@override
  set onmessage(f) {
    this.f = f;
    delegate.onmessage = rcvMessage.toJS;
  }

  void rcvMessage(MessageEvent e) {
    //    Map<String, dynamic> data = (e.data as JSObject).;
    Map<String, dynamic> map = {
      'msg': e.data,
      'origin': e.origin,
      'type': e.type,
    };
    f(map);
  }
}
