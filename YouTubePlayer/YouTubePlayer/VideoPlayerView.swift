//
//  VideoPlayerView.swift
//  YouTubePlayer
//
//  Created by Giles Van Gruisen on 12/21/14.
//  Copyright (c) 2014 Giles Van Gruisen. All rights reserved.
//  Copyright (c) 2015 Alexander Kolov. All rights reserved.
//

import WebKit
import UIKit

public enum YouTubePlayerState: String {
  case Unstarted = "-1"
  case Ended = "0"
  case Playing = "1"
  case Paused = "2"
  case Buffering = "3"
  case Queued = "4"
}

public enum YouTubePlayerEvents: String {
  case YouTubeIframeAPIReady = "onYouTubeIframeAPIReady"
  case Ready = "onReady"
  case StateChange = "onStateChange"
  case PlaybackQualityChange = "onPlaybackQualityChange"
}

public enum YouTubePlaybackQuality: String {
  case Default = "default"
  case Small = "small"
  case Medium = "medium"
  case Large = "large"
  case HD720 = "hd720"
  case HD1080 = "hd1080"
  case HighResolution = "highres"
}

public protocol YouTubePlayerDelegate {
  func playerReady(videoPlayer: YouTubePlayerView)
  func playerStateChanged(videoPlayer: YouTubePlayerView, playerState: YouTubePlayerState)
  func playerQualityChanged(videoPlayer: YouTubePlayerView, playbackQuality: YouTubePlaybackQuality)
}

/** Embed and control YouTube videos */
public class YouTubePlayerView: UIView, WKNavigationDelegate {

  public typealias YouTubePlayerParameters = [String: AnyObject]

  private var webView: WKWebView!

  private(set) public var ready = false
  private(set) public var playerState = YouTubePlayerState.Unstarted
  private(set) public var playbackQuality = YouTubePlaybackQuality.Default

  public var delegate: YouTubePlayerDelegate?

  public override init(frame: CGRect) {
    super.init(frame: frame)
    configure()
  }

