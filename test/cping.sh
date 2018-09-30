#!/usr/bin/env bash

cping() {
    local i=1 # 为了看到效果，这里的255可以写成5
    while [ $i -le 5 ]; do
        if ping -W 1 -c 1 $1.$i &> /dev/null; then
            echo "$1.$i is up"
        else
            echo "$1.$i is down."
        fi
        let i++
    done
}
bping() {
    local j=0 # 为了看到效果，这里的255可以写成5
    while [ $j -le 5 ]; do
            cping $1.$j
            let j++
    done
}
aping() {
    local x=0
    while [ $x -le 255 ]; do
            bping $1.$x
            let x++
    done
}

aping 192

