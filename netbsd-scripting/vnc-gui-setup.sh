#!/bin/sh

# vnc-mate-setup.sh - Manage Xvfb + MATE/XFCE + x11vnc on NetBSD
# Streamlines remote desktop access via VNC and SSH tunneling.

# --- Configuration ---
DISPLAY_ID="1"
DISPLAY=":${DISPLAY_ID}"
RESOLUTION="1280x800x24"
VNC_PORT="5901"
LOG_DIR="/tmp"
DEFAULT_DESKTOP="mate"

# PID files
XVFB_PID="${LOG_DIR}/Xvfb-${DISPLAY_ID}.pid"
DESKTOP_PID="${LOG_DIR}/desktop-${DISPLAY_ID}.pid"
VNC_PID="${LOG_DIR}/vnc-${DISPLAY_ID}.pid"

# Logs
XVFB_LOG="${LOG_DIR}/Xvfb-${DISPLAY_ID}.log"
DESKTOP_LOG="${LOG_DIR}/desktop-${DISPLAY_ID}.log"
VNC_LOG="${LOG_DIR}/x11vnc-${DISPLAY_ID}.log"

# Path to binaries (adjust if necessary)
XVFB_BIN="Xvfb"
MATE_BIN="mate-session"
XFCE_BIN="xfce4-session"
VNC_BIN="x11vnc"

check_deps() {
    desktop_bin=$1
    for cmd in "$XVFB_BIN" "$desktop_bin" "$VNC_BIN"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Error: $cmd is not installed or not in PATH."
            exit 1
        fi
    done
}

check_passwd() {
    if [ ! -f "$HOME/.vnc/passwd" ]; then
        echo "Warning: VNC password file not found at $HOME/.vnc/passwd"
        echo "Please run: $VNC_BIN -storepasswd"
        exit 1
    fi
}

status() {
    running=0
    for pfile in "$XVFB_PID" "$DESKTOP_PID" "$VNC_PID"; do
        name=$(basename "$pfile" .pid | cut -d- -f1)
        if [ -f "$pfile" ]; then
            pid=$(cat "$pfile")
            if kill -0 "$pid" 2>/dev/null; then
                # For the desktop process, try to be more specific
                display_name="$name"
                if [ "$name" = "desktop" ]; then
                    cmd=$(ps -p "$pid" -o command= 2>/dev/null)
                    case "$cmd" in
                        *mate-session*) display_name="MATE" ;;
                        *xfce4-session*) display_name="XFCE4" ;;
                        *) display_name="desktop" ;;
                    esac
                fi
                echo "$display_name is running (PID: $pid)"
                running=$((running + 1))
            else
                echo "$name PID file exists ($pid), but process is dead."
            fi
        else
            echo "$name is NOT running"
        fi
    done
    return $running
}

start() {
    CHOICE=${1:-$DEFAULT_DESKTOP}
    case "$CHOICE" in
        mate) DESKTOP_BIN="$MATE_BIN"; DESKTOP_NAME="MATE" ;;
        xfce|xfce4) DESKTOP_BIN="$XFCE_BIN"; DESKTOP_NAME="XFCE4" ;;
        *) echo "Unknown desktop: $CHOICE (use 'mate' or 'xfce')"; exit 1 ;;
    esac

    check_deps "$DESKTOP_BIN"
    check_passwd

    if [ -f "$XVFB_PID" ] && kill -0 $(cat "$XVFB_PID") 2>/dev/null; then
        echo "A session appears to be already running on ${DISPLAY}."
        echo "Use '$0 stop' first."
        exit 1
    fi

    echo "1. Starting Xvfb on ${DISPLAY} (${RESOLUTION})..."
    "$XVFB_BIN" "${DISPLAY}" -screen 0 "${RESOLUTION}" > "${XVFB_LOG}" 2>&1 &
    echo $! > "$XVFB_PID"
    
    # Wait for X server to start
    echo "   Waiting for X server to initialize..."
    sleep 3

    echo "2. Starting ${DESKTOP_NAME} Session..."
    export DISPLAY="${DISPLAY}"
    # Redirecting output to log
    "$DESKTOP_BIN" > "${DESKTOP_LOG}" 2>&1 &
    echo $! > "$DESKTOP_PID"

    echo "3. Starting x11vnc on port ${VNC_PORT}..."
    # -localhost: only listen on 127.0.0.1 (safe for SSH tunneling)
    # -forever: keep listening after client disconnects
    # -bg: run in background
    # -pidfile: record PID
    # -rfbauth: use stored password
    "$VNC_BIN" -display "${DISPLAY}" -rfbport "${VNC_PORT}" -localhost -forever -bg -o "${VNC_LOG}" -rfbauth "$HOME/.vnc/passwd" -pidfile "$VNC_PID"
    
    echo ""
    echo "Success! Virtual desktop is ready."
    echo "--------------------------------------------------------"
    echo "To connect from your remote machine:"
    echo "1. Run this SSH tunnel command on your local machine:"
    echo "   ssh -N -L 127.0.0.1:${VNC_PORT}:127.0.0.1:${VNC_PORT} $(whoami)@$(hostname)"
    echo "2. Connect your VNC viewer to: 127.0.0.1:${VNC_PORT}"
    echo "--------------------------------------------------------"
}

stop() {
    echo "Stopping VNC session..."
    [ -f "$VNC_PID" ] && kill $(cat "$VNC_PID") 2>/dev/null && rm "$VNC_PID"
    [ -f "$DESKTOP_PID" ] && kill $(cat "$DESKTOP_PID") 2>/dev/null && rm "$DESKTOP_PID"
    [ -f "$XVFB_PID" ] && kill $(cat "$XVFB_PID") 2>/dev/null && rm "$XVFB_PID"
    echo "All processes stopped."
}

verify() {
    echo "Checking port ${VNC_PORT}..."
    if command -v nc >/dev/null 2>&1; then
        if nc -vz 127.0.0.1 "${VNC_PORT}" 2>/dev/null; then
            echo "Port ${VNC_PORT} is open and listening."
        else
            echo "Port ${VNC_PORT} is NOT listening."
        fi
    else
        echo "nc command not found, skipping network check."
    fi
}

case "$1" in
    start)   start "$2" ;;
    stop)    stop ;;
    status)  status ;;
    verify)  verify ;;
    restart) stop; sleep 2; start "$2" ;;
    *) echo "Usage: $0 {start|stop|status|restart|verify} [mate|xfce]"; exit 1 ;;
esac
