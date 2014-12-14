Gem::Specification.new do |s|
  s.name = 'rack-rscript'
  s.version = '0.6.1'
  s.summary = 'Rack-Rscript is a light-weight alternative to Sinatra-Rscript.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/**/*.rb']
  s.add_runtime_dependency('rack', '~> 1.5', '>=1.5.2')
  s.add_runtime_dependency('app-routes', '~> 0.1', '>=0.1.18')
  s.add_runtime_dependency('rscript', '~> 0.1', '>=0.1.25') 
  s.add_runtime_dependency('haml', '~> 4.0', '>=4.0.5') 
  s.add_runtime_dependency('tilt', '~> 2.0', '>=2.0.1') 
  s.add_runtime_dependency('slim', '~> 2.0', '>=2.0.2')
  s.add_runtime_dependency('websocket-eventmachine-client', '~> 1.0', '>=1.0.1')
  s.signing_key = '../privatekeys/rack-rscript.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/rack-rscript'
  s.required_ruby_version = '>= 2.1.2'
end
