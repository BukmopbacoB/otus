#!/bin/sh
# echo $(( RANDOM % 101 ))

case "$1" in
  metric1) echo $(( RANDOM % 80 ));;       # 0-79
  metric2) echo $(( RANDOM % 101 ));;      # 0-100
  metric3) echo $(( 70 + RANDOM % 31 ));;  # 70-100
esac