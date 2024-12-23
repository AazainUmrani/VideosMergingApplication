# VideoMerge

**VideoMerge** is a simple iOS app that allows users to select videos from their photo library, play them within the app, merge them into a collage, and export the final result back to the photo library. The app leverages the `PHPickerViewController` for video selection and `AVPlayer` for video playback.

## Features

- **Photo Library Access**: Requests photo library access and handles permissions seamlessly.
- **Video Selection**: Filters and selects videos from the photo library with ease.
- **Video Playback**: Plays selected videos within the app using `AVPlayerLayer`.
- **Multiple Video Support**: Allows playing and merging up to 3 videos (as set by the selection limit).
- **Collage Merge & Export**: Combines selected videos into a collage and enables exporting the final result to the photo library.

## How to Use

1. Launch the app and press the **"Add Photos"** button to access the photo library.
2. Grant access to the photo library when prompted.
3. Select up to **3 videos** from the photo library.
4. The selected videos will be displayed and played in the app's video view.
5. Use the merge and export functionality to save a collage of the selected videos back to your photo library.

## Requirements

- iOS 15.0 or later
- Swift programming language
- Xcode for development

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/your-username/VideoMerge.git
