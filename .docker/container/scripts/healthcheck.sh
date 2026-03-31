#!/bin/bash
set -e

# Check critical services
ERRORS=0
BOOT_INIT="/etc/dockraft/scripts/boot-init.sh"
BOOT_INIT_START_TIME_FILE="/root/sindla/boot-init-container-start-time"

if [ -f $BOOT_INIT ]; then
    if [ -f $BOOT_INIT_START_TIME_FILE ]; then
        START_TIME=$(cat "$BOOT_INIT_START_TIME_FILE")
        CURRENT_TIME=$(date +%s)
        ELAPSED_TIME=$((CURRENT_TIME - START_TIME))

        if [ $ELAPSED_TIME -gt 600 ]; then
            echo "WARNING: Boot script exists after $((ELAPSED_TIME / 60)) minutes since container start"
            # @TODO: Log or remediation action
        else
            echo "Container initializing... $((ELAPSED_TIME / 60)) minutes elapsed"
            exit 0
        fi
    else
        echo "Boot initialization in progress, no start time recorded"
        exit 0
    fi
fi


# 1. Check Nginx
if ! pgrep nginx > /dev/null; then
    echo "ERROR: Nginx is not running"
    ERRORS=$((ERRORS + 1))
fi

# 2. Check PHP-FPM
if ! pgrep php-fpm > /dev/null; then
    echo "ERROR: PHP-FPM is not running"
    ERRORS=$((ERRORS + 1))
fi

# 3. Check PostgreSQL (if installed)
if [ "${DKZ_POSTGRESQL_VERSION_INSTALL:-0}" != "0" ]; then
    if ! pgrep postgres > /dev/null; then
        echo "ERROR: PostgreSQL is not running"
        ERRORS=$((ERRORS + 1))
    fi

    # Test database connection
    if ! su - postgres -c "psql -d $DKZ_POSTGRESQL_DATABASE -c 'SELECT 1;'" > /dev/null 2>&1; then
        echo "ERROR: Cannot connect to PostgreSQL database"
        ERRORS=$((ERRORS + 1))
    fi
fi

# 4. Check HTTP response
if command -v curl >/dev/null 2>&1; then
    if ! curl -f http://localhost/ > /dev/null 2>&1; then
        echo "ERROR: HTTP service not responding"
        ERRORS=$((ERRORS + 1))
    fi
fi

# 5. Check disk space
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "WARNING: Disk usage is ${DISK_USAGE}%"
fi

# 6. Check memory usage
MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
if [ "$MEM_USAGE" -gt 80 ]; then
    echo "WARNING: Memory usage is ${MEM_USAGE}%"
fi

if [ $ERRORS -eq 0 ]; then
    echo "All services are healthy"
    exit 0
else
    echo "Health check failed with $ERRORS error(s)"
    exit 1
fi
