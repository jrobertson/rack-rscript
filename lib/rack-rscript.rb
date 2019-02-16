#!/usr/bin/env ruby

# file: rack-rscript.rb


require 'rsc'
require 'haml'
require 'slim'
require 'tilt'
require 'json'
require 'rexslt'
require 'rscript'
require 'app-routes'
require 'uri'
require 'polyrex-links'


class Redirect
  attr_reader :to_url
  
  def initialize(url)
    @to_url = url
  end
end

class RackRscriptError < Exception
end

class RackRscript
  include AppRoutes


  def initialize(log: nil, pkg_src: '', cache: 5, rsc_host: 'rse', 
                 rsc_package_src: nil, pxlinks: nil, debug: false,
                 root: 'www', static: [])

    @log, @debug, @static = log, debug, static
    
    puts '@app_root: ' + @app_root.inspect if @debug
    puts 'root: ' + root.inspect if @debug
    
    @params = {}
    
    @templates = {}
    
    @rrscript = RScript.new log: log, pkg_src: pkg_src, cache: cache
    
    @url_base = pkg_src # web server serving the RSF files
    @url_base += '/' unless @url_base[-1] == '/'    
    
    if pxlinks then
      
      src, _ = RXFHelper.read(pxlinks)
      
      if src =~ /^<\?/ then
        
        @pxlinks = PolyrexLinks.new src
        
      else
        
        @pxlinks = PolyrexLinks.new
        @pxlinks.parse pxlinks
        
      end      
      
    end

    super() # required for app-routes initialize method to exectue
    default_routes(@env, @params)    
    
    @rsc = nil
    @rsc = RSC.new rsc_host, rsc_package_src if rsc_package_src
    
    @filetype = {xml: 'application/xml', html: 'text/html', png: 'image/png',
             jpg: 'image/jpeg', txt: 'text/plain', css: 'text/css',
             xsl: 'application/xml', svg: 'image/svg+xml'}    
    
    @root, @static = root, static

  end

  def call(env)
    
    @env = env
    raw_request = env['REQUEST_URI'][/https?:\/\/[^\/]+(.*)/,1]

    @log.info 'RackRscript/call: ' + env.inspect if @log
    @req = Rack::Request.new(env)

    @req_params = @req.params
    default_routes(env,@params)
    
    request = if @pxlinks then
      found = @pxlinks.locate(raw_request)
      found ? found.join : raw_request
    else
      raw_request
    end
    
    run_request(request)
	end

  def clear_cache()
    @rrscript.reset
  end

  def run_job(url, jobs, params={}, *qargs)

    if @params[:splat] then
      @params.each do  |k,v|
        @params.delete k unless k == :splat or k == :package \
            or k == :job or k == :captures
      end
    end  
    
    if @params[:splat] and @params[:splat].length > 0 then
      h = @params[:splat].first[1..-1].split('&').inject({}) do |r,x| 
        k, v = x.split('=')
        v ? r.merge(k[/\w+$/].to_sym => Rack::Utils.unescape(v)) : r
      end
      @params.merge! h
    end
    
    @params.merge! @req.params
    result, args = @rrscript.read([url, jobs.split(/\s/), \
      qargs].flatten)

    rws = self
    rsc = @rsc if @rsc    
    req = @req if @req
    
    begin
      r = eval result
      return r

    rescue Exception => e  
      
      @params = {}
      err_label = e.message.to_s + " :: \n" + e.backtrace.join("\n")      
      raise RackRscriptError, err_label

      @log.debug 'RackRscript/run_job/error: ' + err_label if @log
    end
    
  end

  
  def redirect(url)
    Redirect.new url
  end
  
  # jr 140616 not yet used and still needs to be tested
  def transform(xsl, xml)
    Rexslt.new(xsl, xml).to_s
  end

  def haml(name,options={})    
    render name, :haml, options
  end            
            
  def slim(name,options={})
    render name, :slim, options
  end    
  
  protected

  def default_routes(env, params)


    get '/do/:package/:job' do |package,job|
      run_job("%s%s.rsf" % [@url_base, package], "//job:" + job, params)  
    end    

    get /\/(.*)\/do\/(\w+)\/(\w+)/ do |d, package,job|
      run_job(("%s%s/%s.rsf" % [@url_base, d, package]), 
              "//job:" + job, params) 
    end    

    post '/do/:package/:job' do |package,job|
      run_job("%s%s.rsf" % [@url_base, package], "//job:" + job, params)  
    end
    
    get '/do/:package/:job/*' do |package, job|
      raw_args = params[:splat]
      args = raw_args.first[1..-1][/.\S*/].split('/')
      run_job("%s%s.rsf" % [@url_base, package], "//job:" + job, params, args)
    end

    post '/do/:package/:job/*' do |package, job|
      raw_args = params[:splat]
      args = raw_args.first[1..-1][/.\S*/].split('/')
      run_job("%s%s.rsf" % [@url_base, package], "//job:" + job, params, args)
    end

    get '/source/:package/:job' do |package,job|
      url = "%s%s.rsf" % [@url_base, package]
      [@rrscript.read([url, '//job:' + job]).first, 'text/plain']
    end    

    get '/source/:package' do |package,job|
       
      url = "%s%s.rsf" % [@url_base, package]

      begin
        
        [RXFHelper.read(url).first,'text/plain']

      rescue
        
        ['url: ' + url + '; ' + ($!).inspect + \
          'couldn\'t find that package', 'text/plain']
      end

    end    

    get '/ls' do
       
      File.exists? @url_base
      filepath = @url_base
       
      [Dir.glob(filepath + '/*.rsf').map{|x| x[/([^\/]+)\.rsf$/,1]}.to_json,\
                                                            'application/json']

    end    
    
    if @static.any? then
        
      get /^(\/(?:#{@static.join('|')}).*)/ do |path|

        puts 'path: ' + path.inspect if @debug
        filepath = File.join(@app_root, @root, path )

        if @log then
          @log.info 'DandelionS1/default_routes: ' + 
              "root: %s path: %s" % [@root, path]
        end

        if path.length < 1 or path[-1] == '/' then
          path += 'index.html' 
          File.read filepath
        elsif File.directory? filepath then
          Redirect.new (path + '/') 
        elsif File.exists? filepath then

          content_type = @filetype[filepath[/\w+$/].to_sym]
          [File.read(filepath), content_type || 'text/plain']
        else
          'oops, file ' + filepath + ' not found'
        end

      end
    end

    get /^\/$/ do

      file = File.join(@root, 'index.html')
      File.read file
    end

  end
  
  def run_request(request)
    
    #@log.debug 'inside run_request: ' + request.inspect if @log
    #@log.debug 'inside run_request @env: ' + @env.inspect if @log
    method_type = @env ? @env['REQUEST_METHOD'] : 'GET'
    content, content_type, status_code = run_route(request, method_type)    
    #@log.debug 'inside run_request' if @log
    if content.is_a? Redirect then
      
      redirectx = content
      res = Rack::Response.new
      res.redirect(redirectx.to_url)
      res.finish      
      
    else

      e = $!

      if e then
        content, status_code = e, 500
        @log.debug 'RackRscript/call/error: ' + e if @log
      elsif content.nil? then
        content, status_code  = "404: page not found", 404             
      end      

      tilt_proc = lambda do |s, content_type| 
        type = content_type[/[^\/]+$/]
        s = [s,{}] unless s.is_a? Array
        content, options = s
        [Tilt[type].new() {|x| content}.render(self, options), 'text/html']
      end
      
      passthru_proc = lambda{|c, ct| [c,ct]}
                                          
      ct_list = {
        'text/html' => passthru_proc,
        'text/haml' => tilt_proc,
        'text/slim' => tilt_proc,
        'text/plain' => passthru_proc,
        'text/xml' => passthru_proc,
        'text/css' => passthru_proc,
        'text/markdown' => passthru_proc,
        'application/xml' => passthru_proc,
        'application/xhtml' => passthru_proc,
        'application/json' => passthru_proc,
        'image/png' => passthru_proc,
        'image/jpeg' => passthru_proc,
        'image/svg+xml' => passthru_proc      
      }
      
      content_type ||= 'text/html'
      status_code ||= 200                  
      proc = ct_list[content_type]
      proc ||= passthru_proc
      content, content_type = proc.call(content, content_type)      
      
      [status_code, {"Content-Type" => content_type}, [content]]
    end    
    
  end
  
  alias jumpto run_request

  private

  def render(name, type, opt={})
    
    options = {locals: {}}.merge!(opt)
    locals = options.delete :locals
    
    unless @templates[:layout] then
      template(:layout, type) { File.read('views/layout.' + type.to_s) }
    end
    
    layout = Tilt[type.to_s].new(options) {|x| @templates[:layout][:content]}    

    unless @templates[name] then
      template(name, type) { File.read("views/%s.%s" % [name.to_s, type.to_s])}
    end    

    template = Tilt[type.to_s].new(options) {|x| @templates[name][:content]}
    layout.render{ template.render(self, locals)}
  end            
  
  def template(name, type=nil, &blk)
    @templates.merge!({name => {content: blk.call, type: type}})
    @templates[name]
  end                  

  def tilt(name, options={})
    
    options = {locals: {}}.merge!(opt)
    locals = options.delete :locals
    layout = Tilt[@templates[:layout][:type].to_s].new(options)\
        {|x| @templates[:layout][:content]}
    template = Tilt[@templates[name][:type].to_s].new(options) \
        {|x| @templates[name][:content]}
    layout.render{ template.render(self, locals)}
    
  end    
  
end
