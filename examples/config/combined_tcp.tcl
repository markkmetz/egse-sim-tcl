set EGSE_CONFIG [dict create \
    transport_mode combined \
    tc_transport tcp \
    tm_transport tcp \
    tc_host 127.0.0.1 \
    tc_port 5100 \
    tm_host 127.0.0.1 \
    tm_port 5100 \
    mib_root "examples/mibs" \
    mib_set generic \
    log_file "logs/packets_combined.log"]
