# StreamSync 📺📱

StreamSync is a high-performance local media streaming solution built with Flutter. It allows you to transform your mobile device into a media server and stream videos directly to your Android TV or other devices on the same Wi-Fi network.

## 🚀 Key Features

- **Local Media Server**: Host your phone's video library over HTTP using a robust background service.
- **Android TV Optimized**: Fully compatible with Android TV, featuring a remote-friendly UI and D-pad navigation.
- **Smart Discovery**: Automatically find other StreamSync devices on your network using UDP beacons and mDNS.
- **High-Performance Playback**: Powered by `media_kit` (libmpv) with optimized software decoding for stable playback on low-end TV hardware.
- **Secure Handshake**: Peer-to-peer connection approval system to ensure only authorized devices can access your media.
- **Responsive Architecture**: One codebase that scales seamlessly from small mobile screens to large 4K TV interfaces.

## 🏗️ Architecture: Feature-First Clean Architecture

The project follows a highly scalable **Feature-First Clean Architecture**, ensuring strict separation of concerns and clear domain boundaries.

```text
lib/
├── app/                        # Responsive orchestration & Routing
├── core/                       # Global constants, theme, & utilities
└── features/                   # Domain-driven modules
    ├── server/                 # Media Hosting (data sources, services, UI)
    ├── discovery/              # Network Scanning logic
    ├── client/                 # Remote Library browsing
    └── player/                 # Video Playback engine
```

## 🛠️ Tech Stack

- **Framework**: Flutter
- **State Management**: Riverpod
- **Local Storage**: Hive (with custom adapters)
- **Networking**: Shelf (HTTP Server), Multicast DNS, UDP Sockets
- **Video Player**: Media Kit (libmpv)
- **Background Tasking**: Flutter Background Service

## 📥 Getting Started

### Prerequisites
- Flutter SDK (Latest Stable)
- FVM (Optional but recommended)
- Android Studio / VS Code

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/legion/streamsync.git
   cd streamsync
   ```

2. **Install dependencies**:
   ```bash
   fvm flutter pub get
   ```

3. **Generate Hive Adapters**:
   ```bash
   fvm flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Run the app**:
   ```bash
   fvm flutter run
   ```

## 📺 TV Support
StreamSync is specifically tuned for Android TV. We use **Skia** rendering (Impeller disabled) to ensure compatibility with older TV chipsets and force **Software Decoding** (`hwdec=no`) to prevent rendering artifacts like green squares often seen on low-end hardware.

## 🛡️ License
MIT License - feel free to use and contribute!
