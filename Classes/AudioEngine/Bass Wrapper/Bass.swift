//
//  Bass.swift
//  iSub Beta
//
//  Created by Benjamin Baron on 9/17/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

struct Bass {
    static func printChannelInfo(_ channel: HSTREAM) {
        var i = BASS_CHANNELINFO()
        BASS_ChannelGetInfo(channel, &i)
        let bytes = BASS_ChannelGetLength(channel, UInt32(BASS_POS_BYTE))
        let time = BASS_ChannelBytes2Seconds(channel, bytes)
        log.debug("channel type = \(i.ctype) (\(self.formatForChannel(channel)))\nlength = \(bytes) (seconds: \(time)  flags: \(i.flags)  freq: \(i.freq)  origres: \(i.origres)")
    }
    
    static func formatForChannel(_ channel: HSTREAM) -> String {
        var i = BASS_CHANNELINFO()
        BASS_ChannelGetInfo(channel, &i)
        
        /*if (plugin)
         {
         // using a plugin
         const BASS_PLUGININFO *pinfo=BASS_PluginGetInfo(plugin) // get plugin info
         int a
         for (a=0a<pinfo->formatca++)
         {
         if (pinfo->formats[a].ctype==ctype) // found a "ctype" match...
         return [NSString stringWithFormat:"%s", pinfo->formats[a].name] // return it's name
         }
         }*/
        
        switch Int32(i.ctype) {
        case BASS_CTYPE_STREAM_WV:        return "WV"
        case BASS_CTYPE_STREAM_MPC:       return "MPC"
        case BASS_CTYPE_STREAM_APE:       return "APE"
        case BASS_CTYPE_STREAM_FLAC:      return "FLAC"
        case BASS_CTYPE_STREAM_FLAC_OGG:  return "FLAC"
        case BASS_CTYPE_STREAM_OGG:       return "OGG"
        case BASS_CTYPE_STREAM_MP1:       return "MP1"
        case BASS_CTYPE_STREAM_MP2:       return "MP2"
        case BASS_CTYPE_STREAM_MP3:       return "MP3"
        case BASS_CTYPE_STREAM_AIFF:      return "AIFF"
        case BASS_CTYPE_STREAM_OPUS:      return "Opus"
        case BASS_CTYPE_STREAM_WAV_PCM:   return "PCM WAV"
        case BASS_CTYPE_STREAM_WAV_FLOAT: return "Float WAV"
        // Check if WAV case works
        case BASS_CTYPE_STREAM_WAV: return "WAV"
        case BASS_CTYPE_STREAM_CA:
            // CoreAudio codec
            guard let tags = BASS_ChannelGetTags(channel, UInt32(BASS_TAG_CA_CODEC)) else {
                return ""
            }
            
            return tags.withMemoryRebound(to: TAG_CA_CODEC.self, capacity: 1) { pointer in
                let codec: TAG_CA_CODEC = pointer.pointee
                switch codec.atype {
                case kAudioFormatLinearPCM:            return "LPCM"
                case kAudioFormatAC3:                  return "AC3"
                case kAudioFormat60958AC3:             return "AC3"
                case kAudioFormatAppleIMA4:            return "IMA4"
                case kAudioFormatMPEG4AAC:             return "AAC"
                case kAudioFormatMPEG4CELP:            return "CELP"
                case kAudioFormatMPEG4HVXC:            return "HVXC"
                case kAudioFormatMPEG4TwinVQ:          return "TwinVQ"
                case kAudioFormatMACE3:                return "MACE 3:1"
                case kAudioFormatMACE6:                return "MACE 6:1"
                case kAudioFormatULaw:                 return "μLaw 2:1"
                case kAudioFormatALaw:                 return "aLaw 2:1"
                case kAudioFormatQDesign:              return "QDMC"
                case kAudioFormatQDesign2:             return "QDM2"
                case kAudioFormatQUALCOMM:             return "QCPV"
                case kAudioFormatMPEGLayer1:           return "MP1"
                case kAudioFormatMPEGLayer2:           return "MP2"
                case kAudioFormatMPEGLayer3:           return "MP3"
                case kAudioFormatTimeCode:             return "TIME"
                case kAudioFormatMIDIStream:           return "MIDI"
                case kAudioFormatParameterValueStream: return "APVS"
                case kAudioFormatAppleLossless:        return "ALAC"
                case kAudioFormatMPEG4AAC_HE:          return "AAC-HE"
                case kAudioFormatMPEG4AAC_LD:          return "AAC-LD"
                case kAudioFormatMPEG4AAC_ELD:         return "AAC-ELD"
                case kAudioFormatMPEG4AAC_ELD_SBR:     return "AAC-SBR"
                case kAudioFormatMPEG4AAC_HE_V2:       return "AAC-HEv2"
                case kAudioFormatMPEG4AAC_Spatial:     return "AAC-S"
                case kAudioFormatAMR:                  return "AMR"
                case kAudioFormatAudible:              return "AUDB"
                case kAudioFormatiLBC:                 return "iLBC"
                case kAudioFormatDVIIntelIMA:          return "ADPCM"
                case kAudioFormatMicrosoftGSM:         return "GSM"
                case kAudioFormatAES3:                 return "AES3"
                default: return ""
                }
            }
        default: return ""
        }
    }
    
