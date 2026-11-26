# Network address fallback

`rootcopy-install/etc/NetworkManager/dispatcher.d/90-minios-network` links to the executable in `no-wait.d`. The handler checks MiniOS resources on `up`, `down`, `vpn-up`, `vpn-down`, `dhcp4-change`, `dhcp6-change`, `dns-change`, `connectivity-change` and `reapply` events. It also accepts `--check` and `--clear` for manual administration.

Each invocation removes the previous managed block from `/etc/hosts` before checking normal name resolution. If a resource fails, the handler tests its previously selected address, current resolver results and configured candidates. It installs only addresses verified through HTTPS with the original hostname and certificate validation. Working normal access does not create a hosts override.

## Resources

The three Pages sites each serve the same immutable synthetic file at `/network-check/v1/minios-network-probe-v1-1m.bin`. The file is exactly 1048576 bytes (1 MiB) and is generated deterministically from SHAKE-256, so it does not compress into a misleadingly tiny transfer. It contains no user data. The same file is a dedicated asset in the MiniOS v5.1.1 GitHub release, independent of the ISO filenames and checksums.

| Hostname | Probe |
| --- | --- |
| `minios.dev` | Full synthetic file from its own origin |
| `deb.minios.dev` | Full synthetic file from its own origin |
| `store.minios.dev` | Full synthetic file from its own origin |
| `github.com` | Fresh HTTPS redirect to the dedicated synthetic release asset |
| `release-assets.githubusercontent.com` | Full synthetic file obtained from that redirect |

Normal DNS access and every alternative address must pass the same bulk-transfer check. A successful probe requires HTTP 200, exactly 1 MiB of uncompressed content, and SHA-256 `8098e63d94f6c48aaf609624bf3c8d4c720d5e18504ea6cb34e86eb4c493f32b`. The expected size and digest are pinned in the dispatcher; the public `.sha256` file is for manual diagnostics, not a source of trust for the script. HTTP 206, incomplete transfers, unexpected content encodings, wrong hashes and inconsistent lengths are rejected. Every request asks for `Accept-Encoding: identity`; it never combines ranges or resumes a partial download.

Healthy access transfers approximately 4 MiB in total per evaluation, plus HTTPS and redirect overhead. Failed checks and alternative candidates can consume additional traffic. Event bursts are coalesced, but distinct events still cause new evaluations. A successful 1 MiB transfer is not a guarantee that an entire ISO will download.

Requests have a 5-second connection timeout, a 30-second bulk-transfer timeout and an 8-second redirect timeout. `curl --max-filesize` and a kernel file-size limit via `prlimit` bound temporary downloads, including chunked responses on older curl versions. Temporary files are kept under `/run` and removed after each request. Diagnostics include the domain, candidate, curl exit code and received size, but never the signed download URL.

### Reproducing and publishing the files

From the top-level repository, run the generator with one or more output directories:

```sh
python3 tools/generate-network-probe.py \
  submodules/minios-linux.github.io/public/network-check/v1 \
  submodules/minios-store/web/public/network-check/v1 \
  /path/to/deb/network-check/v1
```

Commit and publish those files with the usual site workflows. Vite copies the website and store `public` directories into the published site; the APT repository's Pages workflow copies `network-check/v1` as static files. Upload the `.bin` and its `.sha256` to the release referenced by `release_probe_url`. Publish the files before distributing the updated dispatcher. A missing file must not be worked around by accepting an HTML page, a tiny file or a different hostname.

The generator refuses to overwrite different content at the same versioned path. Keep v1 available and unchanged; use a new versioned path and update the local digest together if the format changes. Signed redirect URLs are never persisted. The probe does not replace package or image authenticity verification.

## Configuration

`/etc/minios/network-fallback.json` contains `enabled`, `release_probe_url` and per-host `candidates`. Candidate IP addresses are hints, not permanent bindings: every selected address must pass a live content and TLS check. The release URL must refer to the dedicated versioned synthetic `.bin` asset; do not replace it with an ISO checksum or a normal site page. Changes to this configuration take effect on the next supported event or a manual `--check`.

Set `enabled` to `false` and invoke the following command to disable fallback and immediately restore ordinary resolution:

```sh
sudo /etc/NetworkManager/dispatcher.d/90-minios-network --clear
```

Trigger a fresh evaluation manually with:

```sh
sudo /etc/NetworkManager/dispatcher.d/90-minios-network --check
```

The handler edits only the block between `# BEGIN MINIOS NETWORK OVERRIDES` and `# END MINIOS NETWORK OVERRIDES`. Hostnames with user-managed entries outside this block are not overridden. A malformed managed block causes an error instead of deleting possibly unrelated data. Hosts updates use atomic replacement and preserve ownership, permissions and extended attributes.

Concurrent invocations share a short write lock and a generation token under `/run/minios-network-fallback`. A newer event invalidates older work; network addresses, policy routes and resolver configuration are compared before and after probing. Requests have individual timeouts and share a 180-second probe budget. The next supported event clears stale entries, including entries persisted from the previous boot. Without another event, the selected entries remain in effect.

Diagnostics are sent to syslog with identifier `minios-network-fallback`. On systemd installations, use `journalctl -t minios-network-fallback`.

Address selection can help when some endpoints are unreachable. It cannot recover a service when no candidate works. Probes use direct connections, because a successful HTTP proxy connection does not establish that the client can reach a candidate IP directly. Applications using a proxy, their own resolver or an existing connection may not immediately use the new hosts entries.

## Tests

Run from the repository root:

```sh
python3 -B linux-live/tests/test_network_fallback.py -v
python3 -B linux-live/tests/test_network_probe_https.py -v
```

The tests use isolated hosts files and mocked network responses. They cover fallback selection, exact payload/hash/size validation, rejected truncated or compressed responses, generation reproducibility, runtime download limits, HTTPS validation, redirect restrictions, preservation of manual entries and file metadata, cleanup, disabled configuration, concurrent events, timeouts and changing network state.

The HTTPS integration suite runs the actual curl/prlimit path against a temporary loopback TLS server with a private test CA. It covers complete fixed-length, close-delimited and chunked responses; truncated, corrupt, compressed, oversized and partial responses; TLS hostname mismatches; and temporary-file cleanup. It does not change the system trust store, networking or hosts file. The suite requires `openssl`, `curl` and `prlimit`.
