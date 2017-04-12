//
//  ViewController.swift
//  YouTubePlayerExample
//
//  Created by Giles Van Gruisen on 1/31/15.
//  Copyright (c) 2015 Giles Van Gruisen. All rights reserved.
//

import UIKit
import YouTubePlayer

class ViewController: UIViewController, YouTubePlayerDelegate {

  @IBOutlet var playerView: YouTubePlayerView!
  @IBOutlet var playButton: UIButton!

  override func viewDidLoad() {
    super.viewDidLoad()
    playerView.delegate = self
  }

  @IBAction func play(_ sender: UIButton) {
    if playerView.isReady {
      if playerView.playerState != YouTubePlayerState.playing {
        playerView.play()
        playButton.setTitle("Pause", for: UIControlState())
      }
      else {
        playerView.pause()
        playButton.setTitle("Play", for: UIControlState())
      }
    }
  }

  @IBAction func prev(_ sender: UIButton) {
    playerView.previousVideo()
  }

  @IBAction func next(_ sender: UIButton) {
    playerView.nextVideo()
  }

  @IBAction func loadVideo(_ sender: UIButton) {
    playerView.playerVars = ["controls": 2, "showinfo": 0, "modestbranding": 1, "rel": 0]
    try! playerView.load(videoID: "L0MK7qz13bU")
  }

  @IBAction func loadPlaylist(_ sender: UIButton) {
    try! playerView.load(playlistID: "PL4BrNFx1j7E6a6IKg8N0IgnkoamHlCHWa")
  }

  func showAlert(_ message: String) {
    self.present(alertWithMessage(message), animated: true, completion: nil)
  }

  func alertWithMessage(_ message: String) -> UIAlertController {
    let alertController =  UIAlertController(title: "", message: message, preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))

    return alertController
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  // MARK: YouTubePlayerDelegate

  func youTubePlayerReady(_ videoPlayer: YouTubePlayerView) {
    print("Player ready")
  }

  func youTubePlayerStateChanged(_ videoPlayer: YouTubePlayerView, playerState: YouTubePlayerState) {
    print("Player state changed: \(playerState.rawValue)")
  }

  func youTubePlayerQualityChanged(_ videoPlayer: YouTubePlayerView, playbackQuality: YouTubePlaybackQuality) {
    print("Player quality changed: \(playbackQuality.rawValue)")
  }

  func youTubePlayerPlayTimeUpdated(_ videoPlayer: YouTubePlayerView, playTime: TimeInterval) {
    print("Player time changed: \(playTime)")
  }

  func youTubePlayerWantsToOpenURL(_ videoPlayer: YouTubePlayerView, url: URL) {
    UIApplication.shared.openURL(url)
  }

}

