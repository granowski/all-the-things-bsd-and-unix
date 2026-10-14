#!/bin/sh

DISPLAY_ID=1
DISPLAY=":${DISPLAY_ID}"
RESOLUTION=1280x800x24
VNC_PORT=5901
DEFAULT_DESKTOP=mate
VNC_PASSWD="${HOME}/.vnc/passwd"
RUNTIME_DIR="/tmp/vnc-gui-setup-$(id -u)"

XVFB_BIN=Xvfb
MATE_BIN=mate-session
XFCE_BIN=xfce4-session
VNC_BIN=x11vnc

XVFB_PID="${RUNTIME_DIR}/Xvfb-${DISPLAY_ID}.pid"
DESKTOP_PID="${RUNTIME_DIR}/desktop-${DISPLAY_ID}.pid"
VNC_PID="${RUNTIME_DIR}/vnc-${DISPLAY_ID}.pid"
XVFB_LOG="${RUNTIME_DIR}/Xvfb-${DISPLAY_ID}.log"
DESKTOP_LOG="${RUNTIME_DIR}/desktop-${DISPLAY_ID}.log"
VNC_LOG="${RUNTIME_DIR}/x11vnc-${DISPLAY_ID}.log"

usage() {
    echo "Usage: $0 {start|stop|status|restart|verify|storepasswd} [mate|xfce]"
}

check_deps() {
    desktop_bin=$1
    for cmd in "$XVFB_BIN" "$desktop_bin" "$VNC_BIN"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Error: $cmd is not installed or not in PATH." >&2
            return 1
        fi
    done
}

process_matches() {
    pid=$1
    expected=$2
    case "$pid" in
        ''|*[!0-9]*) return 1 ;;
    esac
    kill -0 "$pid" 2>/dev/null || return 1
    command_line=$(ps -p "$pid" -o command= 2>/dev/null) || return 1
    case "$command_line" in
        $expected) return 0 ;;
        *) return 1 ;;
    esac
}

matches_process() {
    pid=$1
    expected=$2
    case "$expected" in
        desktop)
            process_matches "$pid" '*mate-session*' ||
                process_matches "$pid" '*xfce4-session*'
            ;;
        *) process_matches "$pid" "$expected" ;;
    esac
}

read_pid() {
    pid_file=$1
    [ -f "$pid_file" ] || return 1
    pid=$(cat "$pid_file") || return 1
    case "$pid" in
        ''|*[!0-9]*) return 1 ;;
    esac
}

stop_one() {
    pid_file=$1
    label=$2
    expected=$3

    if ! read_pid "$pid_file"; then
        [ ! -f "$pid_file" ] || rm -f "$pid_file"
        return 0
    fi

    if ! matches_process "$pid" "$expected"; then
        echo "$label PID file is stale or does not match; not signaling PID $pid." >&2
        rm -f "$pid_file"
        return 0
    fi

    echo "Stopping $label (PID: $pid)..."
    if ! kill -TERM "$pid" 2>/dev/null; then
        echo "Error: could not stop $label (PID: $pid)." >&2
        return 1
    fi
    count=0
    while matches_process "$pid" "$expected" && [ "$count" -lt 5 ]; do
        sleep 1
        count=$((count + 1))
    done
    if matches_process "$pid" "$expected"; then
        if ! kill -KILL "$pid" 2>/dev/null; then
            echo "Error: could not force-stop $label (PID: $pid)." >&2
            return 1
        fi
    fi
    rm -f "$pid_file"
}

stop() {
    result=0
    stop_one "$VNC_PID" x11vnc "*x11vnc*${DISPLAY}*" || result=1
    stop_one "$DESKTOP_PID" "desktop session" desktop || result=1
    stop_one "$XVFB_PID" Xvfb "*Xvfb*${DISPLAY}*" || result=1
    if [ "$result" -eq 0 ]; then
        echo "Virtual desktop stopped."
    fi
    return "$result"
}

status_one() {
    pid_file=$1
    label=$2
    expected=$3

    if ! read_pid "$pid_file"; then
        echo "$label is not running"
        return 1
    fi
    if matches_process "$pid" "$expected"; then
        echo "$label is running (PID: $pid)"
        return 0
    fi
    echo "$label PID file exists ($pid), but no matching process is running."
    return 1
}

status() {
    result=0
    status_one "$XVFB_PID" Xvfb "*Xvfb*${DISPLAY}*" || result=1
    status_one "$DESKTOP_PID" "desktop session" desktop || result=1
    status_one "$VNC_PID" x11vnc "*x11vnc*${DISPLAY}*" || result=1
    return "$result"
}

