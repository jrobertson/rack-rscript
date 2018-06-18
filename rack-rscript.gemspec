Gem::Specification.new do |s|
  s.name = 'rack-rscript'
  s.version = '1.1.1'
  s.summary = 'Rack-Rscript is a light-weight alternative to Sinatra-Rscript.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/rack-rscript.rb']
  s.add_runtime_dependency('rack', '~> 2.0', '>=2.0.5')
  s.add_runtime_dependency('app-routes', '~> 0.1', '>=0.1.19')
  s.add_runtime_dependency('rscript', '~> 0.4', '>=0.4.1') 
  # had to comment out haml because of dependency conflict with temple caused
  #  by slim using a fixed version
  #s.add_runtime_dependency('haml', '~> 5.0', '>=5.0.0')
  s.add_runtime_dependency('tilt', '~> 2.0', '>=2.0.8') 
  s.add_runtime_dependency('slim', '~> 3.0', '>=3.0.9')
  s.add_runtime_dependency('json', '~> 2.1', '>=2.1.0')
  s.add_runtime_dependency('rexslt', '~> 0.6', '>=0.6.11')
  s.add_runtime_dependency('rsc', '~> 0.4', '>=0.4.0')
  s.add_runtime_dependency('polyrex-links', '~> 0.3', '>=0.3.0')
  s.signing_key = '../privatekeys/rack-rscript.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/rack-rscript'
  s.required_ruby_version = '>= 2.1.2'
end
