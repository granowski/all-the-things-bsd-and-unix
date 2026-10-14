#!/bin/sh

# Start Xvfb
Xvfb :1 -screen 0 1280x800x24 > /tmp/Xvfb-granowski.log 2>&1 &

# Start mate-session
mate-session --display=:1 > /tmp/mate-sess-granowski.log 2>&1 &

# Start x11vnc
x11vnc -display :1 -rfbport 5901

# Start SSH tunnel
ssh -v -N -L 127.0.0.1:5901:127.0.0.1:5901 granowski@10.0.0.167

# Start x11vnc password storage
x11vnc -storepasswd

# Start nc to connect to x11vnc
nc -v 10.0.0.167 5901

# Start nc to connect to x11vnc
nc -vz 127.0.0.1 5901

# List all sockets
sockstat -4 -l

