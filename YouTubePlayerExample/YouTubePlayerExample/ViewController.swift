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

  @IBAction func play(sender: UIButton) {
    if playerView.ready {
      if playerView.playerState != YouTubePlayerState.Playing {
        playerView.play()
        playButton.setTitle("Pause", forState: .Normal)
      }
      else {
        playerView.pause()
        playButton.setTitle("Play", forState: .Normal)
      }
    }
  }

  @IBAction func prev(sender: UIButton) {
    playerView.previousVideo()
  }

  @IBAction func next(sender: UIButton) {
    playerView.nextVideo()
  }

  @IBAction func loadVideo(sender: UIButton) {
    playerView.playerVars = ["playsinline": "1"]
    playerView.videoID = "wQg3bXrVLtg"
  }

  @IBAction func loadPlaylist(sender: UIButton) {
    playerView.playlistID = "RDe-ORhEE9VVg"
  }

  func showAlert(message: String) {
    self.presentViewController(alertWithMessage(message), animated: true, completion: nil)
  }

  func alertWithMessage(message: String) -> UIAlertController {
    let alertController =  UIAlertController(title: "", message: message, preferredStyle: .Alert)
    alertController.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))

    return alertController
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  // MARK: YouTubePlayerDelegate

  func youTubePlayerReady(videoPlayer: YouTubePlayerView) {
    println("Player ready")
  }

  func youTubePlayerStateChanged(videoPlayer: YouTubePlayerView, playerState: YouTubePlayerState) {
    println("Player state changed: \(playerState.rawValue)")
  }

  func youTubePlayerQualityChanged(videoPlayer: YouTubePlayerView, playbackQuality: YouTubePlaybackQuality) {
    println("Player quality changed: \(playbackQuality.rawValue)")
  }

  func youTubePlayerPlayTimeUpdated(videoPlayer: YouTubePlayerView, playTime: NSTimeInterval) {
    println("Player time changed: \(playTime)")
  }

}

