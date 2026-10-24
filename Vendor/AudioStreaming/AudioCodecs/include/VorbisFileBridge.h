#ifndef VORBIS_FILE_BRIDGE_H
#define VORBIS_FILE_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

// Opaque refs for Swift-friendly API
typedef void * VFStreamRef;
typedef void * VFFileRef;

#ifdef __cplusplus
extern "C" {
#endif

// Stream info structure
typedef struct {
    int sample_rate;
    int channels;
    long long total_pcm_samples; // -1 if unknown
    double duration_seconds;     // < 0 if unknown
    long bitrate_nominal;        // nominal bitrate in bits/sec, or 0 if unknown
} VFStreamInfo;

// Stream lifecycle
VFStreamRef VFStreamCreate(size_t capacity_bytes);
void VFStreamDestroy(VFStreamRef s);
size_t VFStreamAvailableBytes(VFStreamRef s);

// Feeding data
void VFStreamPush(VFStreamRef s, const uint8_t *data, size_t len);
void VFStreamMarkEOF(VFStreamRef s);

// Decoder lifecycle
// Returns 0 on success, negative on error (same codes as ov_open_callbacks)
int VFOpen(VFStreamRef s, VFFileRef *out_vf);
void VFClear(VFFileRef vf);

// Query info; returns 0 on success
int VFGetInfo(VFFileRef vf, VFStreamInfo *out_info);

// Read interleaved float32 PCM frames into dst; returns number of frames read, 0 on EOF, <0 on error
long VFReadInterleavedFloat(VFFileRef vf, float *dst, int max_frames);

// Read deinterleaved float32 PCM frames (channel-by-channel); returns number of frames read, 0 on EOF, <0 on error
// out_pcm will point to an array of channel pointers (float**)
long VFReadFloat(VFFileRef vf, float ***out_pcm, int max_frames);

// Seek to a specific time in seconds; returns 0 on success, <0 on error
int VFSeekTime(VFFileRef vf, double time_seconds);

// Check if the stream is seekable; returns 1 if seekable, 0 if not
int VFIsSeekable(VFFileRef vf);

#ifdef __cplusplus
}
#endif

#endif // VORBIS_FILE_BRIDGE_H