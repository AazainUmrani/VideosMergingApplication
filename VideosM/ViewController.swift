//
//  ViewController.swift
//  VM2
//
//  Created by Apple on 20/12/2024.
//

import UIKit
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import AVKit

class ViewController: UIViewController, PHPickerViewControllerDelegate {
    
    @IBOutlet weak var videoContainer1: UIView!
    @IBOutlet weak var videoContainer2: UIView!
    @IBOutlet weak var videoContainer3: UIView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var PreogressTextField: UITextField!
    @IBOutlet weak var AddVideosTextField: UILabel!
    
    // IBOutlet for the play/pause button
    @IBOutlet weak var playPauseButton: UIButton!
    
    var videoURLs: [URL] = []
    var players: [AVPlayer] = []
    var playerLayers: [AVPlayerLayer] = []
    var isPlaying = false

    override func viewDidLoad() {
        super.viewDidLoad()
        progressView?.isHidden = true
        PreogressTextField.borderStyle = .none
        AddVideosTextField?.text = "Add 3 videos that you would like to merge"
        
        playPauseButton.isHidden = true
        playPauseButton.alpha = 0.5
    }

    func askPermission() {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                DispatchQueue.main.async {
                    self.showPhotoLibrary()
                }
            } else {
                DispatchQueue.main.async {
                    print("No access to Photo Library")
                }
            }
        }
    }

    @IBAction func selectVideosTapped(_ sender: UIButton) {
        AddVideosTextField?.isHidden = true
        askPermission()
    }

    func showPhotoLibrary() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 3

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        videoURLs.removeAll()

        for result in results {
            if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    if let url = url {
                        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                        try? FileManager.default.copyItem(at: url, to: destinationURL)
                        DispatchQueue.main.async {
                            self.videoURLs.append(destinationURL)
                            if self.videoURLs.count == 3 {
                                self.setupVideoPlayers()
                            }
                        }
                    } else {
                        print("Error loading video: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
        }
    }

    func setupVideoPlayers() {
        guard videoURLs.count == 3 else { return }

        players.forEach { $0.pause() }
        players.removeAll()
        playerLayers.forEach { $0.removeFromSuperlayer() }
        playerLayers.removeAll()

        let containers = [videoContainer1!, videoContainer2!, videoContainer3!]

        for (index, url) in videoURLs.enumerated() {
            let player = AVPlayer(url: url)
            players.append(player)

            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.frame = containers[index].bounds
            playerLayer.videoGravity = .resizeAspectFill
            containers[index].layer.addSublayer(playerLayer)
            playerLayers.append(playerLayer)

            player.actionAtItemEnd = .none
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(loopVideo(_:)),
                                                   name: .AVPlayerItemDidPlayToEndTime,
                                                   object: player.currentItem)
        }

        playPauseButton.isHidden = false
        playPauseButton.alpha = 0.5
        players.forEach { $0.play() }
    }

    @objc func loopVideo(_ notification: Notification) {
        if let playerItem = notification.object as? AVPlayerItem {
            playerItem.seek(to: .zero, completionHandler: nil)
        }
    }

    @IBAction func playPauseButtonTapped(_ sender: UIButton) {
        if isPlaying {
            players.forEach { $0.pause() }
            playPauseButton.setTitle("Play All", for: .normal)
        } else {
            players.forEach { $0.play() }
            playPauseButton.setTitle("Pause All", for: .normal)
        }
        isPlaying.toggle()
    }

    @IBAction func exportButtonTapped(_ sender: UIButton) {
        PreogressTextField?.text = "Export Progress"
        guard videoURLs.count == 3 else {
            print("Please select exactly 3 videos before exporting.")
            let alert = UIAlertController(title: "Error", message: "Please select exactly 3 videos before exporting.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        progressView?.isHidden = false
        progressView?.progress = 0.0

        combineVideos(videoURLs: videoURLs) { outputURL in
            DispatchQueue.main.async {
                self.progressView?.isHidden = true
            }
            guard let outputURL = outputURL else {
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Export Failed", message: "Could not export the video.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
                return
            }

            self.saveVideoToLibrary(outputURL: outputURL)
        }
    }

    func combineVideos(videoURLs: [URL], completion: @escaping (URL?) -> Void) {
        let composition = AVMutableComposition()
        let videoSize = CGSize(width: 1080, height: 1920)
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        var layerInstructions: [AVMutableVideoCompositionLayerInstruction] = []

        for (index, videoURL) in videoURLs.enumerated() {
            let asset = AVURLAsset(url: videoURL)
            guard let assetTrack = asset.tracks(withMediaType: .video).first else {
                print("Error: No video track found in asset at URL: \(videoURL)")
                completion(nil)
                return
            }

            let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)

            do {
                let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
                try compositionVideoTrack?.insertTimeRange(timeRange, of: assetTrack, at: .zero)
            } catch {
                print("Error inserting time range for video at URL: \(videoURL). Error: \(error)")
                completion(nil)
                return
            }

            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack!)
            let scaleTransform = CGAffineTransform(scaleX: 1080 / 1920, y: 720 / 1080)
            let positionTransform = CGAffineTransform(translationX: 0, y: CGFloat(index) * 610)

            let finalTransform = scaleTransform.concatenating(positionTransform)
            layerInstruction.setTransform(finalTransform, at: .zero)

            layerInstructions.append(layerInstruction)
        }

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        instruction.layerInstructions = layerInstructions
        videoComposition.instructions = [instruction]

        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("verticalCollage.mp4")
        if FileManager.default.fileExists(atPath: exportURL.path) {
            try? FileManager.default.removeItem(at: exportURL)
        }

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetMediumQuality) else {
            print("Error creating AVAssetExportSession")
            completion(nil)
            return
        }

        exportSession.outputURL = exportURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        // Start the export asynchronously
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    print("Export successful: \(exportURL)")
                    completion(exportURL)
                case .failed:
                    print("Export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")")
                    completion(nil)
                default:
                    print("Export status: \(exportSession.status.rawValue)")
                    completion(nil)
                }
            }
        }

        // Timer to track progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if exportSession.status == .exporting {
                DispatchQueue.main.async {
                    self.progressView.progress = exportSession.progress
                }
            } else {
                timer.invalidate()
            }
        }
    }
    func saveVideoToLibrary(outputURL: URL) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
        }) { success, error in
            if success {
                print("Video saved to library.")
                self.showAlert(title: "Success", message: "Video has been saved to your library.")
                print("Hello")
            } else {
                print("Error saving video: \(error?.localizedDescription ?? "Unknown error")")
                self.showAlert(title: "Error", message: "Failed to save video: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
}
