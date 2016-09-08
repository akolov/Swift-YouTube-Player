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
  case unstarted = -1
  case ended = 0
  case playing = 1
  case paused = 2
  case buffering = 3
  case cued = 5
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
  func youTubePlayerReady(_ videoPlayer: YouTubePlayerView)
  func youTubePlayerStateChanged(_ videoPlayer: YouTubePlayerView, playerState: YouTubePlayerState)
  func youTubePlayerQualityChanged(_ videoPlayer: YouTubePlayerView, playbackQuality: YouTubePlaybackQuality)
  func youTubePlayerPlayTimeUpdated(_ videoPlayer: YouTubePlayerView, playTime: TimeInterval)
  func youTubePlayerWantsToOpenURL(_ videoPlayer: YouTubePlayerView, URL: URL)
}

open class YouTubePlayerView: UIView {

  public typealias YouTubePlayerParameters = [String: Any]

  internal(set) open var ready = false

  internal(set) open var playerState = YouTubePlayerState.unstarted {
    didSet {
      delegate?.youTubePlayerStateChanged(self, playerState: playerState)
    }
  }

  internal(set) open var playbackQuality = YouTubePlaybackQuality.Default {
    didSet {
      delegate?.youTubePlayerQualityChanged(self, playbackQuality: playbackQuality)
    }
  }

  internal(set) open var playTime: TimeInterval? {
    didSet {
      if let playTime = playTime {
        delegate?.youTubePlayerPlayTimeUpdated(self, playTime: playTime)
      }
    }
  }

  var originURL: URL?

  open var playerVars = YouTubePlayerParameters()

  open weak var delegate: YouTubePlayerDelegate?

  public override init(frame: CGRect) {
    super.init(frame: frame)
    configure()
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    configure()
  }

  // MARK: Web view

  fileprivate var webView: WKWebView!
  fileprivate var html: String?

  func configure() {
    let configuration = WKWebViewConfiguration()
    configuration.allowsInlineMediaPlayback = true
    configuration.mediaPlaybackAllowsAirPlay = true
    configuration.mediaPlaybackRequiresUserAction = true
    configuration.userContentController.add(self, name: "EventHandler")

    webView = WKWebView(frame: bounds, configuration: configuration)
    webView.scrollView.bounces = false
    webView.scrollView.isScrollEnabled = false
    webView.scrollView.panGestureRecognizer.isEnabled = false
    webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    webView.navigationDelegate = self
    webView.uiDelegate = self

    addSubview(webView)
  }

  func loadPlayer(_ parameters: YouTubePlayerParameters) throws {
    let path = Bundle(for: type(of: self)).path(forResource: "Player", ofType: "html")
    let json = try serializedJSON(parameters as AnyObject)
    html = try String(contentsOfFile: path!, encoding: String.Encoding.utf8).replacingOccurrences(of: "@PARAMETERS@", with: json, options: [], range: nil)
    reloadVideo()
  }

  open func loadVideo(_ videoID: String) throws {
    playerVars["listType"] = nil
    playerVars["list"] = nil
    var params = playerParameters
    params["videoId"] = videoID as AnyObject?
    try loadPlayer(params)
  }

  open func loadPlaylist(_ playlistID: String) throws {
    playerVars["listType"] = "playlist" as AnyObject?
    playerVars["list"] = playlistID as AnyObject?
    try loadPlayer(playerParameters)
  }

  open func loadURL(_ URL: Foundation.URL) throws {
    if let components = URLComponents(url: URL, resolvingAgainstBaseURL: true), let videoID = components.queryItems?.filter({ $0.name == "v" }).first?.value {
      try loadVideo(videoID)
    }
  }

  open func reloadVideo() {
    if let html = html {
      webView.loadHTMLString(html, baseURL: originURL)
    }
  }

  func evaluatePlayerCommand(_ command: String, callback: ((Any?, Error?) -> Void)? = nil) {
    let fullCommand = "player." + command + ";"
    webView.evaluateJavaScript(fullCommand) { object, error in
      callback?(object, error)
      if let error = error {
        print("Failed to evaluate JavaScript: \(error.localizedDescription)")
      }
    }
  }

  // MARK: Player parameters and defaults

  var playerParameters: YouTubePlayerParameters {
    return [
      "height": "100%" as AnyObject,
      "width": "100%" as AnyObject,
      "playerVars": playerVars,
      "events": [
        "onReady": "onReady",
        "onStateChange": "onStateChange",
        "onPlaybackQualityChange": "onPlaybackQualityChange",
        "onError": "onPlayerError"
      ]
    ]
  }

