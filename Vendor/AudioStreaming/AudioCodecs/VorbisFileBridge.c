#include "include/VorbisFileBridge.h"

#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <vorbis/vorbisfile.h>

struct VFRemoteStream {
    uint8_t *buf;
    size_t cap, head, tail, size;
    int eof;
    long long pos;           // Current read position in the stream
    long long total_pushed;  // Total bytes pushed into the buffer
    pthread_mutex_t m;
    pthread_cond_t cv;
};

// Simple ring buffer write
static size_t rb_write(struct VFRemoteStream *s, const uint8_t *src, size_t len) {
    size_t written = 0;
    while (written < len) {
        size_t free_space = s->cap - s->size;
        if (free_space == 0) break;
        size_t chunk = s->cap - s->tail;
        if (chunk > len - written) chunk = len - written;
        if (chunk > free_space) chunk = free_space;
        memcpy(s->buf + s->tail, src + written, chunk);
        s->tail = (s->tail + chunk) % s->cap;
        s->size += chunk;
        written += chunk;
    }
    return written;
}

// Simple ring buffer read
static size_t rb_read(struct VFRemoteStream *s, uint8_t *dst, size_t len) {
    size_t read = 0;
    while (read < len && s->size > 0) {
        size_t chunk = s->cap - s->head;
        if (chunk > s->size) chunk = s->size;
        if (chunk > len - read) chunk = len - read;
        memcpy(dst + read, s->buf + s->head, chunk);
        s->head = (s->head + chunk) % s->cap;
        s->size -= chunk;
        read += chunk;
    }
    return read;
}

// Create a stream buffer
VFStreamRef VFStreamCreate(size_t capacity_bytes) {
    struct VFRemoteStream *s = (struct VFRemoteStream *)calloc(1, sizeof(struct VFRemoteStream));
    if (!s) return NULL;
    s->buf = (uint8_t *)malloc(capacity_bytes);
    if (!s->buf) { free(s); return NULL; }
    s->cap = capacity_bytes;
    pthread_mutex_init(&s->m, NULL);
    pthread_cond_init(&s->cv, NULL);
    return s;
}

// Destroy a stream buffer
void VFStreamDestroy(VFStreamRef sr) {
    struct VFRemoteStream *s = (struct VFRemoteStream *)sr;
    if (!s) return;
    pthread_mutex_destroy(&s->m);
    pthread_cond_destroy(&s->cv);
    free(s->buf);
    free(s);
}

// Get available bytes in the buffer
size_t VFStreamAvailableBytes(VFStreamRef sr) {
    struct VFRemoteStream *s = (struct VFRemoteStream *)sr;
    if (!s) return 0;
    pthread_mutex_lock(&s->m);
    size_t sz = s->size;
    pthread_mutex_unlock(&s->m);
    return sz;
}

// Push data into the stream
void VFStreamPush(VFStreamRef sr, const uint8_t *data, size_t len) {
    struct VFRemoteStream *s = (struct VFRemoteStream *)sr;
    if (!s || !data || len == 0) return;

    pthread_mutex_lock(&s->m);
    size_t written_total = 0;
    while (written_total < len) {
        size_t w = rb_write(s, data + written_total, len - written_total);
        written_total += w;
        if (written_total < len) {
            // Buffer full, wait for consumer to read
            pthread_cond_wait(&s->cv, &s->m);
        }
    }
    s->total_pushed += (long long)len;
    pthread_cond_broadcast(&s->cv);
    pthread_mutex_unlock(&s->m);
}

// Mark the stream as EOF
void VFStreamMarkEOF(VFStreamRef sr) {
    struct VFRemoteStream *s = (struct VFRemoteStream *)sr;
    if (!s) return;
    pthread_mutex_lock(&s->m);
    s->eof = 1;
    pthread_cond_broadcast(&s->cv);
    pthread_mutex_unlock(&s->m);
}

// libvorbisfile callbacks

// Read callback for libvorbisfile
static size_t read_cb(void *ptr, size_t size, size_t nmemb, void *datasrc) {
    struct VFRemoteStream *s = (struct VFRemoteStream *)datasrc;
    size_t want_bytes = size * nmemb;
    size_t got = 0;

    pthread_mutex_lock(&s->m);
    // Read what's available NOW - don't block waiting for more data
    while (got < want_bytes && s->size > 0) {
        size_t chunk = rb_read(s, (uint8_t *)ptr + got, want_bytes - got);
        s->pos += (long long)chunk;
        got += chunk;

        if (chunk == 0) break;
        // Allow producer to push more
        pthread_cond_broadcast(&s->cv);
    }

    // If nothing available and EOF, we're done
    if (got == 0 && s->eof) {
        // Return 0 to signal EOF to libvorbisfile
    }

    pthread_mutex_unlock(&s->m);

    return size ? (got / size) : 0;
}

