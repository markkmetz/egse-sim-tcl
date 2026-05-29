# EGSE Simulator (Tcl)

Pure Tcl EGSE simulator for SCOS2000-style MIB workflows.

Implemented features:
- Decode TC packets with CCSDS Space Packet + minimal PUS TC secondary header.
- Load SCOS2000-style ASCII `.dat` table sets from a MIB root directory.
- Support multiple MIB sets (examples: `generic`, `powerlab`).
- Dispatch decoded TC commands to pluggable EGSE actions (RF and power supply stubs).
- Build TM responses from MIB metadata (`pid.dat` + `plf.dat`) and action-returned parameter values.
- Support non-blocking asynchronous sockets for TCP and UDP.
- Support separate TC/TM sockets and combined I/O mode via config.
- Write persistent verbose logs with packet hex and decoded fields.
- Rotate logs with size-based retention.
- Provide targeted tests for MIB integrity, decoding, and socket flow.

## Layout

- `bin/egse_sim.tcl`: main entry point.
- `lib/egse/*.tcl`: core library modules.
- `lib/egse/plugins/*.tcl`: EGSE action stubs.
- `examples/mibs/*`: sample MIB sets per EGSE profile.
- `examples/config/*.tcl`: runnable transport/config profiles.
- `tests`: tcltest suites.

## Run tests

```bash
cd /home/markkmetz/egse-sim-tcl
tclsh tests/run_all.tcl
```

## Run simulator

```bash
cd /home/markkmetz/egse-sim-tcl
tclsh bin/egse_sim.tcl
```

Run with explicit config profile:

```bash
cd /home/markkmetz/egse-sim-tcl
tclsh bin/egse_sim.tcl examples/config/separate_tcp.tcl
```

Available profile examples:
- `examples/config/separate_tcp.tcl`
- `examples/config/combined_tcp.tcl`
- `examples/config/separate_udp.tcl`

Default sockets:
- TC TCP server: `localhost:5000`
- TM TCP server: `localhost:5001`

## Notes

- UDP mode requires Tcl `udp` package (`package require udp`).
- The included `.dat` format is a practical SCOS-style, headered, pipe-delimited starter format for fast iteration.
