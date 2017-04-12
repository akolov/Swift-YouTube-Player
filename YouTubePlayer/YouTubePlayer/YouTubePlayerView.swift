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
  func youTubePlayerWantsToOpenURL(_ videoPlayer: YouTubePlayerView, url: URL)
}

open class YouTubePlayerView: UIView {

  public override init(frame: CGRect) {
    super.init(frame: frame)
    configure()
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    configure()
  }

  // MARK: Public Methods

  public func load(videoID: String) throws {
    var params = playerParameters
    params["videoId"] = videoID
    try loadPlayer(parameters: params)
  }

  public func load(playlistID: String) throws {
    var params = playerParameters
    params["playerVars"] = [
      "listType": "playlist",
      "list": playlistID
    ]
    try loadPlayer(parameters: params)
  }

  public func load(url: URL) throws {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return
    }

    if components.host == "youtu.be" {
      var value = components.path
      value.remove(at: value.startIndex)
      videoID = value
    }
    else if let value = components.queryItems?.first(where: { $0.name == "v" })?.value {
      videoID = value
    }

    if let videoID = videoID {
      try load(videoID: videoID)
    }
  }

  public func reloadVideo() {
    if let html = html {
      webView.loadHTMLString(html, baseURL: originURL)
    }
  }

  public func play() {
    evaluate(command: "playVideo()")
  }

  public func pause() {
    delegate?.youTubePlayerStateChanged(self, playerState: .paused)
    evaluate(command: "pauseVideo()")
  }

  public func stop() {
    evaluate(command: "stopVideo()")
  }

  public func clear() {
    evaluate(command: "clearVideo()")
  }

  public func seekTo(_ seconds: TimeInterval, seekAhead: Bool) {
    evaluate(command: "seekTo(\(seconds), \(seekAhead))")
  }

  public func previousVideo() {
    evaluate(command: "previousVideo()")
  }

  public func nextVideo() {
    evaluate(command: "nextVideo()")
  }

  public func playbackRate(_ callback: @escaping (Float?, Error?) -> Void) {
    evaluate(command: "getPlaybackRate()") { object, error in
      callback((object as? NSNumber)?.floatValue, error)
    }
  }

  public func setPlaybackRate(_ suggestedRate: Float, callback: @escaping (Error?) -> Void) {
    evaluate(command: "setPlaybackRate(\(suggestedRate))") { object, error in
      callback(error)
    }
  }

  public func availablePlaybackRates(_ callback: @escaping ([Float], Error?) -> Void) {
    evaluate(command: "getAvailablePlaybackRates()") { object, error in
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

  public func videoLoadedFraction(_ callback: @escaping (Float?, Error?) -> Void) {
    evaluate(command: "getVideoLoadedFraction()") { object, error in
      callback((object as? NSNumber)?.floatValue, error)
    }
  }

  public func currentTime(_ callback: @escaping (TimeInterval?, Error?) -> Void) {
    evaluate(command: "getCurrentTime()") { object, error in
      callback((object as? NSNumber)?.doubleValue, error)
    }
  }

  public func duration(_ callback: @escaping (TimeInterval?, Error?) -> Void) {
    evaluate(command: "getDuration()") { object, error in
      callback((object as? NSNumber)?.doubleValue, error)
    }
  }

  // MARK: Private Methods

  private func configure() {
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

  private func loadPlayer(parameters: [String: Any]) throws {
    guard let path = Bundle(for: type(of: self)).path(forResource: "Player", ofType: "html") else {
      return
    }

    let data = try JSONSerialization.data(withJSONObject: parameters, options: [])
    guard let json = String(data: data, encoding: .utf8) else {
      return
    }

    html = try String(contentsOfFile: path, encoding: .utf8)
      .replacingOccurrences(of: "@PARAMETERS@", with: json)
      .replacingOccurrences(of: "@TITLE@", with: videoID ?? "")
    reloadVideo()
  }

  private func evaluate(command: String, callback: ((Any?, Error?) -> Void)? = nil) {
    guard isReady else {
      return
    }

    let fullCommand = "player." + command + ";"
    webView.evaluateJavaScript(fullCommand) { object, error in
      callback?(object, error)
      if let error = error {
        print("Failed to evaluate JavaScript command `\(fullCommand)`: \(error.localizedDescription)")
      }
    }
  }

  fileprivate func handlePlayerEvent(_ event: YouTubePlayerEvents, data: AnyObject?) {
    switch event {
    case .YouTubeIframeAPIReady:
      isReady = true

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

  // MARK: Properties

  public weak var delegate: YouTubePlayerDelegate?
  public var playerVars: [String: Any]?
  public var originURL: URL?

  private var playerParameters: [String: Any] {
    var params: [String: Any] = [
      "height": "100%",
      "width": "100%",
      "events": [
        "onReady": "onReady",
        "onStateChange": "onStateChange",
        "onPlaybackQualityChange": "onPlaybackQualityChange",
        "onError": "onPlayerError"
      ]
    ]
    params["playerVars"] = playerVars
    return params
  }

  private(set) public var isReady = false

  private(set) public var playerState = YouTubePlayerState.unstarted {
    didSet {
      delegate?.youTubePlayerStateChanged(self, playerState: playerState)
    }
  }

  private(set) public var playbackQuality = YouTubePlaybackQuality.Default {
    didSet {
      delegate?.youTubePlayerQualityChanged(self, playbackQuality: playbackQuality)
    }
  }

  private(set) public var playTime: TimeInterval? {
    didSet {
      if let playTime = playTime {
        delegate?.youTubePlayerPlayTimeUpdated(self, playTime: playTime)
      }
    }
  }

  private(set) public var videoID: String?
  fileprivate var html: String?
  fileprivate var webView: WKWebView!

}

// MARK: WKScriptMessageHandler

extension YouTubePlayerView: WKScriptMessageHandler {

  public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    if let dict = message.body as? [String: AnyObject] {
      if let eventName = dict["event"] as? String, let event = YouTubePlayerEvents(rawValue: eventName) {
        handlePlayerEvent(event, data: dict["data"])
      }
    }
  }

}

// MARK: WKNavigationDelegate

extension YouTubePlayerView: WKNavigationDelegate {

  public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if let url = navigationAction.request.url , navigationAction.navigationType == .linkActivated {
      delegate?.youTubePlayerWantsToOpenURL(self, url: url)
      decisionHandler(.cancel)
    }
    else {
      decisionHandler(.allow)
    }

  }

}

// MARK: WKUIDelegate

extension YouTubePlayerView: WKUIDelegate {

  public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
    if let url = navigationAction.request.url , navigationAction.targetFrame == nil {
      reloadVideo()
      delegate?.youTubePlayerWantsToOpenURL(self, url: url)
    }
    return nil
  }

}
