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
  include RXFHelperModule
  using ColouredText

  attr_reader :req, :rsc


  def initialize(log: nil, pkg_src: '', cache: 5, rsc_host: nil,
                 rsc: {host: rsc_host, port: '61000'},
                 pxlinks: nil, debug: false, root: '', static: {})

    @log, @debug, @static = log, debug, static
#=begin
    puts '@app_root: ' + @app_root.inspect if @debug
    puts 'root: ' + root.inspect if @debug

    @params = {}

    @templates = {}

    @rscript = RScriptRW.new log: log, pkg_src: pkg_src, cache: cache, debug: true
    @render = NThrut.new(self)

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
    default_routes(@env, @params || {})

    @rsc = nil

    if rsc[:host] and rsc[:host].length > 0 then
      @rsc = RSC.new(rsc[:host], port: rsc[:port])
    end

    @filetype = {xml: 'application/xml', html: 'text/html', png: 'image/png',
             jpg: 'image/jpeg', txt: 'text/plain', css: 'text/css',
             xsl: 'application/xml', svg: 'image/svg+xml'}

    @root, @static = root, static
    @initialized = {}
#=end
  end

  def call(env, testmode: false)


    @env = env
    raw_request = env['REQUEST_URI'][/\/\/[^\/]+(.*)/,1]
    #raw_request = env['REQUEST_PATH']

    @log.info 'RackRscript/call: ' + env.inspect if @log

    if testmode == false then

      @req = Rack::Request.new(env)
      @req_params = @req.params

    end

    default_routes(env,@params)

    request = if @pxlinks then
      found = @pxlinks.locate(raw_request)
      found ? found.join : raw_request
    else
      raw_request
    end

    @log.info 'RackRscript/call/request: ' + request.inspect if @log
#=begin
    puts 'request: ' + request.inspect if @debug
    run_request(request)
