# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application. The main entry point is `lib/main.dart`. The project follows a standard Flutter project structure.

## Common Commands

*   **Run the app:** `flutter run`
*   **Run tests:** `flutter test`
*   **Lint:** `flutter analyze`
*   **Build:** 
    *   Android: `flutter build apk` or `flutter build appbundle`
    *   iOS: `flutter build ios`
*   **Get dependencies:** `flutter pub get`
*   **Generate code for Isar:** `flutter pub run build_runner build`


## High-level Architecture

The application's code is organized in the `lib` directory with the following structure:

*   `lib/main.dart`: The main entry point of the application.
*   `lib/controllers`: Contains the business logic of the application.
*   `lib/models`: Defines the data models used in the application.
*   `lib/pages`: Contains the different pages or screens of the application.
*   `lib/providers`: Contains Riverpod providers for state management.
*   `lib/renderer`: Contains the code for rendering ebook content. This seems to be based on the `foliate-js` project.
*   `lib/server`: Contains a local server implementation using `shelf`.
*   `lib/services`: Contains services that interact with external resources or APIs.
*   `lib/utils`: Contains utility functions and classes.
*   `lib/widgets`: Contains reusable widgets used throughout the application.

## Dependencies

The project uses the following key dependencies:

*   `flutter_riverpod` and `riverpod_annotation` for state management.
*   `isar` and `isar_flutter_libs` for a local database.
*   `webview_flutter` and `flutter_inappwebview` for displaying web content.
*   `http` for making HTTP requests.
*   `just_audio` for audio playback.
*   `shelf` and `shelf_static` for a local server.
