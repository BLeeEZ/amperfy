//
//  Created by Dimitrios Chatzieleftheriou on 27/05/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import AudioToolbox
import Foundation

/// mapping from mime types to `AudioFileTypeID`
// Custom file type for Ogg Vorbis
let kAudioFileOggType: AudioFileTypeID = 0x6F676720 // 'ogg '

let fileTypesFromMimeType: [String: AudioFileTypeID] =
  [
    "audio/mp3": kAudioFileMP3Type,
    "audio/mpg": kAudioFileMP3Type,
    "audio/mpeg": kAudioFileMP3Type,
    "audio/wav": kAudioFileWAVEType,
    "audio/x-wav": kAudioFileWAVEType,
    "audio/vnd.wav": kAudioFileWAVEType,
    "audio/aifc": kAudioFileAIFCType,
    "audio/aiff": kAudioFileAIFFType,
    "audio/x-m4a": kAudioFileM4AType,
    "audio/x-mp4": kAudioFileMPEG4Type,
    "audio/m4a": kAudioFileM4AType,
    "audio/mp4": kAudioFileMPEG4Type,
    "video/mp4": kAudioFileMPEG4Type,
    "audio/caf": kAudioFileCAFType,
    "audio/x-caf": kAudioFileCAFType,
    "audio/aac": kAudioFileAAC_ADTSType,
    "audio/aacp": kAudioFileAAC_ADTSType,
    "audio/ac3": kAudioFileAC3Type,
    "audio/3gp": kAudioFile3GPType,
    "video/3gp": kAudioFile3GPType,
    "audio/3gpp": kAudioFile3GPType,
    "video/3gpp": kAudioFile3GPType,
    "audio/3gp2": kAudioFile3GP2Type,
    "video/3gp2": kAudioFile3GP2Type,
    "audio/flac": kAudioFileFLACType,
    "audio/ogg": kAudioFileOggType,
    "audio/vorbis": kAudioFileOggType,
    "application/ogg": kAudioFileOggType,
  ]

/// Method that converts mime type to AudioFileTypeID
/// - parameter mimeType: A `String` of the type to be converted, eg `audio/mp3`
/// - returns: `AudioFileTypeID` or 0 if not found
func audioFileType(mimeType: String) -> AudioFileTypeID {
  guard let fileType = fileTypesFromMimeType[mimeType] else { return 0 }
  return fileType
}

/// mapping from file extension to `AudioFileTypeID`
let fileTypesFromFileExtension: [String: AudioFileTypeID] =
  [
    "mp3": kAudioFileMP3Type,
    "wav": kAudioFileWAVEType,
    "aifc": kAudioFileAIFCType,
    "aiff": kAudioFileAIFFType,
    "m4a": kAudioFileM4AType,
    "mp4": kAudioFileMPEG4Type,
    "caf": kAudioFileCAFType,
    "aac": kAudioFileAAC_ADTSType,
    "ac3": kAudioFileAC3Type,
    "3gp": kAudioFile3GPType,
    "flac": kAudioFileFLACType,
    "ogg": kAudioFileOggType,
    "oga": kAudioFileOggType,
  ]

func audioFileType(fileExtension: String) -> AudioFileTypeID {
  guard let fileType = fileTypesFromFileExtension[fileExtension] else { return 0 }
  return fileType
}
