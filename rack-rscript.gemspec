Gem::Specification.new do |s|
  s.name = 'rack-rscript'
  s.version = '0.4.8'
  s.summary = 'Rack-Rscript is a light-weight alternative to Sinatra-Rscript.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/**/*.rb']
  s.add_dependency('rack')
  s.add_dependency('app-routes')
  s.add_dependency('rscript') 
  s.signing_key = '../privatekeys/rack-rscript.pem'
  s.cert_chain  = ['gem-public_cert.pem']
end
