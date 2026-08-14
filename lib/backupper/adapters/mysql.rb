require_relative '../adapter'

class Backupper
  module Adapters
    class Mysql < Backupper::Adapter
      def extension
        return '.sql.bz2'
      end

      def command
        params = []
        params << "-u#{username}"
        params << "-p#{password}" if password
        params << dump_options if dump_options
        return "mysqldump #{database} #{params.join(' ')} | bzip2 > #{outfile}"
      end
    end
  end
end
