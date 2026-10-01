# IRL Quality Offensive — self-hosted Restream replacement

Primary stream core: **Muxshed**
- RTMP ingest on TCP/1935
- SRT ingest on UDP/9000
- browser production UI/API on TCP/8080
- fan-out to Twitch, YouTube, Kick, and custom RTMP/RTMPS
- failover/BRB, scenes, browser/media sources, audio mixing and recording

IRL telemetry layer: **RatoNet**
- GPS / speed / altitude / heading
- live map + route
- WebSocket telemetry
- browser overlays
- SRT/SRTLA support for a later bonded uplink

First production path:

GoPro HERO13 -> Pixel hotspot/mobile data -> public Muxshed RTMP endpoint -> Twitch/YouTube/Kick

No Pixel VM relay, no local MediaMTX, no local FFmpeg listener.

## Host requirements

Public Linux host with:
- public IPv4 or public TCP proxy
- TCP 1935 reachable from the Internet
- TCP 8080 for Muxshed UI/API
- TCP 8000 for RatoNet UI/API
- Docker 24+ / Docker Compose
- recommended for building both projects: 2 vCPU / 4 GB RAM

Later:
- UDP 9000 for SRT
- UDP 5001 for SRTLA
- TCP 8443 for WebRTC signalling

Run `bootstrap.sh` on the VPS.

## GoPro / Pixel networking

The Pixel hotspot credentials and the GoPro camera's own Wi-Fi credentials are different things.

For streaming, GoPro Quik configures the camera to join the **Pixel hotspot** as the Internet uplink. The camera's own SSID/password are for pairing/control and are not RTMP server credentials.

After Muxshed is online:
1. Create an RTMP source in Muxshed.
2. Copy the generated publish URL/key.
3. In GoPro Quik -> Live -> RTMP/Other, choose the Pixel hotspot and enter the Muxshed publish URL.
4. Start the first field test at 720p.

## Current infrastructure findings — 2026-10-01

- Railway: refuses new resources because the trial expired.
- Render: Frankfurt services exist, but public Render web services do not expose raw RTMP TCP/1935.
- DigitalOcean: connector is authenticated, but the account reports a droplet-limit warning while listing zero visible droplets; do not provision blindly.
- Fly Sprites: existing sprites are available, but public service exposure is HTTP-oriented rather than a direct raw RTMP endpoint.

Remaining hard requirement: one public raw-TCP host.

## Security

Never commit Twitch/YouTube/Kick stream keys, Muxshed API keys, hotspot passwords, or GoPro Wi-Fi passwords.
`bootstrap.sh` creates runtime secrets locally on the host in `/opt/irl-stack/runtime-secrets.env`.
