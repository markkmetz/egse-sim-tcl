# EGSE-2 startup file.
# One file per EGSE: config + listeners live together.

set EGSE_CONFIG [dict create \
    egse_type generic \
    transport_mode separate \
    tc_transport tcp \
    tm_transport tcp \
    tc_host 127.0.0.1 \
    tc_port 6000 \
    tm_host 127.0.0.1 \
    tm_port 6001 \
    mib_root "MIBS" \
    mib_set generic \
    log_file "logs/packets_egse2.log"]

proc _egse2_print_tc_params {commandName params} {
    puts "[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}] EGSE2 TC $commandName"
    if {[dict size $params] == 0} {
        puts "  (no decoded parameters)"
        return
    }
    dict for {k v} $params {
        puts "  $k = $v"
    }
}

proc on_S2KTC002 {params} {
    _egse2_print_tc_params S2KTC002 $params
}

egse::dispatch::registerCommandListener S2KTC002 on_S2KTC002 params
