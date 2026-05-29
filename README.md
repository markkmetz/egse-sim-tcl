# EGSE Simulator (Tcl)

Pure Tcl EGSE simulator for SCOS2000-style MIB workflows.

Implemented features:
- Decode TC packets with CCSDS Space Packet + minimal PUS TC secondary header.
- Load SCOS2000-style ASCII `.dat` table sets from a MIB root directory.
- Support multiple MIB sets (examples: `generic`, `powerlab`).
- Dispatch decoded TC commands via EGSE type modules (one file per EGSE).
- Build TM responses from MIB metadata (`pid.dat` + `plf.dat`) and action-returned parameter values.
- Support non-blocking asynchronous sockets for TCP and UDP.
- Support separate TC/TM sockets and combined I/O mode via config.
- Write persistent verbose logs with packet hex and decoded fields.
- Rotate logs with size-based retention.
- Provide targeted tests for MIB integrity, decoding, and socket flow.

## Layout

- `bin/egse_sim.tcl`: main entry point.
- `lib/egse/*.tcl`: core library modules.
- `lib/egse/egse_types/*.tcl`: one file per EGSE (settings + action handlers + registrations).
- `examples/mibs/*`: sample MIB sets per EGSE profile.
- `examples/config/*.tcl`: runnable transport/config profiles.
- `tests`: tcltest suites.

## Add a new EGSE simulator

The simulator now loads one EGSE file based on `egse_type`, so you do not edit `bin/egse_sim.tcl` when adding a new EGSE.

1. Create one file: `lib/egse/egse_types/<egse_type>.tcl`.
2. Define `proc ::egse::type::<egse_type>::settings {}` that returns EGSE defaults (for example `mib_set`).
3. Define your action procs in the same file.
4. Define `proc ::egse::type::<egse_type>::register {rootDir}` and register actions with `egse::dispatch::registerHandler`.
5. Set `egse_type` in your config file to match `<egse_type>`.

Minimal one-file example:

```tcl
namespace eval egse::type::thermal {
	proc settings {} {
		return [dict create mib_set thermal egse_type thermal]
	}

	proc action_setpoint {decodedTc} {
		return [dict create status ok tm_service_type 5 tm_subservice 2 tm_param_values [dict create]]
	}

	proc register {rootDir} {
		egse::dispatch::registerHandler thermal_setpoint ::egse::type::thermal::action_setpoint
	}
}
```

Known built-in EGSE files in this repo:
- `rf`
- `generic`
- `powerlab`

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
