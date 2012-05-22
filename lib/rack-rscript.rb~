#!/usr/bin/env ruby

# file: rack-rscript.rb


require 'rscript'
require 'app-routes'

class RackRscript
  include AppRoutes

  def initialize(raw_opts={})
    
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

    log Time.now.to_s + ": " + request
    content, content_type, status_code = run_route(request)
    content, status_code  = "404: page not found", 404 if content.nil?

    content_type ||= 'text/html'
    status_code ||= 200
	  [status_code, {"Content-Type" => content_type}, [content]]
	end

  private

  def default_routes(params)

    get '/do/:package/:job' do |package,job|
      run_job("%s%s.rsf" % [@url_base, package], "//job:" + job, params)  
    end
    
    get '/do/:package/:job/*' do |package, job|
      raw_args = params[:splat]
      args = raw_args.join.split('/')[1..-1]
      run_job("%s%s.rsf" % [@url_base, package], "//job:" + job, params, args)
    end        
  end

  def run_job(url, jobs, params={}, *qargs)
    if params[:splat] and params[:splat].length > 0 then
      h = params[:splat].first[1..-1].split('&').inject({}) do |r,x| 
        k, v = x.split('=')
        r.merge(k.to_sym => v)
      end
      params.merge! h
    end

    result, args = RScript.new.read([url, jobs.split(/\s/), \
      qargs].flatten)
    rws = self
    
    begin
      r = eval result
      @params = {}
      return r

    rescue Exception => e  

      err_label = e.message.to_s + " :: \n" + e.backtrace.join("\n")      
      log(err_label)
      ($!).to_s
    end
  end

  def log(msg)
    if @log == true then
      @logger.debug msg
    end
  end
end
