#!/usr/bin/env ruby

# file: rack-rscript.rb


require 'rscript'
require 'app-routes'
require 'requestor'
require 'logger'

class RackRscript
  include AppRoutes

  def initialize(raw_opts={})
    @params = {}

    opts = {logfile: '', logrotate: 'daily', pkg_src: ''}.merge(raw_opts)
    @url_base = opts[:pkg_src] # web server serving the RSF files
    @url_base += '/' unless @url_base[-1] == '/'
    @log = false

    if opts[:logfile].length > 0 then
      @log = true
      @logger = Logger.new(opts[:logfile], opts[:logrotate])
    end

    super() # required for app-routes initialize method to exectue
    default_routes(@params)
  end

  def call(env)
    request = env['REQUEST_URI'][/https?:\/\/[^\/]+(.*)/,1]

    log Time.now.to_s + ": " + request.inspect
    content, content_type, status_code = run_route(request)
    if content.nil? then
      e = $!
      log(e) if e
      content, status_code  = "404: page not found", 404 
    end

    content_type ||= 'text/html'
    status_code ||= 200
    [status_code, {"Content-Type" => content_type}, [content]]
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

    result, args = RScript.new.read([url, jobs.split(/\s/), \
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
  
  private

  def default_routes(params)

    get '/do/:package/:job' do |package,job|
      run_job("%s%s.rsf" % [@url_base, package], "//job:" + job, params)  
    end
    
    get '/do/:package/:job/*' do |package, job|
      raw_args = params[:splat]
      args = raw_args.first[1..-1][/.[\/\w]+/].split('/')
      run_job("%s%s.rsf" % [@url_base, package], "//job:" + job, params, args)
    end        
  end
  
   
end
