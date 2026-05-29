package require tcltest
namespace import ::tcltest::*

set here [file dirname [file normalize [info script]]]
set root [file dirname $here]

source [file join $root lib egse dispatcher.tcl]

proc testActionOk {decodedTc} {
    return [dict create \
        status ok \
        tm_service_type 17 \
        tm_subservice 2 \
        tm_param_values [dict get $decodedTc decoded_values]]
}

proc on_S2KTC001 {params} {
    set ::listener_params $params
}

proc on_S2KTC002 {decodedTc} {
    set ::listener_service [dict get $decodedTc service_type]
}

proc bad_listener {params} {
    error "listener failed"
}

proc reset_dispatcher_test_state {} {
    set ::listener_params {}
    set ::listener_service -1
    egse::dispatch::clearCommandListeners
}

set decoded001 [dict create \
    service_type 17 \
    subservice 1 \
    decoded_values [dict create echo_data 4660] \
    command_def [dict create command_name S2KTC001 action test_action_1]]

set decoded002 [dict create \
    service_type 3 \
    subservice 1 \
    decoded_values [dict create voltage_mv 3300] \
    command_def [dict create command_name S2KTC002 action test_action_2]]

set decoded003 [dict create \
    service_type 8 \
    subservice 2 \
    decoded_values [dict create setpoint_cdec 250] \
    command_def [dict create command_name S2KTC003 action test_action_3]]

test dispatch-listener-001 {params listener receives decoded_values} -setup {
    reset_dispatcher_test_state
    egse::dispatch::registerHandler test_action_1 testActionOk
    egse::dispatch::registerCommandListener S2KTC001 on_S2KTC001 params
} -body {
    set result [egse::dispatch::handleTc $decoded001]
    list \
        [dict get $::listener_params echo_data] \
        [dict get $result status]
} -cleanup {
    reset_dispatcher_test_state
} -result {4660 ok}

test dispatch-listener-002 {on_<command> helper registers decodedTc listener} -setup {
    reset_dispatcher_test_state
    egse::dispatch::registerHandler test_action_2 testActionOk
    egse::dispatch::registerListenerByProcName on_S2KTC002 decodedTc
} -body {
    set result [egse::dispatch::handleTc $decoded002]
    list \
        $::listener_service \
        [dict get $result status]
} -cleanup {
    reset_dispatcher_test_state
} -result {3 ok}

test dispatch-listener-003 {listener failures are isolated from action handler} -setup {
    reset_dispatcher_test_state
    egse::dispatch::registerHandler test_action_3 testActionOk
    egse::dispatch::registerCommandListener S2KTC003 bad_listener params
} -body {
    set result [egse::dispatch::handleTc $decoded003]
    list \
        [dict get $result status] \
        [dict get [dict get $result tm_param_values] setpoint_cdec]
} -cleanup {
    reset_dispatcher_test_state
} -result {ok 250}

test dispatch-listener-004 {unregister removes listener callback} -setup {
    reset_dispatcher_test_state
    egse::dispatch::registerHandler test_action_1 testActionOk
    egse::dispatch::registerCommandListener S2KTC001 on_S2KTC001 params
    egse::dispatch::unregisterCommandListener S2KTC001 on_S2KTC001
} -body {
    egse::dispatch::handleTc $decoded001
    list \
        [llength [egse::dispatch::listCommandListeners S2KTC001]] \
        [dict size $::listener_params]
} -cleanup {
    reset_dispatcher_test_state
} -result {0 0}

cleanupTests
