require 'shellwords'

class Backupper
  # Base class for dump adapters. A subclass must implement `#extension` and
  # `#command`; it is automatically registered under its underscored class
  # name (use `register 'name'` to pick a different one).
  class Adapter
    @subclasses = []

    class << self
      def inherited(subclass)
        super
        Backupper::Adapter.subclasses << subclass
      end

      def register(name)
        @adapter_name = name.to_s
      end

      def adapter_name
        return @adapter_name if defined?(@adapter_name) && @adapter_name
        # On Ruby < 3.0 `inherited` fires before the constant is assigned, so
        # the name must be derived lazily, at lookup time.
        return nil if name.nil?

        basename = name.split('::').last
        return basename.gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
      end

      def find(name)
        # Reverse scan: a later-loaded custom adapter can shadow a built-in name.
        return Backupper::Adapter.subclasses.reverse_each.find { |klass| klass.adapter_name == name.to_s }
      end

      def names
        return Backupper::Adapter.subclasses.map(&:adapter_name).compact.uniq.sort
      end

      def subclasses
        return @subclasses ||= []
      end

      def shellescape_dump_options(dump_options)
        return nil if dump_options.nil?

        options =
          if dump_options.is_a?(Array)
            dump_options.map(&:to_s)
          else
            Shellwords.split(dump_options.to_s)
          end
        return nil if options.empty?

        return options.map { |option| Shellwords.escape(option) }.join(' ')
      rescue ArgumentError => e
        raise ArgumentError, "Invalid dump_options: #{e.message}"
      end
    end

    # All values arrive raw; escaping happens in the accessors below.
    def initialize(database:, username: 'root', password: nil, dump_options: nil, basename:, tmp_dir: '/tmp')
      @raw_database = database
      @raw_username = username
      @raw_password = password
      @raw_dump_options = dump_options
      @raw_basename = basename
      @raw_tmp_dir = tmp_dir
    end

    # Extension of the file produced by `#command` (e.g. '.sql.bz2').
    def extension
      raise NotImplementedError, "#{self.class} must implement #extension"
    end

    # Shell command that writes the dump to `outfile`.
    def command
      raise NotImplementedError, "#{self.class} must implement #command"
    end

    # Raw paths, for the orchestrator (SSHKit download!, report).
    def filename
      return "#{@raw_basename}#{extension}"
    end

    def outfile_path
      return File.join(@raw_tmp_dir, filename)
    end

    def working_dir_path
      return File.join(@raw_tmp_dir, @raw_basename)
    end

    # Shell-escaped accessors: interpolate them directly in `#command`.
    def database
      return Shellwords.escape(@raw_database)
    end

    def username
      return Shellwords.escape(@raw_username)
    end

    def password
      return @raw_password && Shellwords.escape(@raw_password)
    end

    def dump_options
      return Backupper::Adapter.shellescape_dump_options(@raw_dump_options)
    end

    def outfile
      return Shellwords.escape(outfile_path)
    end

    def working_dir
      return Shellwords.escape(working_dir_path)
    end
  end
end