start() {
    choice=${1:-$DEFAULT_DESKTOP}
    case "$choice" in
        mate) desktop_bin=$MATE_BIN; desktop_name=MATE ;;
        xfce|xfce4) desktop_bin=$XFCE_BIN; desktop_name=XFCE4 ;;
        *)
            echo "Unknown desktop: $choice (use 'mate' or 'xfce')." >&2
            return 1
            ;;
    esac

    check_deps "$desktop_bin" || return 1
    if [ ! -r "$VNC_PASSWD" ]; then
        echo "VNC password file not found or not readable: $VNC_PASSWD" >&2
        echo "Run '$0 storepasswd' to create it." >&2
        return 1
    fi
    if ! mkdir -m 700 -p "$RUNTIME_DIR"; then
        echo "Error: could not create runtime directory $RUNTIME_DIR." >&2
        return 1
    fi
    if ! chmod 700 "$RUNTIME_DIR"; then
        echo "Error: could not secure runtime directory $RUNTIME_DIR." >&2
        return 1
    fi
    umask 077

    for pid_file in "$XVFB_PID" "$DESKTOP_PID" "$VNC_PID"; do
        case "$pid_file" in
            "$XVFB_PID") expected="*Xvfb*${DISPLAY}*" ;;
            "$DESKTOP_PID") expected=desktop ;;
            "$VNC_PID") expected="*x11vnc*${DISPLAY}*" ;;
        esac
        if read_pid "$pid_file" && matches_process "$pid" "$expected"; then
            echo "A managed session is already running. Use '$0 stop' first." >&2
            return 1
        fi
        [ ! -f "$pid_file" ] || rm -f "$pid_file"
    done

    echo "Starting Xvfb on ${DISPLAY} (${RESOLUTION})..."
    "$XVFB_BIN" "$DISPLAY" -screen 0 "$RESOLUTION" >"$XVFB_LOG" 2>&1 &
    echo $! >"$XVFB_PID"
    sleep 2
    if ! read_pid "$XVFB_PID" || ! process_matches "$pid" "*Xvfb*${DISPLAY}*"; then
        echo "Error: Xvfb failed to start; see $XVFB_LOG." >&2
        stop
        return 1
    fi

    echo "Starting ${desktop_name} session..."
    DISPLAY=$DISPLAY
    export DISPLAY
    "$desktop_bin" >"$DESKTOP_LOG" 2>&1 &
    echo $! >"$DESKTOP_PID"
    sleep 1
    if ! read_pid "$DESKTOP_PID" || ! process_matches "$pid" "*${desktop_bin}*"; then
        echo "Error: ${desktop_name} failed to start; see $DESKTOP_LOG." >&2
        stop
        return 1
    fi

    echo "Starting x11vnc on localhost port ${VNC_PORT}..."
    "$VNC_BIN" -display "$DISPLAY" -rfbport "$VNC_PORT" -localhost \
        -forever -o "$VNC_LOG" -rfbauth "$VNC_PASSWD" > /dev/null 2>&1 &
    echo $! >"$VNC_PID"
    sleep 1
    if ! read_pid "$VNC_PID" || ! process_matches "$pid" "*x11vnc*${DISPLAY}*"; then
        echo "Error: x11vnc failed to start; see $VNC_LOG." >&2
        stop
        return 1
    fi

    echo "Virtual desktop is ready."
    echo "Create an SSH tunnel from your client:"
    echo "  ssh -N -L 127.0.0.1:${VNC_PORT}:127.0.0.1:${VNC_PORT} user@server"
    echo "Then connect your VNC viewer to 127.0.0.1:${VNC_PORT}."
}

verify() {
    if ! command -v nc >/dev/null 2>&1; then
        echo "Error: nc is not installed or not in PATH." >&2
        return 1
    fi
    if nc -vz 127.0.0.1 "$VNC_PORT"; then
        echo "VNC port ${VNC_PORT} is listening on localhost."
    else
        echo "VNC port ${VNC_PORT} is not listening on localhost." >&2
        return 1
    fi
}

storepasswd() {
    if ! command -v "$VNC_BIN" >/dev/null 2>&1; then
        echo "Error: $VNC_BIN is not installed or not in PATH." >&2
        return 1
    fi
    mkdir -m 700 -p "${HOME}/.vnc" || {
        echo "Error: could not create ${HOME}/.vnc." >&2
        return 1
    }
    "$VNC_BIN" -storepasswd
}

case "$1" in
    start) start "$2" ;;
    stop) stop ;;
    status) status ;;
    verify) verify ;;
    storepasswd) storepasswd ;;
    restart)
        stop || exit 1
        start "$2"
        ;;
    *)
        usage >&2
        exit 1
        ;;
esac
