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
- `lib/egse_worker.tcl`: child worker started by supervisor for each startup file.
- `bin/*.tcl`: EGSE type files (one file per EGSE with combined config + handlers).
- `bin/esa_tc_demo.tcl`: EGSE-1 startup file (includes EGSE_CONFIG + listeners).
- `bin/egse2_demo.tcl`: EGSE-2 startup file (includes EGSE_CONFIG + listeners).
- `lib/egse/*.tcl`: core library modules.
- `MIBS/`: sample MIB sets per EGSE profile.
- `tests`: tcltest suites.

## Add a new EGSE simulator

Each EGSE simulator is defined in a single file `bin/<egse_type>.tcl` that includes both configuration defaults and action handlers.

1. Create one file: `bin/<egse_type>.tcl`.
2. Define `proc ::egse::type::<egse_type>::config {}` that returns EGSE config defaults (mib_set, ports, etc.).
3. Define `proc ::egse::type::<egse_type>::settings {}` that returns EGSE-specific overrides.
4. Define your action procs in the same namespace.
5. Define `proc ::egse::type::<egse_type>::register {rootDir}` and register actions with `egse::dispatch::registerHandler`.

Minimal one-file example:

```tcl
namespace eval egse::type::thermal {
	proc config {} {
		return [dict create \
			egse_type thermal \
			mib_root "MIBS" \
			mib_set thermal \
			tc_port 5300 \
			tm_port 5301 \
			log_file "logs/packets_thermal.log"]
	}

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
- `thermal`

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

`egse_sim.tcl` now runs in supervisor mode only.
It launches child simulators listed in `EGSE_SIMULATORS`.

Edit `bin/egse_sim.tcl` and uncomment/add the startup files you want:

```tcl
set EGSE_SIMULATORS [list]
# lappend EGSE_SIMULATORS "bin/esa_tc_demo.tcl"
# lappend EGSE_SIMULATORS "bin/egse2_demo.tcl"
```

Then run:

```bash
cd /home/markkmetz/egse-sim-tcl
tclsh bin/egse_sim.tcl
```

## Run multiple simulators from one main loop

Edit `bin/egse_sim.tcl` and uncomment the `lappend EGSE_SIMULATORS ...` lines near the top.

```tcl
set EGSE_SIMULATORS [list]
# lappend EGSE_SIMULATORS "bin/esa_tc_demo.tcl"
# lappend EGSE_SIMULATORS "bin/egse2_demo.tcl"
```

Then run:

```bash
cd /home/markkmetz/egse-sim-tcl
tclsh bin/egse_sim.tcl
```

Optional: pass a launcher file that defines `EGSE_SIMULATORS`:

```bash
cd /home/markkmetz/egse-sim-tcl
tclsh bin/egse_sim.tcl path/to/launcher.tcl
```

Each EGSE startup file contains both:
1. `EGSE_CONFIG` (ports, mib_set, log file)
2. TC listener procs and registrations

To add another simulator:
1. Create `bin/<your_egse>.tcl` with `EGSE_CONFIG` + listener procs.
2. Add another `lappend EGSE_SIMULATORS "bin/<your_egse>.tcl"` line in `bin/egse_sim.tcl`.
3. Comment/uncomment `lappend` lines to enable/disable simulators.
4. Give each EGSE file unique `tc_port` and `tm_port`.
5. Set one `mib_set` per EGSE file (for example `MIBS/<mib_set>/`).

The demo listener implementation is in `bin/esa_tc_demo.tcl` and uses your pattern:

```tcl
proc on_S2KTC001 {params} {
	# your code here
}
egse::dispatch::registerCommandListener S2KTC001 on_S2KTC001 params
```

Default sockets:
- TC TCP server: `localhost:5000`
- TM TCP server: `localhost:5001`

## Add a TC listener

You can register listener procs that run when a decoded TC command is received.
This is additive: existing action handlers still run and TM generation is unchanged.

Listener proc naming pattern:

```tcl
proc on_S2KTC001 {params} {
	# params is decoded_values, for example: dict get $params echo_data
	puts "S2KTC001 received params=$params"
}

# Explicit registration
egse::dispatch::registerCommandListener S2KTC001 on_S2KTC001 params

# Or infer command id from proc name on_<COMMAND_ID>
egse::dispatch::registerListenerByProcName on_S2KTC001 params
```

You can also register listeners that receive the full decoded TC dict:

```tcl
proc on_S2KTC001_full {decodedTc} {
	puts "apid=[dict get [dict get $decodedTc space_packet] apid]"
}
egse::dispatch::registerCommandListener S2KTC001 on_S2KTC001_full decodedTc
```

## Notes

- UDP mode requires Tcl `udp` package (`package require udp`).
- SCOS2000 ASCII `.dat` files are loaded from `MIBS/<mib_set>/`.
