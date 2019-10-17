Pod::Spec.new do |s|
  s.name             = 'NetworkHandler'
  s.version          = '0.9.3'
  s.summary          = 'NetworkHandler replaces URLSession by providing a clean way to make HTTP network requests'
  s.swift_version    = '5.0'

  s.description      = <<-DESC
NetworkHandler reduces the boilerplate code you need to deal with when you make an HTTP network request! It makes use of the Swift 5 Result type to cut down redundancies.
                       DESC

  s.homepage         = 'https://github.com/mredig/NetworkHandler'
  s.license          = { :type => 'MIT', :file => 'LICENSE.md' }
  s.author           = { 'Michael Redig, Alex Mata, Hector Villasano' => 'refer to github' }
  s.source           = { :git => 'https://github.com/mredig/NetworkHandler.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.11'

  s.source_files = 'NetworkHandler/*.swift'
  s.ios.source_files = 'iOS/*.swift'
  s.osx.source_files = 'macOS/*.swift'

end
