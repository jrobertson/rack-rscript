#!/usr/bin/env ruby

# file: rack-rscript.rb


require 'rsc'
require 'haml'
require 'slim'
require 'tilt'
require 'json'
require 'logger'
require 'rexslt'
require 'rscript'
require 'app-routes'


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


  def initialize(logfile: '', logrotate: 'daily', pkg_src: '', cache: 5, 
                 rsc_host: 'rse', rsc_package_src: nil)
    
    @params = {}
    @templates = {}
    
    @rrscript = RScript.new logfile: logfile, logrotate: logrotate, \
                            pkg_src: pkg_src, cache: cache
    
    @url_base = pkg_src # web server serving the RSF files
    @url_base += '/' unless @url_base[-1] == '/'
    
    @log = false

    if logfile.length > 0 then
      @log = true
      @logger = Logger.new(logfile, logrotate)
    end

    super() # required for app-routes initialize method to exectue
    default_routes(@env, @params)    
    
    @rsc = nil
    @rsc = RSC.new rsc_host, rsc_package_src if rsc_package_src

  end

  def call(env)
    
    @env = env
    request = env['REQUEST_URI'][/https?:\/\/[^\/]+(.*)/,1]

    log "_: " + env.keys.inspect
    log Time.now.to_s + "_: " + env.inspect
    req = Rack::Request.new(env)

    @req_params = req.params
    default_routes(env,@params)
    content, content_type, status_code = run_route(request, env['REQUEST_METHOD'])

    if content.is_a? Redirect then
      
      redirectx = content
      res = Rack::Response.new
      res.redirect(redirectx.to_url)
      res.finish      
      
    else

      e = $!

      if e then
        content, status_code = e, 500
        log(e)      
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
        'application/xml' => passthru_proc,
        'application/json' => passthru_proc,
        'image/png' => passthru_proc,
        'image/jpeg' => passthru_proc
      }
      
      content_type ||= 'text/html'
      status_code ||= 200                  
      proc = ct_list[content_type]
      proc ||= passthru_proc
      content, content_type = proc.call(content, content_type)      
      
      [status_code, {"Content-Type" => content_type}, [content]]
    end
        end

  def clear_cache()
    @rrscript.reset
  end

  def run_job(url, jobs, params={}, *qargs)

    if @params[:splat] then
      @params.each do  |k,v|
        @params.delete k unless k == :splat or k == :package or k == :job or k == :captures
      end
    end  
    
    if @params[:splat] and @params[:splat].length > 0 then
      h = @params[:splat].first[1..-1].split('&').inject({}) do |r,x| 
        k, v = x.split('=')
        v ? r.merge(k[/\w+$/].to_sym => Rack::Utils.unescape(v)) : r
      end
      @params.merge! h
    end
    
    @params.merge! @req_params
    result, args = @rrscript.read([url, jobs.split(/\s/), \
      qargs].flatten)

    rws = self
    rsc = @rsc if @rsc
    
    begin
      r = eval result
      return r

    rescue Exception => e  
      @params = {}
      err_label = e.message.to_s + " :: \n" + e.backtrace.join("\n")      
      raise RackRscriptError, err_label
      log(err_label)
    end
    
  end
  
  def log(msg)
    if @log == true then
      @logger.debug msg
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
      run_job(("%s%s/%s.rsf" % [@url_base, d, package]), "//job:" + job, params) 
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
        

  end

  private

  def render(name, type, opt={})
    
    options = {locals: {}}.merge!(opt)
    locals = options.delete :locals
    
    unless @templates[:layout] then
      template(:layout, type) { File.read('views/layout.' + type.to_s) }
    end
    
    layout = Tilt[type.to_s].new(options) {|x| @templates[:layout][:content]}    

    unless @templates[name] then
      template(name, type) { File.read("views/%s.%s" % [name.to_s, type.to_s]) }
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
    layout = Tilt[@templates[:layout][:type].to_s].new(options) {|x| @templates[:layout][:content]}
    template = Tilt[@templates[name][:type].to_s].new(options) {|x| @templates[name][:content]}
    layout.render{ template.render(self, locals)}
  end    
end