    // TODO: Double check this logic
    static func estimateBitRate(bassStream: BassStream) -> Int {
        // Default to the player bitRate
        let startFilePosition: UInt64 = 0
        let currentFilePosition = BASS_StreamGetFilePosition(bassStream.stream, UInt32(BASS_FILEPOS_CURRENT))
        let filePosition = currentFilePosition - startFilePosition
        let decodedPosition = BASS_ChannelGetPosition(bassStream.stream, UInt32(BASS_POS_BYTE|BASS_POS_DECODE)) // decoded PCM position
        let decodedSeconds = BASS_ChannelBytes2Seconds(bassStream.stream, decodedPosition)
        guard decodedPosition > 0 && decodedSeconds > 0 else {
            return bassStream.song.estimatedBitRate
        }
        
        let bitRateFloat = (Float(filePosition) * 8.0) / Float(decodedSeconds)
        guard bitRateFloat < Float(Int.max) && bitRateFloat > Float(Int.min) else {
            return bassStream.song.estimatedBitRate
        }
        
        var bitRate = Int(bitRateFloat / 1000.0)
        bitRate = bitRate > 1000000 ? 1 : bitRate
        
        var i = BASS_CHANNELINFO()
        BASS_ChannelGetInfo(bassStream.stream, &i)
        
        // Check the current stream format, and make sure that the bitRate is in the correct range
        // otherwise use the song's estimated bitRate instead (to keep something like a 10000 kbitRate on an mp3 from being used for buffering)
        switch Int32(i.ctype) {
        case BASS_CTYPE_STREAM_WAV_PCM,
             BASS_CTYPE_STREAM_WAV_FLOAT,
             BASS_CTYPE_STREAM_WAV,
             BASS_CTYPE_STREAM_AIFF,
             BASS_CTYPE_STREAM_WV,
             BASS_CTYPE_STREAM_FLAC,
             BASS_CTYPE_STREAM_FLAC_OGG:
            if bitRate < 330 || bitRate > 12000 {
                bitRate = bassStream.song.estimatedBitRate
            }
        case BASS_CTYPE_STREAM_OGG,
             BASS_CTYPE_STREAM_MP1,
             BASS_CTYPE_STREAM_MP2,
             BASS_CTYPE_STREAM_MP3,
             BASS_CTYPE_STREAM_MPC:
            if bitRate > 450 {
                bitRate = bassStream.song.estimatedBitRate
            }
        case BASS_CTYPE_STREAM_CA:
            // CoreAudio codec
            guard let tags = BASS_ChannelGetTags(bassStream.stream, UInt32(BASS_TAG_CA_CODEC)) else {
                bitRate = bassStream.song.estimatedBitRate
                break
            }
            
            tags.withMemoryRebound(to: TAG_CA_CODEC.self, capacity: 1) { pointer in
                let codec: TAG_CA_CODEC = pointer.pointee
                switch codec.atype {
                case kAudioFormatLinearPCM,
                     kAudioFormatAppleLossless:
                    if bitRate < 330 || bitRate > 12000 {
                        bitRate = bassStream.song.estimatedBitRate
                    }
                case kAudioFormatMPEG4AAC,
                     kAudioFormatMPEG4AAC_HE,
                     kAudioFormatMPEG4AAC_LD,
                     kAudioFormatMPEG4AAC_ELD,
                     kAudioFormatMPEG4AAC_ELD_SBR,
                     kAudioFormatMPEG4AAC_HE_V2,
                     kAudioFormatMPEG4AAC_Spatial,
                     kAudioFormatMPEGLayer1,
                     kAudioFormatMPEGLayer2,
                     kAudioFormatMPEGLayer3:
                    if bitRate > 450 {
                        bitRate = bassStream.song.estimatedBitRate;
                    }
                default:
                    // If we can't detect the format, use the estimated bitRate instead of player to be safe
                    bitRate = bassStream.song.estimatedBitRate
                }
            }
        default:
            // If we can't detect the format, use the estimated bitRate instead of player to be safe
            bitRate = bassStream.song.estimatedBitRate
        }
        
        return bitRate
    }
    
