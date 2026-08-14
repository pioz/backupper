require_relative '../adapter'

class Backupper
  module Adapters
    class Postgresql < Backupper::Adapter
      def extension
        return '.sql.bz2'
      end

      def command
        params = []
        params << "-U #{username}"
        params << dump_options if dump_options
        return "PGPASSWORD=#{password} pg_dump #{database} #{params.join(' ')} | bzip2 > #{outfile}"
      end
    end
  end
end
