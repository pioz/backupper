require_relative '../adapter'

class Backupper
  module Adapters
    class Mydumper < Backupper::Adapter
      def extension
        return '.tar'
      end

      def command
        params = []
        params << "--user #{username}"
        params << "--password #{password}" if password
        params << dump_options if dump_options
        return "mydumper --database #{database} #{params.join(' ')} --outputdir #{working_dir} && tar -cf #{outfile} -C #{working_dir} ."
      end
    end
  end
end