  func serializedJSON(_ object: AnyObject) throws -> String {
    let data = try JSONSerialization.data(withJSONObject: object, options: JSONSerialization.WritingOptions())
    return NSString(data: data, encoding: String.Encoding.utf8.rawValue) as! String
  }

  // MARK: Player controls

  open func play() {
    evaluatePlayerCommand("playVideo()")
  }

  open func pause() {
    delegate?.youTubePlayerStateChanged(self, playerState: .paused)
    evaluatePlayerCommand("pauseVideo()")
  }

  open func stop() {
    evaluatePlayerCommand("stopVideo()")
  }

  open func clear() {
    evaluatePlayerCommand("clearVideo()")
  }

  open func seekTo(_ seconds: TimeInterval, seekAhead: Bool) {
    evaluatePlayerCommand("seekTo(\(seconds), \(seekAhead))")
  }

  // MARK: Playlist controls

  open func previousVideo() {
    evaluatePlayerCommand("previousVideo()")
  }

  open func nextVideo() {
    evaluatePlayerCommand("nextVideo()")
  }

  // MARK: Playback rate

  open func playbackRate(_ callback: @escaping (Float?, Error?) -> Void) {
    evaluatePlayerCommand("getPlaybackRate()") { object, error in
      callback((object as? NSNumber)?.floatValue, error)
    }
  }

  open func setPlaybackRate(_ suggestedRate: Float, callback: @escaping (Error?) -> Void) {
    evaluatePlayerCommand("setPlaybackRate(\(suggestedRate))") { object, error in
      callback(error)
    }
  }

  open func availablePlaybackRates(_ callback: @escaping ([Float], Error?) -> Void) {
    evaluatePlayerCommand("getAvailablePlaybackRates()") { object, error in
      var rates: [NSNumber]?
      var jsonError: Error?
      if let data = (object as? String)?.data(using: String.Encoding.utf8) {
        do {
          rates = try JSONSerialization.jsonObject(with: data, options: []) as? [NSNumber]
        }
        catch let e as NSError {
          jsonError = e
        }
      }

      callback(rates?.map { $0.floatValue } ?? [], error ?? jsonError)
    }
  }

  // MARK: Playback status

  open func videoLoadedFraction(_ callback: @escaping (Float?, Error?) -> Void) {
    evaluatePlayerCommand("getVideoLoadedFraction()") { object, error in
      callback((object as? NSNumber)?.floatValue, error)
    }
  }

  open func currentTime(_ callback: @escaping (TimeInterval?, Error?) -> Void) {
    evaluatePlayerCommand("getCurrentTime()") { object, error in
      callback((object as? NSNumber)?.doubleValue, error)
    }
  }

  open func duration(_ callback: @escaping (TimeInterval?, Error?) -> Void) {
    evaluatePlayerCommand("getDuration()") { object, error in
      callback((object as? NSNumber)?.doubleValue, error)
    }
  }

  // MARK: Event handling

  func handlePlayerEvent(_ event: YouTubePlayerEvents, data: AnyObject?) {
    switch event {
    case .YouTubeIframeAPIReady:
      ready = true

    case .Ready:
      delegate?.youTubePlayerReady(self)

    case .StateChange:
      if let stateName = data as? Int, let state = YouTubePlayerState(rawValue: stateName) {
        playerState = state
      }

    case .PlaybackQualityChange:
      if let qualityName = data as? String, let quality = YouTubePlaybackQuality(rawValue: qualityName) {
        playbackQuality = quality
      }

    case .PlayTime:
      if let time = data as? TimeInterval {
        playTime = time
      }
    }
  }

}

extension YouTubePlayerView: WKScriptMessageHandler {

  public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    if let dict = message.body as? [String: AnyObject] {
      if let eventName = dict["event"] as? String, let event = YouTubePlayerEvents(rawValue: eventName) {
        handlePlayerEvent(event, data: dict["data"])
      }
    }
  }

}

extension YouTubePlayerView: WKNavigationDelegate {

  public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if let URL = navigationAction.request.url , navigationAction.navigationType == .linkActivated {
      delegate?.youTubePlayerWantsToOpenURL(self, URL: URL)
      decisionHandler(.cancel)
    }
    else {
      decisionHandler(.allow)
    }

  }

}

extension YouTubePlayerView: WKUIDelegate {

  public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
    if let URL = navigationAction.request.url , navigationAction.targetFrame == nil {
      reloadVideo()
      delegate?.youTubePlayerWantsToOpenURL(self, URL: URL)
    }
    return nil
  }

}
