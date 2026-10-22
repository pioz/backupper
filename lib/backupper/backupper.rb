require 'fileutils'
require 'sshkit'
require 'sshkit/dsl'
require 'yaml'

require_relative 'adapter'
require_relative 'adapters/mysql'
require_relative 'adapters/postgresql'
require_relative 'adapters/mydumper'
require_relative 'mailer'
require_relative 'sshkit'

class Backupper
  include SSHKit::DSL

  SSHKit::Backend::Netssh.configure do |ssh|
    ssh.connection_timeout = 30
    ssh.ssh_options = {
      auth_methods: %w[publickey password],
      keepalive: true
    }
  end

  def initialize(conf_file_path)
    conf = YAML.load_file(conf_file_path)
    @default = conf['default'] || {}
    @mailer = conf['mailer'] || {}
    @conf = conf.select { |k, v| !%w[default mailer].include?(k) && (v['disabled'].nil? || v['disabled'] == false) }
    @report = {}
    @logger = SSHKit::Formatter::Pretty.new($stdout)
  end

  def backup!(only_these_keys = nil)
    filtered_conf = @conf
    if only_these_keys
      filtered_conf = @conf.slice(*only_these_keys)
      (only_these_keys - @conf.keys).each do |k|
        err = "Configuration key '#{k}' not found or disabled!"
        error(k, err)
        @logger.error err
      end
    end
    filtered_conf.each do |k, options|
      @logger.info "[#{Time.now}] ⬇️  backing up #{k}..."
      o, err = setup_options(options)
      if err
        error(k, err)
        @logger.error err
        next
      end
      begin
        do_and_download_dump(
          key:          k,
          adapter:      o['adapter'],
          url:          o['url'],
          password:     o['password'],
          database:     o['database'],
          db_username:  o['db_username'],
          db_password:  o['db_password'],
          dump_options: o['dump_options'],
          sudo:         o['sudo'],
          outdir:       o['outdir'],
          extra_copy:   o['extra_copy'],
          tmp_dir:      o['tmp_dir']
        )
      rescue SSHKit::Runner::ExecuteError, ArgumentError, NotImplementedError => e
        error(k, e.to_s)
        @logger.error e
      end
    end
    send_report_email!
  end

  private

    def do_and_download_dump(key:, adapter: 'mysql', url:, password: nil, database:, db_username: 'root', db_password: nil, dump_options: nil, sudo: false, outdir:, extra_copy: nil, tmp_dir: nil)
      t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      adapter = Adapter.find(adapter).new(
        database: database,
        username: db_username,
        password: db_password,
        dump_options: dump_options,
        basename: "#{key}__#{database}",
        tmp_dir: tmp_dir || '/tmp'
      )
      dump_name = "#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}__#{adapter.filename}"
      path = File.join(outdir, dump_name)
      command = adapter.command
      on(url) do |host|
        host.password = password
        sudo_execute :mkdir, '-p', adapter.working_dir, password: password, sudo: sudo
        sudo_execute 'set -o pipefail; ' + command, password: password, sudo: sudo
        download! adapter.outfile_path, path
        sudo_execute :rm, adapter.outfile, password: password, sudo: sudo
        sudo_execute :rm, '-r', adapter.working_dir, password: password, sudo: sudo
      end
      extra_copy = check_dir(extra_copy)
      FileUtils.cp(path, extra_copy) if extra_copy
      @report[key] = {
        path: File.absolute_path(path),
        size: (File.size(path).to_f / 2**20).round(2),
        time: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t).round(2)
      }
      @report[key][:extra_copy] = File.absolute_path(File.join(extra_copy, dump_name)) if extra_copy
    end

    def setup_options(options)
      o = @default.merge(options)
      o['outdir'] = check_dir(o['dump'].to_s)
      return nil, 'Invalid directory where to save database dump' unless o['outdir']
      return nil, 'Please specify the database name!' unless o['database']
      return nil, 'Please specify the host!' unless o['host']

      o['url'] = o['host']
      o['url'] = "#{o['username']}@#{o['url']}" if o['username']
      o['url'] = "#{o['url']}:#{o['port']}" if o['port']
      o['adapter'] ||= 'mysql'
      if Adapter.find(o['adapter']).nil?
        return nil, "Cannot handle adapter '#{o['adapter']}' (supported: #{Adapter.names.join(', ')})"
      end
      begin
        Adapter.shellescape_dump_options(o['dump_options'])
      rescue ArgumentError => e
        return nil, e.message
      end

      return o, nil
    end

    def send_report_email!
      if @report.any? && @mailer['from'] && @mailer['to'] && @mailer['password']
        begin
          Mailer.deliver(@report, from: @mailer['from'], to: @mailer['to'], password: @mailer['password'], address: @mailer['address'] || 'smtp.gmail.com', port: @mailer['port'] || 587, authentication: @mailer['authentication'] || 'plain')
        rescue Net::SMTPAuthenticationError => e
          @logger.error e
        end
      end
    end

    def error(key, error)
      @report[key] = { error: error }
    end

    def check_dir(dirpath)
      return nil if dirpath.nil?

      unless File.exist?(dirpath)
        begin
          FileUtils.mkdir_p(dirpath)
        rescue StandardError => _e
          return nil
        end
      end
      return File.dirname(dirpath) unless File.directory?(dirpath)

      return dirpath
    end
end
