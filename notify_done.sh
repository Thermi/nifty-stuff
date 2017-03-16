#! /bin/bash

# Purpose is to run that after some long task to tell users that it's done.
# E.g. xz -9 giantfile ; notify_done
# paplay needs pulseaudio.

function notify_done {
    paplay /usr/share/sounds/freedesktop/stereo/complete.oga
}