    static func string(fromErrorCode errorCode: Int32) -> String {
        switch errorCode {
        case BASS_OK:             return "No error! All OK"
        case BASS_ERROR_MEM:      return "Memory error"
        case BASS_ERROR_FILEOPEN: return "Can't open the file"
        case BASS_ERROR_DRIVER:   return "Can't find a free/valid driver"
        case BASS_ERROR_BUFLOST:  return "The sample buffer was lost"
        case BASS_ERROR_HANDLE:   return "Invalid handle"
        case BASS_ERROR_FORMAT:   return "Unsupported sample format"
        case BASS_ERROR_POSITION: return "Invalid position"
        case BASS_ERROR_INIT:     return "BASS_Init has not been successfully called"
        case BASS_ERROR_START:    return "BASS_Start has not been successfully called"
        case BASS_ERROR_ALREADY:  return "Already initialized/paused/whatever"
        case BASS_ERROR_NOCHAN:   return "Can't get a free channel"
        case BASS_ERROR_ILLTYPE:  return "An illegal type was specified"
        case BASS_ERROR_ILLPARAM: return "An illegal parameter was specified"
        case BASS_ERROR_NO3D:     return "No 3D support"
        case BASS_ERROR_NOEAX:    return "No EAX support"
        case BASS_ERROR_DEVICE:   return "Illegal device number"
        case BASS_ERROR_NOPLAY:   return "Not playing"
        case BASS_ERROR_FREQ:     return "Illegal sample rate"
        case BASS_ERROR_NOTFILE:  return "The stream is not a file stream"
        case BASS_ERROR_NOHW:     return "No hardware voices available"
        case BASS_ERROR_EMPTY:    return "The MOD music has no sequence data"
        case BASS_ERROR_NONET:    return "No internet connection could be opened"
        case BASS_ERROR_CREATE:   return "Couldn't create the file"
        case BASS_ERROR_NOFX:     return "Effects are not available"
        case BASS_ERROR_NOTAVAIL: return "Requested data is not available"
        case BASS_ERROR_DECODE:   return "The channel is a 'decoding channel'"
        case BASS_ERROR_DX:       return "A sufficient DirectX version is not installed"
        case BASS_ERROR_TIMEOUT:  return "Connection timedout"
        case BASS_ERROR_FILEFORM: return "Unsupported file format"
        case BASS_ERROR_SPEAKER:  return "Unavailable speaker"
        case BASS_ERROR_VERSION:  return "Invalid BASS version (used by add-ons)"
        case BASS_ERROR_CODEC:    return "Codec is not available/supported"
        case BASS_ERROR_ENDED:    return "The channel/file has ended"
        case BASS_ERROR_BUSY:     return "The device is busy"
        default:                  return "Unknown error."
        }
    }
    
    static func printBassError(file: String = #file, line: Int = #line, function: String = #function) {
        let errorCode = BASS_ErrorGetCode()
        printError("BASS error: \(errorCode) - \(string(fromErrorCode: errorCode))", file: file, line: line, function: function)
    }
    
    static func testStream(forSong song: Song) -> Bool {
        guard song.fileExists else {
            return false
        }
        
        BASS_SetDevice(0)
        
        var fileStream: HSTREAM = 0
        song.currentPath.withCString { unsafePointer in
            fileStream = BASS_StreamCreateFile(false, unsafePointer, 0, UInt64(song.size), UInt32(BASS_STREAM_DECODE|BASS_SAMPLE_FLOAT))
            if fileStream == 0 {
                fileStream = BASS_StreamCreateFile(false, unsafePointer, 0, UInt64(song.size), UInt32(BASS_STREAM_DECODE|BASS_SAMPLE_SOFTWARE|BASS_SAMPLE_FLOAT))
            }
        }
        
        if fileStream > 0 {
            BASS_StreamFree(fileStream)
            return true
        }
        return false
    }
    
    static func bytesToBuffer(forKiloBitRate rate: Int, speedInBytesPerSec: Int) -> Int64 {
        // If start date is nil somehow, or total bytes transferred is 0 somehow, return the default of 10 seconds worth of audio
        if rate == 0 || speedInBytesPerSec == 0 {
            return BytesForSecondsAtBitRate(seconds: 10, bitRate: rate)
        }
        
        // Get the download speed in KB/sec
        let kiloBytesPerSec = Double(speedInBytesPerSec) / 1024.0
        
        // Find out out many bytes equals 1 second of audio
        let bytesForOneSecond = Double(BytesForSecondsAtBitRate(seconds: 1, bitRate: rate))
        let kiloBytesForOneSecond = bytesForOneSecond / 1024.0
        
        // Calculate the amount of seconds to start as a factor of how many seconds of audio are being downloaded per second
        let secondsPerSecondFactor = kiloBytesPerSec / kiloBytesForOneSecond
        
        var numberOfSecondsToBuffer: Double
        if secondsPerSecondFactor < 0.5 {
            // Downloading very slow, buffer for a while
            numberOfSecondsToBuffer = 20
        } else if secondsPerSecondFactor >= 0.5 && secondsPerSecondFactor < 0.7 {
            // Downloading faster, but not much faster, allow for a long buffer period
            numberOfSecondsToBuffer = 12
        } else if secondsPerSecondFactor >= 0.7 && secondsPerSecondFactor < 0.9 {
            // Downloading not much slower than real time, use a smaller buffer period
            numberOfSecondsToBuffer = 8
        } else if secondsPerSecondFactor >= 0.9 && secondsPerSecondFactor < 1.0 {
            // Almost downloading full speed, just buffer for a short time
            numberOfSecondsToBuffer = 5
        } else {
            // We're downloading over the speed needed, so probably the connection loss was temporary? Just buffer for a very short time
            numberOfSecondsToBuffer = 2
        }
        
        // Convert from seconds to bytes
        let numberOfBytesToBuffer = numberOfSecondsToBuffer * bytesForOneSecond
        return Int64(numberOfBytesToBuffer)
    }
}
