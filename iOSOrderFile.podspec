Pod::Spec.new do |s|
  s.name = 'iOSOrderFile'
  s.version = '0.1.0'
  s.summary = 'A short description of iOSOrderFile.'
  s.description = 'this is a simple tool for generate clang order file'
  s.homepage = 'https://github.com/xiongzenghui/iOSOrderFile'
  s.license = {:type => 'MIT', :file => 'LICENSE'}
  s.author = {'xiongzenghui' => 'zxcvb1234001@163.com'}
  s.source = {:git => 'https://github.com/xzhhe/iOSOrderFile', :tag => s.version.to_s}
  s.ios.deployment_target = '8.0'
  s.source_files = 'iOSOrderFile/Classes/**/*'
  s.static_framework = true
end