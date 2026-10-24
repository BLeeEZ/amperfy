# AudioStreaming

This is the Amperfy-pinned AudioStreaming 1.4.4 source at upstream revision
`a729ee28fece29d80a749419d96df0693200f124` (MIT license in `LICENSE`). It is
kept locally so Amperfy can preserve multichannel PCM instead of receiving the
library's fixed stereo output.

Local changes:

- Configure the canonical PCM stream, renderer buffers, and converter layouts
  for MPEG 5.1 audio.
- Use the output format's channel count throughout the render callback.
- Tag six-channel Vorbis streams with the Ogg 5.1 channel layout. Vorbis and
  MPEG 5.1 use different channel orders; the converter maps Ogg input to the
  MPEG 5.1 output layout.
- Hand the hardware stereo for stereo and mono tracks and 5.1 only for
  multichannel ones (`HardwareOutput`). The player decodes into one 5.1
  stream; iOS judges content by the hardware stream, so a fixed 5.1 output made
  every track show as multichannel Spatial Audio.
- Decode at 48 kHz, the rate of AirPods and the iPhone output, instead of
  44.1 kHz, so a track is resampled at most once.
- Seek FLAC exactly. A FLAC seek starts at a byte offset estimated from the
  average bitrate, which can be far off. The first frame header received gives
  the real sample position (`FlacFrameLocator`); a miss of more than a second is
  retried from a corrected offset (up to four tries), and the shown time is set
  to where playback really is.
