#!/bin/bash

# Interval between each sample in seconds
INTERVAL=5

# Function to get CPU usage
get_cpu_usage() {
    top -bn1 | grep "Cpu(s)" | \
    sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | \
    awk '{print 100 - $1"%"}'
}

# Function to get memory usage
get_memory_usage() {
    free -m | awk 'NR==2{printf "Memory Usage: %s/%sMB (%.2f%%)\n", $3, $2, $3*100/$2 }'
}

# Main function to monitor the system
monitor_system() {
    while true; do
        clear
        echo "System Monitoring Script"
        echo "========================"
        echo "CPU Usage: $(get_cpu_usage)"
        get_memory_usage
        sleep $INTERVAL
    done
}

# Run the monitoring function
monitor_system