#=end
#    [200, {"Content-Type" => "text/plain"}, [env.inspect]]
	end

  def clear_cache()
    @rscript.reset
  end

  def run_job(url, job, params={}, type=:get, *qargs)

    puts 'inside run_job' if @debug
    @log.debug 'RackRscript/run_job/params: ' + params.inspect if @log
    @log.debug 'RackRscript/run_job/qargs: ' + qargs.inspect if @log

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

    @params.merge! @req.params if @req
    @rscript.type = type

    if not @rscript.jobs(url).include?(job.to_sym) then

      if @rscript.jobs(url).include?(:job_missing) then
        job = 'job_missing'
      else
        [404, 'job not found']
      end

    end

    result, args = @rscript.read([url, '//job:' + job, \
      qargs].flatten)

    rws = self
    rsc = @rsc if @rsc
    req = @req if @req

    begin

      if @debug then
        puts @rscript.jobs(url).inspect
        puts 'job: ' + job.inspect
        puts 'url: ' + url.inspect
        puts '@initialized: ' + @initialized.inspect
        bflag = @rscript.jobs(url).include?(:initialize) and \
            !@initialized[url] and job != 'initialize'
        puts 'bflag: ' + bflag.inspect
      end

      if @rscript.jobs(url).include?(:initialize) and
          !@initialized[url]  and job != 'initialize' then
        puts 'before run initialize' if @debug
        r2 = @rscript.read([url, '//job:initialize'])
        puts 'r2: ' + r2.inspect if @debug
        eval r2.join
        @initialized[url] = true
      end


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
    @render.haml name, options
  end

  def slim(name,options={})
    @render.slim name, options
  end

  protected

  def default_routes(env, params)

    @log.info 'RackRscript/default_routes: ' + params.inspect if @log

    get '/do/:package/:job' do |package,job|
      @log.info 'RackRscript/route/do/package/job: ' + [package, job].inspect if @log
      run_job("%s%s.rsf" % [@url_base, package], job, params)
    end

    get '/:dir/do/:package/:job' do |dir, package, job|
      run_job(("%s%s/%s.rsf" % [@url_base, dir, package]), job, params)
    end

    get '/:dir/do/:package/:job/*' do |dir, package, job|
      raw_args = params[:splat]
      args = raw_args.first[/[^\s\?]+/].to_s.split('/')[1..-1]
      run_job(("%s%s/%s.rsf" % [@url_base, dir, package]), job, params, :get, args)
    end

    post '/do/:package/:job' do |package,job|
      run_job("%s%s.rsf" % [@url_base, package], job, params, :post)
    end

    post '/:dir/do/:package/:job' do |dir, package,job|
      run_job(("%s%s/%s.rsf" % [@url_base, dir, package]), job, params, :post)
    end

    get '/do/:package/:job/*' do |package, job|
      raw_args = params[:splat]
      args = raw_args.first[/[^\s\?]+/].to_s.split('/')[1..-1]
      run_job("%s%s.rsf" % [@url_base, package], job, params, :get, args)
    end

    post '/do/:package/:job/*' do |package, job|
      raw_args = params[:splat]
      args = raw_args.first[/[^\s\?]+/].to_s.split('/')[1..-1]
      run_job("%s%s.rsf" % [@url_base, package], job, params, :post, args)
    end

    post '/:dir/do/:package/:job/*' do |package, job|
      raw_args = params[:splat]
      args = raw_args.first[/[^\s\?]+/].to_s.split('/')[1..-1]
      run_job("%s%s/%s.rsf" % [@url_base, dir, package], job, params, :post, args)
    end

    get '/source/:package/:job' do |package,job|
      url = "%s%s.rsf" % [@url_base, package]
      [@rscript.read([url, job]).first, 'text/plain']
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

      FileX.exists? @url_base
      filepath = @url_base

      [Dir.glob(filepath + '/*.rsf').map{|x| x[/([^\/]+)\.rsf$/,1]}.to_json,\
                                                            'application/json']

    end

    if @static.any? then

      get /^(\/(?:#{@static.keys.join('|')}).*)/ do |raw_path|

        _, file, tailpath = raw_path.split('/',3)

        filepath = if @static[file].empty? then

          path = raw_path
          puts 'path: ' + path.inspect if @debug
          filepath = File.join(@app_root, @root, path )

        else

          File.join(@static[file], tailpath)

        end

        @log.debug 'RackRscript/default_routes/filepath: ' + filepath.inspect if @log


        if @log then
          @log.info 'DandelionS1/default_routes: ' +
              "root: %s path: %s" % [@root, path]
        end

        if filepath.length < 1 or filepath[-1] == '/' then
          filepath += 'index.html'
          FileX.read filepath
        elsif FileX.directory? filepath then
          Redirect.new (filepath + '/')
        elsif FileX.exists? filepath then

          content_type = @filetype[filepath[/\w+$/].to_sym]
          [FileX.read(filepath), content_type || 'text/plain']
        else
          'oops, file ' + filepath + ' not found'
        end

      end
    end

    get /^\/$/ do

      if @root.length > 0 then
        file = File.join(@root, 'index.html')
        File.read file
      else
        Time.now.inspect
      end

    end

    # file exists?
    a = Dir.glob( File.join(@root.to_s, '*')).select do |x|
      File::ftype(x) == 'directory'
    end

    get /^\/#{a.join('|')}/ do

    'found' + a.inspect

    end

  end

  def run_request(request)

    #@log.debug 'inside run_request: ' + request.inspect if @log
    #@log.debug 'inside run_request @env: ' + @env.inspect if @log
    method_type = @env ? @env['REQUEST_METHOD'] : 'GET'
    content, content_type, status_code = run_route(request, method_type)
    @log.info 'RackRscript/run_request/content: ' + content.inspect if @log
    #puts 'content: ' + content.inspect if @debug

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

  def template(name, type=nil, &blk)
    @render.template name, type, &blk
  end

end
