namespace eval ::egse::type::thermal {
    proc settings {} {
        return [dict create \
            mib_set thermal \
            egse_type thermal]
    }

    proc action_thermal_set_setpoint {decodedTc} {
        set values [dict get $decodedTc decoded_values]
        if {![dict exists $values setpoint_cdec]} {
            dict set values setpoint_cdec 0
        }
        return [dict create \
            status ok \
            tm_service_type 8 \
            tm_subservice 2 \
            tm_param_values [dict create setpoint_cdec [dict get $values setpoint_cdec]]]
    }

    proc action_thermal_ping {decodedTc} {
        set values [dict get $decodedTc decoded_values]
        if {![dict exists $values echo_data]} {
            dict set values echo_data 0
        }
        return [dict create \
            status ok \
            tm_service_type 8 \
            tm_subservice 6 \
            tm_param_values [dict create echo_data [dict get $values echo_data]]]
    }

    proc register {rootDir} {
        egse::dispatch::registerHandler thermal_set_setpoint ::egse::type::thermal::action_thermal_set_setpoint
        egse::dispatch::registerHandler thermal_ping ::egse::type::thermal::action_thermal_ping
    }
}

package provide egse::type::thermal 0.1.0
