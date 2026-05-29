namespace eval egse::transport {
    variable tcServer ""
    variable tmServer ""
    variable ioServer ""
    variable tcUdp ""
    variable tmUdp ""
    variable ioUdp ""
    variable tmClients {}
    variable ioClients {}
    variable onTcPacket ""
    variable mode "separate"

    proc start {cfg tcCallback} {
        variable onTcPacket
        variable mode
        set onTcPacket $tcCallback
        set mode separate
        if {[dict exists $cfg transport_mode]} {
            set mode [dict get $cfg transport_mode]
        }

        set tcTransport [dict get $cfg tc_transport]
        set tmTransport [dict get $cfg tm_transport]

        if {$mode eq "combined"} {
            if {$tcTransport ne $tmTransport} {
                error "Combined mode requires tc_transport and tm_transport to match"
            }
            if {[dict get $cfg tc_port] != [dict get $cfg tm_port]} {
                error "Combined mode requires tc_port and tm_port to be equal"
            }
            if {$tcTransport eq "tcp"} {
                _startIoTcp [dict get $cfg tc_host] [dict get $cfg tc_port]
            } else {
                _startIoUdp [dict get $cfg tc_host] [dict get $cfg tc_port]
            }
            return
        }

        if {$tcTransport eq "tcp"} {
            _startTcTcp [dict get $cfg tc_host] [dict get $cfg tc_port]
        } else {
            _startTcUdp [dict get $cfg tc_host] [dict get $cfg tc_port]
        }

        if {$tmTransport eq "tcp"} {
            _startTmTcp [dict get $cfg tm_host] [dict get $cfg tm_port]
        } else {
            _startTmUdp [dict get $cfg tm_host] [dict get $cfg tm_port]
        }
    }

    proc stop {} {
        variable tcServer
        variable tmServer
        variable ioServer
        variable tcUdp
        variable tmUdp
        variable ioUdp
        variable tmClients
        variable ioClients

        foreach s $tmClients {
            catch {close $s}
        }
        set tmClients {}

        foreach s $ioClients {
            catch {close $s}
        }
        set ioClients {}

        foreach s [list $tcServer $tmServer $ioServer $tcUdp $tmUdp $ioUdp] {
            if {$s ne ""} {
                catch {close $s}
            }
        }

        set tcServer ""
        set tmServer ""
        set ioServer ""
        set tcUdp ""
        set tmUdp ""
        set ioUdp ""
    }

    proc sendTm {cfg tmPacket} {
        variable mode
        if {$mode eq "combined"} {
            set ioTransport [dict get $cfg tc_transport]
            if {$ioTransport eq "tcp"} {
                _sendIoTcp $tmPacket
            } else {
                _sendIoUdp $cfg $tmPacket
            }
            return
        }

        set tmTransport [dict get $cfg tm_transport]
        if {$tmTransport eq "tcp"} {
            _sendTmTcp $tmPacket
        } else {
            _sendTmUdp $cfg $tmPacket
        }
    }

    proc _startTcTcp {host port} {
        variable tcServer
        set tcServer [socket -server [namespace code _onTcConnect] -myaddr $host $port]
    }

    proc _startTmTcp {host port} {
        variable tmServer
        set tmServer [socket -server [namespace code _onTmConnect] -myaddr $host $port]
    }

    proc _startIoTcp {host port} {
        variable ioServer
        set ioServer [socket -server [namespace code _onIoConnect] -myaddr $host $port]
    }

    proc _onTcConnect {sock addr port} {
        fconfigure $sock -blocking 0 -translation binary -buffering none
        fileevent $sock readable [list [namespace current]::_onTcReadable $sock $addr $port]
    }

    proc _onIoConnect {sock addr port} {
        variable ioClients
        fconfigure $sock -blocking 0 -translation binary -buffering none
        lappend ioClients $sock
        fileevent $sock readable [list [namespace current]::_onIoReadable $sock $addr $port]
    }

    proc _onTmConnect {sock addr port} {
        variable tmClients
        fconfigure $sock -blocking 0 -translation binary -buffering none
        lappend tmClients $sock
        fileevent $sock readable [list [namespace current]::_onTmReadable $sock]
    }

    proc _onTmReadable {sock} {
        if {[eof $sock]} {
            _dropTmClient $sock
            return
        }
        # TM connections are send-only for this simulator, read and discard any input.
        catch {read $sock}
    }

    proc _dropIoClient {sock} {
        variable ioClients
        catch {close $sock}
        set next {}
        foreach s $ioClients {
            if {$s ne $sock} {
                lappend next $s
            }
        }
        set ioClients $next
    }

    proc _dropTmClient {sock} {
        variable tmClients
        catch {close $sock}
        set next {}
        foreach s $tmClients {
            if {$s ne $sock} {
                lappend next $s
            }
        }
        set tmClients $next
    }

    proc _onTcReadable {sock addr port} {
        variable onTcPacket
        if {[eof $sock]} {
            catch {close $sock}
            return
        }

        set data [read $sock]
        if {$data eq ""} {
            return
        }

        {*}$onTcPacket tcp "$addr:$port" $data
    }

    proc _onIoReadable {sock addr port} {
        variable onTcPacket
        if {[eof $sock]} {
            _dropIoClient $sock
            return
        }
        set data [read $sock]
        if {$data eq ""} {
            return
        }
        {*}$onTcPacket tcp "$addr:$port" $data
    }

    proc _sendTmTcp {tmPacket} {
        variable tmClients
        set alive {}
        foreach s $tmClients {
            if {[catch {
                puts -nonewline $s $tmPacket
                flush $s
            }]} {
                catch {close $s}
                continue
            }
            lappend alive $s
        }
        set tmClients $alive
    }

    proc _sendIoTcp {tmPacket} {
        variable ioClients
        set alive {}
        foreach s $ioClients {
            if {[catch {
                puts -nonewline $s $tmPacket
                flush $s
            }]} {
                catch {close $s}
                continue
            }
            lappend alive $s
        }
        set ioClients $alive
    }

    proc _startTcUdp {host port} {
        variable tcUdp
        if {[catch {package require udp}]} {
            error "UDP support requires Tcl udp package"
        }
        set tcUdp [udp_open $port]
        fconfigure $tcUdp -blocking 0 -buffering none -translation binary
        fileevent $tcUdp readable [list [namespace current]::_onTcUdpReadable $tcUdp]
    }

    proc _startTmUdp {host port} {
        variable tmUdp
        if {[catch {package require udp}]} {
            error "UDP support requires Tcl udp package"
        }
        set tmUdp [udp_open $port]
        fconfigure $tmUdp -blocking 0 -buffering none -translation binary
    }

    proc _startIoUdp {host port} {
        variable ioUdp
        if {[catch {package require udp}]} {
            error "UDP support requires Tcl udp package"
        }
        set ioUdp [udp_open $port]
        fconfigure $ioUdp -blocking 0 -buffering none -translation binary
        fileevent $ioUdp readable [list [namespace current]::_onIoUdpReadable $ioUdp]
    }

    proc _onTcUdpReadable {sock} {
        variable onTcPacket
        set data [read $sock]
        if {$data eq ""} {
            return
        }
        set peer [fconfigure $sock -peer]
        {*}$onTcPacket udp $peer $data
    }

    proc _onIoUdpReadable {sock} {
        variable onTcPacket
        set data [read $sock]
        if {$data eq ""} {
            return
        }
        set peer [fconfigure $sock -peer]
        {*}$onTcPacket udp $peer $data
    }

    proc _sendTmUdp {cfg tmPacket} {
        variable tmUdp
        if {$tmUdp eq ""} {
            return
        }
        # For initial milestone, send TM to configured endpoint.
        set host [dict get $cfg tm_host]
        set port [dict get $cfg tm_port]
        fconfigure $tmUdp -remote [list $host $port]
        puts -nonewline $tmUdp $tmPacket
        flush $tmUdp
    }

    proc _sendIoUdp {cfg tmPacket} {
        variable ioUdp
        if {$ioUdp eq ""} {
            return
        }
        set host [dict get $cfg tm_host]
        set port [dict get $cfg tm_port]
        fconfigure $ioUdp -remote [list $host $port]
        puts -nonewline $ioUdp $tmPacket
        flush $ioUdp
    }
}

package provide egse::transport 0.1.0
