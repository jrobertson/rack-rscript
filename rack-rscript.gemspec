Gem::Specification.new do |s|
  s.name = 'rack-rscript'
  s.version = '1.4.1'
  s.summary = 'Rack-Rscript is a light-weight alternative to Sinatra-Rscript.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/rack-rscript.rb']
  s.add_runtime_dependency('rack', '~> 2.2', '>=2.2.3')
  s.add_runtime_dependency('app-routes', '~> 0.1', '>=0.1.19')
  s.add_runtime_dependency('rscript', '~> 0.9', '>=0.9.0')
  s.add_runtime_dependency('haml', '~> 5.2', '>=5.2.2')
  s.add_runtime_dependency('tilt', '~> 2.0', '>=2.0.10') 
  s.add_runtime_dependency('slim', '~> 4.1', '>=4.1.0')
  s.add_runtime_dependency('rexslt', '~> 0.8', '>=0.8.0')
  s.add_runtime_dependency('rsc', '~> 0.5', '>=0.5.0')
  s.add_runtime_dependency('polyrex-links', '~> 0.5', '>=0.5.0')
  s.add_runtime_dependency('nthrut', '~> 0.1', '>=0.1.0')
  s.signing_key = '../privatekeys/rack-rscript.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/rack-rscript'
  s.required_ruby_version = '>= 2.1.2'
end
