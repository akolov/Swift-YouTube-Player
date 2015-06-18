Pod::Spec.new do |s|

  s.name         = "YouTubePlayer"
  s.version      = "1.0"
  s.summary      = "A swift port of the YouTube embedded player for iOS"

  s.homepage     = "https://github.com/akolov/YouTubePlayer"
  s.license      = { :type => "MIT", :file => "license.txt" }

  s.authors      = { "Corey Auger" => "coreyauger@gmail.com", "Alexander Kolov" => "me@alexkolov.com" }
  s.platform     = :ios, "8.0"

  s.source       = { :git => "https://github.com/akolov/YouTubePlayer.git", :tag => "1.0" }

  s.source_files  = "Classes", "Classes/**/*.{h,m}", "YouTubePlayer/**/*.{swift,h,m}"
  s.exclude_files = "Classes/Exclude"

  s.resource  = "YouTubePlayer/YouTubePlayer/Player.html"

end
