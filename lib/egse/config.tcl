namespace eval egse::config {
    variable defaultConfig [dict create \
        egse_type rf \
        mib_root "examples/mibs" \
        mib_set generic \
        transport_mode separate \
        tc_transport tcp \
        tm_transport tcp \
        tc_host 127.0.0.1 \
        tc_port 5000 \
        tm_host 127.0.0.1 \
        tm_port 5001 \
        log_file "logs/packets.log" \
        log_rotate_bytes 10485760 \
        log_rotate_files 5 \
        log_verbose 1]

    proc defaults {} {
        variable defaultConfig
        return $defaultConfig
    }

    proc load {configPath} {
        set cfg [defaults]
        if {$configPath eq ""} {
            return $cfg
        }
        if {![file exists $configPath]} {
            error "Config file does not exist: $configPath"
        }

        # Config file must define global variable EGSE_CONFIG with a dict value.
        catch {unset ::EGSE_CONFIG}
        uplevel #0 [list source $configPath]
        if {![info exists ::EGSE_CONFIG]} {
            error "Config file must define non-empty dict variable EGSE_CONFIG"
        }
        if {![dict size $::EGSE_CONFIG]} {
            error "Config file must define non-empty dict variable EGSE_CONFIG"
        }

        dict for {k v} $::EGSE_CONFIG {
            dict set cfg $k $v
        }
        return $cfg
    }
}

package provide egse::config 0.1.0
