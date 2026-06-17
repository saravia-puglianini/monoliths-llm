#!/bin/dash

export DISPLAY=:0
xterm -e "cd && bash monoliths-llm/simple_second_counter.sh $1"
