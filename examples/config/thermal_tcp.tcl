set EGSE_CONFIG [dict create \
    egse_type thermal \
    transport_mode separate \
    tc_transport tcp \
    tm_transport tcp \
    tc_host 127.0.0.1 \
    tc_port 5300 \
    tm_host 127.0.0.1 \
    tm_port 5301 \
    mib_root "examples/mibs" \
    mib_set thermal \
    log_file "logs/packets_thermal.log"]
