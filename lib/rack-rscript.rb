#!/usr/bin/env ruby

# file: rack-rscript.rb


require 'rscript'
require 'app-routes'
require 'logger'
require 'haml'
require 'slim'
require 'tilt'

class Redirect
  attr_reader :to_url
  
  def initialize(url)
    @to_url = url
  end
end

class RackRscript
  include AppRoutes

  def initialize(raw_opts={})
    @params = {}
    @templates = {}
    
    @rrscript = RScript.new
    
    opts = {logfile: '', logrotate: 'daily', pkg_src: ''}.merge(raw_opts)
    @url_base = opts[:pkg_src] # web server serving the RSF files
    @url_base += '/' unless @url_base[-1] == '/'
    
    @log = false

    if opts[:logfile].length > 0 then
      @log = true
      @logger = Logger.new(opts[:logfile], opts[:logrotate])    
    end

    super() # required for app-routes initialize method to exectue
    default_routes(@env, @params)
  end

  def call(env)
    @env = env
    request = env['REQUEST_URI'][/https?:\/\/[^\/]+(.*)/,1]

    log "_: " + env.keys.inspect
    log Time.now.to_s + "_: " + env.inspect

    default_routes(env,@params)
    content, content_type, status_code = run_route(request)        

    if content.is_a? Redirect then
      redirectx = content
      res = Rack::Response.new
      res.redirect(redirectx.to_url)
      res.finish      
    else
      
      if content.nil? then
        e = $!
        log(e) if e
        content, status_code  = "404: page not found", 404             
      end      

      tilt_proc = lambda do |s, content_type| 
        type = content_type[/[^\/]+$/]
        s = [s,{}] unless s.is_a? Array
        content, options = s
        [Tilt[type].new(options) {|x| content}.render, 'text/html']
      end
      
      passthru_proc = lambda{|c, ct| [c,ct]}
      
      ct_list = {
        'text/html' => passthru_proc,
        'text/haml' => tilt_proc,
        'text/slim' => tilt_proc,
        'text/plain' => passthru_proc
      }
      content_type ||= 'text/html'
      status_code ||= 200                  
      content, content_type = ct_list[content_type].call(content, content_type)      
      
      [status_code, {"Content-Type" => content_type}, [content]]
    end
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
        v ? r.merge(k[/\w+$/].to_sym => v) : r
      end
      @params.merge! h
    end
    
    result, args = @rrscript.read([url, jobs.split(/\s/), \
      qargs].flatten)

    rws = self
    
    begin
      r = eval result
      return r

    rescue Exception => e  
      @params = {}
      err_label = e.message.to_s + " :: \n" + e.backtrace.join("\n")      
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

  def haml(name,options={})    
    render name, :haml
  end            
            
  def slim(name,options={})
    render name, :slim
  end    
  
  private

  def default_routes(env, params)

    get '/do/:package/:job' do |package,job|
      run_job("%s%s.rsf" % [@url_base, package], "//job:" + job, params)  
    end
    
    get '/do/:package/:job/*' do |package, job|
      raw_args = params[:splat]
      args = raw_args.first[1..-1][/.[\/\w]+/].split('/')
      run_job("%s%s.rsf" % [@url_base, package], "//job:" + job, params, args)
    end

    get '/source/:package/:job' do |package,job|
      url = "%s%s.rsf" % [@url_base, package]
      [@rrscript.read([url, '//job:' + job]).first, 'text/plain']
    end    

     get '/source/:package' do |package,job|
       url = "%s%s.rsf" % [@url_base, package]
       [open(url,'User-Agent' => 'Rack-Rscript v0.5'){|x| x.read },'text/plain']
    end    
    

  end

  def render(name, type, options={})
    layout = Tilt[type.to_s].new(options) {|x| @templates[:layout][:content]}
    template = Tilt[type.to_s].new(options) {|x| @templates[name][:content]}
    layout.render{ template.render }
  end            
  
  def template(name, type=nil, &blk)
    @templates.merge!({name => {content: blk.call, type: type}})
  end                  

  def tilt(name, options={})
    
    layout = Tilt[@templates[:layout][:type].to_s].new(options) {|x| @templates[:layout][:content]}
    template = Tilt[@templates[name][:type].to_s].new(options) {|x| @templates[name][:content]}
    layout.render{ template.render }
  end    
end

