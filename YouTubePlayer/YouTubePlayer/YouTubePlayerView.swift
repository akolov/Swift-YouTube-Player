//
//  YouTubePlayerView.swift
//  YouTubePlayer
//
//  Created by Giles Van Gruisen on 12/21/14.
//  Copyright (c) 2014 Giles Van Gruisen. All rights reserved.
//  Copyright (c) 2015 Alexander Kolov. All rights reserved.
//

import UIKit
import WebKit

public enum YouTubePlayerState: Int {
  case Unstarted = -1
  case Ended = 0
  case Playing = 1
  case Paused = 2
  case Buffering = 3
  case Cued = 5
}

public enum YouTubePlayerEvents: String {
  case YouTubeIframeAPIReady = "apiReady"
  case Ready = "ready"
  case StateChange = "stateChange"
  case PlaybackQualityChange = "playbackQualityChange"
  case PlayTime = "playTime"
}

public enum YouTubePlaybackQuality: String {
  case Auto = "auto"
  case Default = "default"
  case Small = "small"
  case Medium = "medium"
  case Large = "large"
  case HD720 = "hd720"
  case HD1080 = "hd1080"
  case HighResolution = "highres"
}

public enum YouTubePlayerError: String {
  case InvalidParam = "2"
  case HTML5 = "5"
  case VideoNotFound = "100"
  case NotEmbeddable = "101"
  case CannotFindVideo = "105"
  case SameAsNotEmbeddable = "150"
}

public protocol YouTubePlayerDelegate: class {
  func youTubePlayerReady(videoPlayer: YouTubePlayerView)
  func youTubePlayerStateChanged(videoPlayer: YouTubePlayerView, playerState: YouTubePlayerState)
  func youTubePlayerQualityChanged(videoPlayer: YouTubePlayerView, playbackQuality: YouTubePlaybackQuality)
  func youTubePlayerPlayTimeUpdated(videoPlayer: YouTubePlayerView, playTime: NSTimeInterval)
}

public class YouTubePlayerView: UIView, WKScriptMessageHandler {

  public typealias YouTubePlayerParameters = [String: AnyObject]

  internal(set) public var ready = false

  internal(set) public var playerState = YouTubePlayerState.Unstarted {
    didSet {
      delegate?.youTubePlayerStateChanged(self, playerState: playerState)
    }
  }

  internal(set) public var playbackQuality = YouTubePlaybackQuality.Default {
    didSet {
      delegate?.youTubePlayerQualityChanged(self, playbackQuality: playbackQuality)
    }
  }

  internal(set) public var playTime: NSTimeInterval? {
    didSet {
      if let playTime = playTime {
        delegate?.youTubePlayerPlayTimeUpdated(self, playTime: playTime)
      }
    }
  }

  var originURL: NSURL?

  public var playerVars = YouTubePlayerParameters()

  public weak var delegate: YouTubePlayerDelegate?

  public override init(frame: CGRect) {
    super.init(frame: frame)
    configure()
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    configure()
  }

  // MARK: Web view

  private var webView: WKWebView!
  private var html: String?

  func configure() {
    let configuration = WKWebViewConfiguration()
    configuration.allowsInlineMediaPlayback = true
    configuration.mediaPlaybackAllowsAirPlay = true
    configuration.mediaPlaybackRequiresUserAction = true
    configuration.userContentController.addScriptMessageHandler(self, name: "EventHandler")

    webView = WKWebView(frame: bounds, configuration: configuration)
    webView.scrollView.bounces = false
    webView.scrollView.scrollEnabled = false
    webView.scrollView.panGestureRecognizer.enabled = false
    webView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]

