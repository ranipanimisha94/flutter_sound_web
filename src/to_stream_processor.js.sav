/*
 * Copyright 2024 Canardoux.
 *
 * This file is part of the τ project.
 *
 * τ is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 (GPL3), as published by
 * the Free Software Foundation.
 *
 * τ is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with τ.  If not, see <https://www.gnu.org/licenses/>.
 */


// The number of ouputs is either 0 or one. We do not handdle the case where number of outputs > 1

class ToStreamProcessorProcessor extends AudioWorkletProcessor {

  constructor(...args) {
    super(...args);
    this.port.onmessage = (e) => {
      //console.log('Rcv ' + e.data);
      //this.port.postMessage("pong (" + e.data + ")");
      //let msg = e.data;
      //let msgType = msg['msgType'];
      //let outputNo = msg['outputNo'];
      //let data = msg['data'];
      //switch (msgType)
      //{
        //case 'SEND_DATA': this.send(outputNo, data); break;
        //case 'STOP': this.stop(); break;
      //}

    };
  }



  receive(inNo, data)
  {
    this.port.postMessage({ 'messageType' : 'RECEIVE_DATA', 'inputNo' : inNo,  'data': data});
  }


  process(inputs, outputs, parameters) {

      let inNo = 0;
      inputs.forEach((input) => // For each input (Probably just one input)
      {
            this.receive(inNo, input);
            ++ inNo;
      });
      
      
    return true;
  }


}

// Actually just 4 processors registered. It can be changed.
registerProcessor("to-stream-processor-1", ToStreamProcessorProcessor);
registerProcessor("to-stream-processor-2", ToStreamProcessorProcessor);
registerProcessor("to-stream-processor-3", ToStreamProcessorProcessor);
registerProcessor("to-stream-processor-4", ToStreamProcessorProcessor);