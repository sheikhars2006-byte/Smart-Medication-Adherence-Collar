# Smart Medication Adherence Collar

An IoT-based medication adherence monitoring system that detects and logs medicine dose events in real time, with a companion mobile app for caregivers to track adherence remotely.

## Overview

The system attaches to a medicine bottle/container and uses motion and orientation sensing to detect when a dose has been taken. Each detected dose event is logged to a cloud backend and surfaced through a mobile app, allowing caregivers to monitor adherence, view history, and receive alerts.

## Hardware Components

- **ESP32-C3 SuperMini** — main microcontroller, handles sensing logic and Wi-Fi connectivity
- **MPU6500 IMU** — detects motion/orientation changes for dose event triggering
- **Hall Effect Sensor** — detects cap open/close state
- **OLED Display** — local status/feedback display
- **RGB LED** — visual status indicator
- **LiPo Battery + TP4056 Charging Module** — portable power supply with charging support

## How It Works

Dose detection follows a three-stage sequence:

1. **Cap Open** — detected via the Hall Effect sensor
2. **Motion** — detected via the IMU, indicating the container was picked up/used
3. **Cap Close** — detected via the Hall Effect sensor, confirming the dose event

When this sequence completes, a dose event is logged to Firebase in real time.

## Software & Backend

- **Firmware**: Written for the ESP32-C3, handling sensor polling, dose-sequence logic, and Firebase communication
- **Backend**: Firebase Realtime Database for dose event storage and real-time sync
- **Mobile App (Flutter)**:
  - Real-time listeners for live dose updates
  - Caregiver dashboard
  - Dose history view
  - Push notifications/alerts via Firebase Cloud Messaging (FCM)

## Enclosure

A two-piece snap-fit enclosure was designed in **OpenSCAD** and 3D-printed in **PETG**, housing the electronics and battery around the medicine container.

## Status

The system has been assembled and validated on a breadboard, with hardware components tested individually and integrated, dose-detection logic implemented end-to-end, and the Flutter app connected to live Firebase data.

## Tech Stack

`ESP32-C3` `C/C++ (Arduino Framework)` `Firebase Realtime Database` `Flutter` `OpenSCAD` `PETG (3D Printing)`