    addSubview(webView)
  }

  func loadPlayer(parameters: YouTubePlayerParameters) throws {
    let path = NSBundle(forClass: self.dynamicType).pathForResource("Player", ofType: "html")
    let json = try serializedJSON(parameters)
    html = try String(contentsOfFile: path!, encoding: NSUTF8StringEncoding).stringByReplacingOccurrencesOfString("@PARAMETERS@", withString: json, options: [], range: nil)
    reloadVideo()
  }

  public func loadVideo(videoID: String) throws {
    playerVars["listType"] = nil
    playerVars["list"] = nil
    var params = playerParameters
    params["videoId"] = videoID
    try loadPlayer(params)
  }

  public func loadPlaylist(playlistID: String) throws {
    playerVars["listType"] = "playlist"
    playerVars["list"] = playlistID
    try loadPlayer(playerParameters)
  }

  public func loadURL(URL: NSURL) throws {
    if let components = NSURLComponents(URL: URL, resolvingAgainstBaseURL: true), videoID = components.queryItems?.filter({ $0.name == "v" }).first?.value {
      try loadVideo(videoID)
    }
  }

  public func reloadVideo() {
    if let html = html {
      webView.loadHTMLString(html, baseURL: originURL)
    }
  }

  func evaluatePlayerCommand(command: String, callback: ((AnyObject?, NSError?) -> Void)? = nil) {
    let fullCommand = "player." + command + ";"
    webView.evaluateJavaScript(fullCommand) { object, error in
      callback?(object, error)
      if let error = error {
        print("Failed to evaluate JavaScript: \(error.localizedDescription)")
      }
    }
  }

  // MARK: WKScriptMessageHandler

  public func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
    if let dict = message.body as? [String: AnyObject] {
      if let eventName = dict["event"] as? String, event = YouTubePlayerEvents(rawValue: eventName) {
        handlePlayerEvent(event, data: dict["data"])
      }
    }
  }

  // MARK: Player parameters and defaults

  var playerParameters: YouTubePlayerParameters {
    return [
      "height": "100%",
      "width": "100%",
      "playerVars": playerVars,
      "events": [
        "onReady": "onReady",
        "onStateChange": "onStateChange",
        "onPlaybackQualityChange": "onPlaybackQualityChange",
        "onError": "onPlayerError"
      ]
    ]
  }

  func serializedJSON(object: AnyObject) throws -> String {
    let data = try NSJSONSerialization.dataWithJSONObject(object, options: NSJSONWritingOptions())
    return NSString(data: data, encoding: NSUTF8StringEncoding) as! String
  }

  // MARK: Player controls

  public func play() {
    evaluatePlayerCommand("playVideo()")
  }

  public func pause() {
    delegate?.youTubePlayerStateChanged(self, playerState: .Paused)
    evaluatePlayerCommand("pauseVideo()")
  }

  public func stop() {
    evaluatePlayerCommand("stopVideo()")
  }

  public func clear() {
    evaluatePlayerCommand("clearVideo()")
  }

  public func seekTo(seconds: NSTimeInterval, seekAhead: Bool) {
    evaluatePlayerCommand("seekTo(\(seconds), \(seekAhead))")
  }

  // MARK: Playlist controls

  public func previousVideo() {
    evaluatePlayerCommand("previousVideo()")
  }

  public func nextVideo() {
    evaluatePlayerCommand("nextVideo()")
  }

  // MARK: Playback rate

  public func playbackRate(callback: (Float?, NSError?) -> Void) {
    evaluatePlayerCommand("getPlaybackRate()") { object, error in
      callback(object?.floatValue, error)
    }
  }

  public func setPlaybackRate(suggestedRate: Float, callback: (NSError?) -> Void) {
    evaluatePlayerCommand("setPlaybackRate(\(suggestedRate))") { object, error in
      callback(error)
    }
  }

  public func availablePlaybackRates(callback: ([Float], NSError?) -> Void) {
    evaluatePlayerCommand("getAvailablePlaybackRates()") { object, error in
      var rates: [NSNumber]?
      var jsonError: NSError?
      if let data = object?.dataUsingEncoding(NSUTF8StringEncoding) {
        do {
          rates = try NSJSONSerialization.JSONObjectWithData(data, options: []) as? [NSNumber]
        }
        catch let e as NSError {
          jsonError = e
        }
      }

      callback(rates?.map { $0.floatValue } ?? [], error ?? jsonError)
    }
  }

  // MARK: Playback status

  public func videoLoadedFraction(callback: (Float?, NSError?) -> Void) {
    evaluatePlayerCommand("getVideoLoadedFraction()") { object, error in
      callback(object?.floatValue, error)
    }
  }

  public func currentTime(callback: (NSTimeInterval?, NSError?) -> Void) {
    evaluatePlayerCommand("getCurrentTime()") { object, error in
      callback(object?.doubleValue, error)
    }
  }

  public func duration(callback: (NSTimeInterval?, NSError?) -> Void) {
    evaluatePlayerCommand("getDuration()") { object, error in
      callback(object?.doubleValue, error)
    }
  }

  // MARK: Event handling

  func handlePlayerEvent(event: YouTubePlayerEvents, data: AnyObject?) {
    switch event {
    case .YouTubeIframeAPIReady:
      ready = true

    case .Ready:
      delegate?.youTubePlayerReady(self)

    case .StateChange:
      if let stateName = data as? Int, state = YouTubePlayerState(rawValue: stateName) {
        playerState = state
      }

    case .PlaybackQualityChange:
      if let qualityName = data as? String, quality = YouTubePlaybackQuality(rawValue: qualityName) {
        playbackQuality = quality
      }

    case .PlayTime:
      if let time = data as? NSTimeInterval {
        playTime = time
      }
    }
  }

}
