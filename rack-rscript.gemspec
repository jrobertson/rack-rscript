Gem::Specification.new do |s|
  s.name = 'rack-rscript'
  s.version = '0.8.0'
  s.summary = 'Rack-Rscript is a light-weight alternative to Sinatra-Rscript.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/rack-rscript.rb']
  s.add_runtime_dependency('rack', '~> 1.6', '>=1.6.4')
  s.add_runtime_dependency('app-routes', '~> 0.1', '>=0.1.18')
  s.add_runtime_dependency('rscript', '~> 0.2', '>=0.2.4') 
  s.add_runtime_dependency('haml', '~> 4.0', '>=4.0.7') 
  s.add_runtime_dependency('tilt', '~> 2.0', '>=2.0.1') 
  s.add_runtime_dependency('slim', '~> 3.0', '>=3.0.7')
  s.signing_key = '../privatekeys/rack-rscript.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/rack-rscript'
  s.required_ruby_version = '>= 2.1.2'
end
