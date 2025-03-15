/*
 * Copyright 2024 Canardoux.
 *
 * This file is part of the Flutter Sound project.
 *
 * Flutter Sound is free software: you can redistribute it and/or modify
 * it under the terms of the Mozilla Public License version 2 (MPL2), as published by
 * the Mozilla organization..
 *
 * Flutter Sound is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the Mozilla Public License
 * along with Flutter Sound.  If not, see <https://www.gnu.org/licenses/>.
 */


// The number of ouputs is either 0 or one. We do not handdle the case where number of outputs > 1

class FlutterSoundStreamProcessor extends AudioWorkletProcessor {

  constructor(...args) {
    super(...args);
    this.MIN_WAITING_LN = 1024;
    this.isPlaying = false;
    this.isFloat32 = true;
    this.nbrChannels = 1;
    this.isInterleaved = false;
    this.dataList = [];
    var me = this;
    this.port.onmessage = (e) => {
        let msg = e['data'];
        //console.log('Rcv ' + e.data);
        //this.port.postMessage("pong (" + e.data + ")");
        //let msg = e.data;
        let msgType = msg['msgType'];
        //let outputNo = msg['outputNo'];
        let data = msg['data'];
        switch (msgType)
        {
            case 'SEND_FEED_UINT8':
            case 'SEND_FEED_I16':
            case 'SEND_FEED_F32': me.dataList.push(data); break;
            case 'START_PLAYER': me.startPlayer(msg); break;
            //case 'STOP': this.stop(); break;
        }
    };
  }



    startPlayer(msg)
    {
        this.isFloat32 = msg['isFloat32'];
        this.nbrChannels = msg['nbrChannels'];
        this.isInterleaved = msg['isInterleaved'];
    }

  receive(inNo, data)
  {
    this.port.postMessage({ 'msgType' : 'RECEIVE_DATA', 'inputNo' : inNo,  'data': data});
  }


  totalLn() {
    let r = 0;
    for (let chunk in this.dataList) {
        r += chunk[0].length; // First channel
    }
    return r;
  }

  uninterleaved(chunk, nbrChannels)
  {
        let view = new DataView(chunk.buffer)
        let frameSize = chunk.length / nbrChannels;
        if (frameSize != Math.floor(frameSize))
        {
            this.port.postMessage({ 'msgType' : 'ERROR', 'message': 'Chunk size is not a multiple of nbrChannels'});
            frameSize = Math.floor(frameSize);
        }
        let r = [];
        for (let channel = 0; channel < nbrChannels; ++channel)
        {
             let x = [];
             x.length = frameSize;
             if (this.isFloat32)
             {
                 for (let i = 0; i < frameSize; ++i)
                 {
                    x[i] = view.getFloat32(4 * chunk[i * nbrChannels + channel]);
                 }

             } else
             {
                 for (let i = 0; i < frameSize; ++i)
                 {
                    x[i] = view.getInt16(2 * chunk[i * nbrChannels + channel]);
                 }
             }
             r.push(x);
        }
        return r;
  }

  fillOutput(data, access, isInterleaved)
  {

    let frameSize = data[0].length; // Probably 128
    let pd = 0;
    while (pd < frameSize)
    {
        if (this.dataList.length == 0)
        {
            if (this.isPlaying)
            {
                this.port.postMessage({ 'msgType' : 'NEED_SOME_FOOD' });
                this.port.postMessage({ 'msgType' : 'BUFFER_UNDERFLOW' });
            }
            this.isPlaying = false;
            return; // Nothing more to play
        }
        this.isPlaying = true;
        let chunk = this.dataList[0];
        if (isInterleaved)
        {
             chunk = this.uninterleaved(chunk, this.nbrChannels);
        }
        let nbrChannel = chunk.length;
        if (nbrChannel > data.length)
        {
            nbrChannel = data.length;
        }
        let lnx = chunk[0].length;
        if (lnx > frameSize - pd)
        {
            lnx = frameSize - pd; // We have enough data to play
        }
        for (let channel = 0; channel < nbrChannel; ++channel)
        {
            for (let i = 0; i < lnx; ++i)
            {
                data[channel][i] = access(chunk, channel, i); // chunk[channel][i];
            }
        }
        let remain = chunk[0].length - lnx;
        if (remain == 0)
        {
            this.dataList.shift();
        } else
        if (!isInterleaved)
        {
            for (channel = 0; channel < nbrChannel; ++channel)
            {
                chunk[channel] = chunk[channel].slice(remain);
            }
            this.dataList[0] = chunk;
        } else
        if (this.isFloat32)
        {
            this.dataList[0] = this.dataList[0].slice(4 * remain * nbrChannel);
        } else
        {
            this.dataList[0] = this.dataList[0].slice(2 * remain * nbrChannel);
        }

        pd += lnx;
    }
  }

  send(outNo, data)
  {
  /*
    for (let channel = 0; channel < data.length; ++ channel)
    {
        for (let i = 0; i < data.length; ++i)
        {
            let x = Math.random() * 2 - 1;
            data[channel][i] = x;
        }
    }
    */

    //if (this.isInterleaved)
    //{
    //} else
    {
        if (this.isFloat32)
        {
            this.fillOutput(data, (chunk, channel, i) => chunk[channel][i], this.isInterleaved);
        } else
        {
            this.fillOutput(data, (chunk, channel, i) => chunk[channel][i] / 32768, this.isInterleaved);
        }
    }
    if (this.totalLn() < this.MIN_WAITING_LN)
    {
        this.port.postMessage({ 'msgType' : 'NEED_SOME_FOOD' });
    }
  }


  process(inputs, outputs, parameters) {

      let inNo = 0;
      inputs.forEach((input) => // For each input (Probably just one or zero input)
      {
            this.receive(inNo, input);
            ++ inNo;
      });
      
      let outNo = 0;
      outputs.forEach((output) => // For each output (Probably just one or zero output)
      {
            this.send(outNo, output);
            ++ outNo;
      });


    return true;
  }



}

registerProcessor("flutter-sound-stream-processor", FlutterSoundStreamProcessor);