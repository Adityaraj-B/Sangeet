# Sangeet — Enterprise-Grade Music Streaming Platform  

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)
![Dart](https://img.shields.io/badge/Dart-2.x-blue)
![Firebase](https://img.shields.io/badge/Firebase-Backend-orange)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-Active-success)

A production-ready music streaming application built with Flutter, focused on real-world mobile engineering across audio systems, cloud synchronization, security, APIs, and user experience.  

Built as a complete product — not a demo — covering everything from background media services to secure authentication and scalable architecture.

---

## Table of Contents  

- [Overview](#overview)  
- [Key Highlights](#key-highlights)  
- [Features](#features)  
- [Architecture](#architecture)  
- [Tech Stack](#tech-stack)  
- [Getting Started](#getting-started)  
- [Project Structure](#project-structure)  
- [Screenshots](#screenshots)  
- [Roadmap](#roadmap)  
- [Contributing](#contributing)  
- [License](#license)  
- [Contact](#contact)  

---

## Overview  

Sangeet is a cross-platform music streaming application designed to deliver a seamless and high-performance listening experience.  
It integrates advanced audio handling, cloud-backed data systems, and modern UI/UX principles into a cohesive system.  

---

## Key Highlights  

- Native background audio playback with system-level controls  
- Secure authentication with biometric access  
- Real-time cloud synchronization with offline-first capability  
- High-performance architecture with scalable state management  
- Modern UI with smooth animations and responsive design  

---

## Features  

### Audio System  
- Background playback with lock-screen and notification controls  
- Queue management with shuffle support  
- Call handling, Bluetooth switching, and device route changes  
- Automatic pause on headphone disconnect  
- Battery-efficient playback  

### Authentication and Security  
- Firebase Authentication (Email and Google Sign-In)  
- Biometric login (Fingerprint and Face ID)  
- Secure credential storage using flutter_secure_storage  
- Rate limiting and layered security approach  

### Cloud and Data  
- Firestore with offline persistence  
- Firebase Storage for media assets  
- Real-time user insights and analytics  
- Playlist synchronization across devices  

### API and Backend Logic  
- REST API integrations for music metadata and search  
- Repository pattern for abstraction  
- Pagination for large datasets  
- Retry and backoff strategies  
- Graceful error handling with UI fallbacks  

### UI and Experience  
- Material Design 3 implementation  
- Smooth animations and haptic feedback  
- Instant search with live results  
- Playlist creation and management  
- Responsive and accessible UI  

---

## Architecture  

- Provider-based state management  
- Modular service layer (audio, authentication, API, analytics)  
- Offline-first architecture with caching  
- just_audio and audio_service for playback  
- Secure networking with validation and timeout handling  

---

## Tech Stack  

Frontend: Flutter  
Language: Dart  
Backend Services: Firebase (Auth, Firestore, Storage)  
State Management: Provider  
Audio Engine: just_audio, audio_service  
Design: Material Design 3  

---

## Getting Started  

### Prerequisites  
- Flutter SDK  
- Firebase project setup  
- Android Studio or VS Code  

### Installation  

```bash
git clone https://github.com/Adityaraj-B/sangeet.git
cd sangeet
flutter pub get
