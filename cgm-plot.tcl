#!/usr/bin/env tclsh

package require Tcl
package require Tk
package require Plotchart
package require json
package require http
package require tls

set title "CGM Dashboard"

# plot dimensions
set height 500
set width 700

# y-axis
set y_description "Blood Glucose (mg/dL)"
set y_start 0
set y_end 300
set y_step 50
set y_axis [list $y_start $y_end $y_step]

# x-axis
set hours_displayed 6
set time_scale [clock add 0 $hours_displayed hours]
set x_leading_minutes 15
set x_time_format {%l:%M %p}
set x_hour_multiple 3

# high and low cutoffs
set low_cutoff 75
set high_cutoff 140

# socket setup for https requests
http::register https 443 [list ::tls::socket -tls1 1]
 
set nightscout_url ""
set api_endpoint /api/v1/entries/sgv.json

# local_hour: given a timestampe, return the local hour as an integer
proc local_hour {t} {
    set hour [clock format $t -format {%I}]
    scan $hour "%d" hour ;# parse hour string as integer
    return $hour
}

# gen_x_labels: generate x-axis for the plot from the beginning of the timeline
proc gen_x_labels {begin} {
    set labels {}
    for {set i 0} {$i < $::hours_displayed + 1} {incr i} {
        set t [clock add $begin $i hours]
        # use time if it is an approprite multiple, otherwise use a
        # whitespace placeholder so that tickmarks still get rendered
        if {[local_hour $t] % $::x_hour_multiple == 0} {
            lappend labels [clock format $t -format $::x_time_format]
        } else {
            lappend labels " "
        }
    }
    return $labels
}

# config: setup the configurtion for how dots and vectors are rendered
#     on the given plot
proc config {s} {
    $s dotconfig data -colour black -outline off -scalebyvalue off -radius 3
    $s dotconfig current -colour white -outline on -scalebyvalue off -radius 4
    $s vectorconfig low -colour red
    $s vectorconfig high -colour yellow
}

# plot_data: clear the canvas and redraw the plot with the over the timeline
#     using the xlist and ylist data
proc plot_data {start stop xlist ylist} {
    set x_axis [list $start $stop ""]
    # clear the canvas
    .c delete all
    set s [::Plotchart::createXYPlot .c $x_axis $::y_axis -xlabels [gen_x_labels $start]]
    config $s
    $s title $::title
    if {$::tcl_version < 8.6} {
        $s ytext $::y_description
    } else {
        $s vtext $::y_description
    }
    $s vector low $start $::low_cutoff $::time_scale 0
    $s vector high $start $::high_cutoff $::time_scale 0
    # draw data points
    foreach x $xlist y $ylist {
        $s dot data $x $y _
    }
}

# exit gracefully if the window is closed
wm protocol . WM_DELETE_WINDOW {
    exit
}

# initialize canvas
canvas .c -background white -width $width -height $height
pack .c -fill both

while {true} {
    set stop [clock add [clock seconds] $x_leading_minutes minutes]
    set start [clock add $stop -$hours_displayed hours]

    set params [::http::formatQuery count 1000 find\[date\]\[\$gte\] [expr {$start * 1000}]]
    set token [::http::geturl $nightscout_url$api_endpoint?$params]
    ::http::wait $token
    set data [::http::data $token]

    set x_list {}
    set y_list {}
    foreach document [::json::json2dict $data] {
        lappend y_list [dict get $document sgv]
        # convert timestamp units from milliseconds to seconds
        lappend x_list [expr {[dict get $document date] / 1000}]
    }

    plot_data $start $stop $x_list $y_list
    after 3000 ;# sleep before looping
}
