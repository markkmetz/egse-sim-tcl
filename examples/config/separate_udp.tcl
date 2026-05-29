set EGSE_CONFIG [dict create \
    transport_mode separate \
    tc_transport udp \
    tm_transport udp \
    tc_host 127.0.0.1 \
    tc_port 5200 \
    tm_host 127.0.0.1 \
    tm_port 5201 \
    mib_root "examples/mibs" \
    mib_set generic \
    log_file "logs/packets_udp.log"]
