#!/usr/bin/env bash
declare -i uphosts=0
declare -i downhosts=0
declare -i i=1

hostping() {
    if ping -W 1 -c 1 $1 &> /dev/null; then
        echo "$1 is up."
        let uphosts+=1
    else
        echo "$1 is down."
        let downhosts+=1
    fi
}
while [ $i -le 40 ]; do
    hostping 124.207.169.$i
    let i++
done
echo "Up hosts: $uphosts, Down hosts: $downhosts."