// Seek callback - seek within the ring buffer
static int seek_cb(void *datasrc, ogg_int64_t offset, int whence) {
    struct VFRemoteStream *s = (struct VFRemoteStream *)datasrc;
    if (!s) return -1;

    pthread_mutex_lock(&s->m);

    ogg_int64_t new_pos = 0;
    switch (whence) {
        case SEEK_SET:
            new_pos = offset;
            break;
        case SEEK_CUR:
            new_pos = s->pos + offset;
            break;
        case SEEK_END:
            new_pos = s->total_pushed + offset;
            break;
        default:
            pthread_mutex_unlock(&s->m);
            return -1;
    }

    // Check if the new position is valid (within available data)
    if (new_pos < 0 || new_pos > s->total_pushed) {
        pthread_mutex_unlock(&s->m);
        return -1; // Can't seek outside available data
    }

    // Calculate how much data we've already consumed from the buffer
    long long already_consumed = s->pos - ((long long)s->total_pushed - (long long)s->size);

    // Calculate the new head position
    long long pos_delta = new_pos - s->pos;

    // For forward seeks, we need to have enough data in the buffer
    if (pos_delta > 0 && pos_delta > (long long)s->size) {
        pthread_mutex_unlock(&s->m);
        return -1; // Not enough data in buffer to seek forward
    }

    // For backward seeks, check if that data is still in the buffer
    if (pos_delta < 0 && (-pos_delta) > already_consumed) {
        pthread_mutex_unlock(&s->m);
        return -1; // Data has been discarded from buffer
    }

    // Adjust head pointer
    if (pos_delta >= 0) {
        // Forward seek: advance head
        s->head = (s->head + pos_delta) % s->cap;
        s->size -= (size_t)pos_delta;
    } else {
        // Backward seek: rewind head
        size_t rewind = (size_t)(-pos_delta);
        if (s->head >= rewind) {
            s->head -= rewind;
        } else {
            s->head = s->cap - (rewind - s->head);
        }
        s->size += rewind;
    }

    s->pos = new_pos;
    pthread_mutex_unlock(&s->m);
    return 0;
}

// Close callback - no-op
static int close_cb(void *datasrc) {
    (void)datasrc;
    return 0;
}

// Tell callback - return current position
static long tell_cb(void *datasrc) {
    struct VFRemoteStream *s = (struct VFRemoteStream *)datasrc;
    return (long)s->pos;
}

// Open a vorbis file using callbacks
int VFOpen(VFStreamRef sr, VFFileRef *out_vf) {
    struct VFRemoteStream *s = (struct VFRemoteStream *)sr;
    if (!s || !out_vf) return -1;

    OggVorbis_File *vf = (OggVorbis_File *)malloc(sizeof(OggVorbis_File));
    if (!vf) return -1;

    ov_callbacks cbs;
    cbs.read_func = read_cb;
    cbs.seek_func = NULL; // Non-seekable streaming (seeking handled at Swift level)
    cbs.close_func = close_cb;
    cbs.tell_func = tell_cb;

    int rc = ov_open_callbacks((void *)s, vf, NULL, 0, cbs);
    if (rc < 0) { free(vf); return rc; }

    *out_vf = (VFFileRef)vf;
    return 0;
}

// Clear a vorbis file
void VFClear(VFFileRef fr) {
    OggVorbis_File *vf = (OggVorbis_File *)fr;
    if (!vf) return;
    ov_clear(vf);
    free(vf);
}

// Get stream info
int VFGetInfo(VFFileRef fr, VFStreamInfo *out_info) {
    OggVorbis_File *vf = (OggVorbis_File *)fr;
    if (!vf || !out_info) return -1;

    vorbis_info const *info = ov_info(vf, -1);
    if (!info) return -1;

    out_info->sample_rate = info->rate;
    out_info->channels = info->channels;
    out_info->total_pcm_samples = ov_pcm_total(vf, -1);
    out_info->duration_seconds = ov_time_total(vf, -1);
    out_info->bitrate_nominal = info->bitrate_nominal;

    return 0;
}

// Read deinterleaved float PCM frames
long VFReadFloat(VFFileRef fr, float ***out_pcm, int max_frames) {
    OggVorbis_File *vf = (OggVorbis_File *)fr;
    if (!vf || !out_pcm || max_frames <= 0) return -1;

    int bitstream = 0;
    long frames = ov_read_float(vf, out_pcm, max_frames, &bitstream);

    // Returns: frames read (0 = EOF, <0 = error)
    return frames;
}

// Read interleaved float PCM frames (legacy, less efficient)
long VFReadInterleavedFloat(VFFileRef fr, float *dst, int max_frames) {
    OggVorbis_File *vf = (OggVorbis_File *)fr;
    if (!vf || !dst || max_frames <= 0) return -1;

    int bitstream = 0;
    float **pcm = NULL;
    long frames = ov_read_float(vf, &pcm, max_frames, &bitstream);

    if (frames <= 0) return frames; // 0 EOF, <0 error/hole

    vorbis_info const *info = ov_info(vf, -1);
    int ch = info->channels;

    // Interleave the PCM data
    for (long f = 0; f < frames; ++f) {
        for (int c = 0; c < ch; ++c) {
            dst[f * ch + c] = pcm[c][f];
        }
    }

    return frames;
}

// Seek to a specific time in seconds
int VFSeekTime(VFFileRef fr, double time_seconds) {
    OggVorbis_File *vf = (OggVorbis_File *)fr;
    if (!vf) return -1;

    // Use ov_time_seek for time-based seeking
    // Returns 0 on success, nonzero on failure
    return ov_time_seek(vf, time_seconds);
}

// Check if the stream is seekable
int VFIsSeekable(VFFileRef fr) {
    OggVorbis_File *vf = (OggVorbis_File *)fr;
    if (!vf) return 0;

    // Returns nonzero if the stream is seekable
    return ov_seekable(vf);
}
