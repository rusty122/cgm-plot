#!/usr/bin/tclsh

package require Tcl
package require Tk
package require Plotchart

# constants for plot dimensions
set width 700
set height 500

# constants for y-axis scale and ticklines
set y_start 0
set y_end 300
set y_step 50

# constants for low and high cutoffs
set low_cutoff 75
set high_cutoff 140

canvas .c -background white -width $width -height $height
pack .c -fill both

# Setup timescale
set stop  [clock add [clock seconds] 15 minutes]
set start [clock add $stop -12 hours]

set x_times {}
for {set i 0} {$i < 13} {incr i} {
    set t [clock add $start $i hours]
    # only use time if hour is multiple of 3 (e.g. 3:00, 6:00, 9:00, 12:00)
    # otherwise use empty string placeholder so hourly tickmarks still rendered
    set hour [clock format $t -format {%I}]
    scan $hour "%d" hour
    if {$hour % 3 == 0} {
        lappend x_times [clock format $t -format {%l:%M %p}]
    } else {
        lappend x_times " "
    }
}

set s [::Plotchart::createXYPlot .c [list $start $stop ""] [list $y_start $y_end $y_step] -xlabels $x_times]

# Perform configuration
$s dotconfig data -colour black -outline off -scalebyvalue off -radius 3.5
$s dotconfig current -colour white -outline on -scalebyvalue off -radius 4
$s vectorconfig low -colour red
$s vectorconfig high -colour yellow
$s balloonconfig -outline white

$s vector low $start $low_cutoff [expr {$stop - $start}] 0
$s vector high $start $high_cutoff [expr {$stop - $start}] 0

# Set chart title and axis labels
$s title "CGM Dashboard"
if {$tcl_version < 8.6} {
    $s ytext "BG (mg/dL)"
} else {
    $s vtext "Blood Glucose (mg/dL)"
}

# bogus data
set tmp [clock seconds]
# Plot data here
$s dot data $tmp 140 _
$s dot current $tmp 120 _
$s dot data $tmp 50 _

$s balloon $tmp 145 "Max: 140" south
$s balloon $tmp 45 "Min: 50" north
