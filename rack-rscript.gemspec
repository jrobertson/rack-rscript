Gem::Specification.new do |s|
  s.name = 'rack-rscript'
  s.version = '0.5.13'
  s.summary = 'Rack-Rscript is a light-weight alternative to Sinatra-Rscript.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/**/*.rb']
  s.add_dependency('rack')
  s.add_dependency('app-routes')
  s.add_dependency('rscript') 
  s.add_dependency('haml') 
  s.add_dependency('tilt') 
  s.add_dependency('slim') 
  s.signing_key = '../privatekeys/rack-rscript.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/rack-rscript'
end
