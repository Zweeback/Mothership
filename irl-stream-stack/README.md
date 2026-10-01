# IRL Quality Offensive — self-hosted Restream replacement

## Production core: Muxshed

First path, deliberately kept simple:

```
GoPro HERO13
   -> Pixel hotspot / mobile data
   -> RTMP
   -> Muxshed
   -> Twitch / YouTube / Kick
```

No Pixel VM relay. No local MediaMTX. No local FFmpeg listener.

Muxshed provides:
- RTMP ingest on TCP/1935
- SRT ingest on UDP/9000 for a later upgrade
- browser UI/API on TCP/8080
- Twitch / YouTube / Kick / custom RTMP fan-out
- scenes, browser/media sources, audio mixing
- IRL program failover / BRB
- local recording

## Verified on 2026-10-01

This is no longer just a design:

- Upstream Muxshed Rust tests were executed in an existing cloud runtime:
  - 14 API/unit tests: pass
  - 32 API integration tests: pass
  - 12 common/type tests: pass
- A real Muxshed process was started headless.
- An RTMP source was created through its API.
- FFmpeg published H.264 + AAC into that source.
- Muxshed reported the source as `live`.
- A local RTMP destination was created.
- Muxshed started an egress pipeline to that destination.
- A second FFmpeg process received the resulting 1920x1080 H.264 + AAC RTMP stream.

That proves the important chain:

```
RTMP publisher -> Muxshed ingest -> program pipeline -> RTMP destination
```

## One-command VPS bootstrap

Run:

```bash
sudo ./bootstrap.sh
```

It installs Docker, builds Muxshed, opens the required firewall ports, generates an API key, creates a GoPro RTMP source through the real API, and writes the generated stream key to:

```
/opt/irl-stack/gopro-source.env
```

## Immediate free smoke test

`temporary-free-rtmp-tunnel.sh` exposes an already-running local Muxshed RTMP port through a free Pinggy TCP tunnel.

The free Pinggy endpoint:
- is real raw TCP, so GoPro RTMP can use it
- needs no HTTP conversion
- expires after 60 minutes
- changes hostname/port on reconnect

It is for proving the GoPro path, not the permanent deployment.

## Free-runtime findings

### Google Colab
Not a server target. Google's current Colab policy explicitly prohibits media serving / general web-service offerings on managed runtimes and restricts remote proxies. It is useful for builds and analysis, not this RTMP ingress.

### Google Cloud Free Tier
Compute Engine offers one free `e2-micro` per month in selected US regions, but the free Compute Engine allowance includes only 1 GB/month outbound transfer. Multistream video burns through that quickly, so it is a poor permanent relay even though the VM can expose TCP/1935.

### SuperGrok / Grok Bot
An eligible SuperGrok subscription can link to Grok Bot, which provides a persistent cloud computer with a browser, filesystem and terminal. That is useful as a build/test/orchestration worker. The public docs do not promise a raw public TCP ingress address, so it is not being treated as the production RTMP endpoint without evidence.

### GitHub Codespaces
Ports can be made public, but the externally exposed endpoint is a GitHub HTTP/HTTPS forwarding URL. Useful for dashboards, not a plain RTMP listener for a GoPro.

### Oracle Cloud Always Free
This is the strongest no-new-monthly-cost production target found:
- Ampere A1 Always Free compute
- up to 2 OCPUs / 12 GB RAM under the documented free allocation
- public networking
- first 10 TB/month public internet egress free

That egress allowance actually fits multistream video in a way Google Cloud's 1 GB free Compute egress does not.

## RatoNet status

RatoNet remains the candidate for GPS / speed / map / overlays.

Its upstream tests were run:
- **47 passed**

But a runtime defect was also reproduced: the documented flat `.env` variables are currently rejected by the root Pydantic Settings object as `extra_forbidden`. So RatoNet is not in the production bootstrap yet. It will be added after that config path is patched and startup is re-tested.

## Security

Never commit:
- Twitch / YouTube / Kick stream keys
- Muxshed API keys
- Pixel hotspot password
- GoPro Wi-Fi password

The bootstrap generates runtime credentials locally on the host.
