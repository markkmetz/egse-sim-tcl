# EGSE-1 startup file (ESA SCOS2000 demo).
# Use directly with egse_sim.tcl:
#   tclsh bin/egse_sim.tcl bin/esa_tc_demo.tcl
#
# It includes BOTH runtime config (EGSE_CONFIG) and TC listeners.
# Expand by adding more on_<COMMAND_ID> procs and registrations.

set EGSE_CONFIG [dict create \
    egse_type generic \
    transport_mode separate \
    tc_transport tcp \
    tm_transport tcp \
    tc_host 127.0.0.1 \
    tc_port 5000 \
    tm_host 127.0.0.1 \
    tm_port 5001 \
    mib_root "MIBS" \
    mib_set generic \
    log_file "logs/packets_esa_demo.log"]

proc _demo_print_tc_params {commandName params} {
    puts "[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}] TC $commandName"
    if {[dict size $params] == 0} {
        puts "  (no decoded parameters)"
        return
    }
    dict for {k v} $params {
        puts "  $k = $v"
    }
}

# Example from ESA generic MIB CCF/CDF tables.
# S2KTC001 has parameters such as HPC Module, HPC Line ID, HPC Pulse Duration.
proc on_S2KTC001 {params} {
    _demo_print_tc_params S2KTC001 $params
}

# Another example that prints any decoded parameters for S2KTC005.
proc on_S2KTC005 {params} {
    _demo_print_tc_params S2KTC005 $params
}

egse::dispatch::registerCommandListener S2KTC001 on_S2KTC001 params
egse::dispatch::registerCommandListener S2KTC005 on_S2KTC005 params