  public required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    configure()
  }

  // MARK: Private functions

  private func configure() {
    let configuration = WKWebViewConfiguration()
    configuration.allowsInlineMediaPlayback = true
    configuration.mediaPlaybackAllowsAirPlay = true
    configuration.mediaPlaybackRequiresUserAction = false

    webView = WKWebView(frame: CGRectZero, configuration: configuration)
    webView.setTranslatesAutoresizingMaskIntoConstraints(false)
    webView.navigationDelegate = self

    addSubview(webView)
    addConstraints([
      NSLayoutConstraint(item: webView, attribute: .Top, relatedBy: .Equal, toItem: self, attribute: .Top, multiplier: 1, constant: 0),
      NSLayoutConstraint(item: webView, attribute: .Left, relatedBy: .Equal, toItem: self, attribute: .Left, multiplier: 1, constant: 0),
      NSLayoutConstraint(item: webView, attribute: .Bottom, relatedBy: .Equal, toItem: self, attribute: .Bottom, multiplier: 1, constant: 0),
      NSLayoutConstraint(item: webView, attribute: .Right, relatedBy: .Equal, toItem: self, attribute: .Right, multiplier: 1, constant: 0)
    ])
  }

  // MARK: Player setup

  private func loadPlayer(parameters: YouTubePlayerParameters) {
    if let path = NSBundle(forClass: YouTubePlayerView.self).pathForResource("Player", ofType: "html") {
      var error: NSError?
      let html = String(contentsOfFile: path, encoding: NSUTF8StringEncoding, error: &error)

      if let json = serializedJSON(parameters), html = html?.stringByReplacingOccurrencesOfString("@PARAMETERS@", withString: json, options: nil, range: nil) {
        webView.loadHTMLString(html, baseURL: NSURL(string: "about:blank"))
      }
      else if let error = error {
        println("Could not open html file: \(error)")
      }
    }
  }

  // MARK: Player parameters and defaults

  private func playerParameters(playerVars: YouTubePlayerParameters? = nil) -> YouTubePlayerParameters {
    return [
      "height": "100%",
      "width": "100%",
      "playerVars": playerVars ?? YouTubePlayerParameters(),
      "events": [
        "onReady": "onReady",
        "onStateChange": "onStateChange",
        "onPlaybackQualityChange": "onPlaybackQualityChange",
        "onError": "onPlayerError"
      ]
    ]
  }

  private func serializedJSON(object: AnyObject) -> String? {
    var error: NSError?
    let data = NSJSONSerialization.dataWithJSONObject(object, options: NSJSONWritingOptions.allZeros, error: &error)

    if let data = data {
      return NSString(data: data, encoding: NSUTF8StringEncoding) as? String
    }
    else if let error = error {
      println("JSON serialization error: \(error.localizedDescription)")
    }

    return nil
  }

  // MARK: Video loading

  public var videoID: String? {
    didSet {
      if let videoID = videoID {
        var params = playerParameters()
        params["videoId"] = videoID
        loadPlayer(params)
      }
    }
  }

  public var playlistID: String? {
    didSet {
      if let videoID = videoID {
        var playerVars = YouTubePlayerParameters()
        playerVars["listType"] = "playlist"
        playerVars["list"] = playlistID

        var params = playerParameters(playerVars: playerVars)
        loadPlayer(params)
      }
    }
  }

  public var videoURL: NSURL? {
    didSet {
      if let url = videoURL, components = NSURLComponents(URL: url, resolvingAgainstBaseURL: true) {
        videoID = components.queryItems?.filter { $0.name == "v" }.first?.value
      }
    }
  }

  // MARK: Player controls

  public func play() {
    evaluatePlayerCommand("playVideo()")
  }

  public func pause() {
    evaluatePlayerCommand("pauseVideo()")
  }

  public func stop() {
    evaluatePlayerCommand("stopVideo()")
  }

  public func clear() {
    evaluatePlayerCommand("clearVideo()")
  }

  public func seekTo(seconds: Float, seekAhead: Bool) {
    evaluatePlayerCommand("seekTo(\(seconds), \(seekAhead))")
  }

  // MARK: Playlist controls

  public func previousVideo() {
    evaluatePlayerCommand("previousVideo()")
  }

  public func nextVideo() {
    evaluatePlayerCommand("nextVideo()")
  }

  // MARK: Event Handling

  private func evaluatePlayerCommand(command: String) {
    let fullCommand = "player." + command + ";"
    webView.evaluateJavaScript(fullCommand) { object, error in
      if let error = error {
        println("Failed to evaluate JavaScript: \(error.localizedDescription)")
      }
    }
  }

  private func handleEvent(eventURL: NSURL) {
    // Grab the last component of the queryString as string
    let components = NSURLComponents(URL: eventURL, resolvingAgainstBaseURL: true)
    let state: String? = components?.queryItems?.filter { $0.name == "data" }.first?.value

    if let host = eventURL.host, state = state, event = YouTubePlayerEvents(rawValue: host) {
      switch event {
      case .YouTubeIframeAPIReady:
        ready = true

      case .Ready:
        delegate?.playerReady(self)

      case .StateChange:
        if let newState = YouTubePlayerState(rawValue: state) {
          playerState = newState
          delegate?.playerStateChanged(self, playerState: newState)
        }

      case .PlaybackQualityChange:
        if let newQuality = YouTubePlaybackQuality(rawValue: state) {
          playbackQuality = newQuality
          delegate?.playerQualityChanged(self, playbackQuality: newQuality)
        }
      }
    }
  }

  // MARK: WKNavigationDelegate

  public func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
    if let url = navigationAction.request.URL {
      if url.scheme == "ytplayer" {
        handleEvent(url)
        decisionHandler(.Cancel)
        return
      }
    }

    decisionHandler(.Allow)
  }

}
