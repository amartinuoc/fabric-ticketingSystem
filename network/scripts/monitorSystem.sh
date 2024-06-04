#!/bin/bash

# Intervalo de tiempo entre cada muestra en segundos
INTERVAL=5

# Función para obtener el uso del procesador
get_cpu_usage() {
    top -bn1 | grep "Cpu(s)" | \
    sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | \
    awk '{print 100 - $1"%"}'
}

# Función para obtener el uso de memoria
get_memory_usage() {
    free -m | awk 'NR==2{printf "Memory Usage: %s/%sMB (%.2f%%)\n", $3, $2, $3*100/$2 }'
}

# Función principal para monitorizar
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

# Ejecutar la función de monitorización
monitor_system