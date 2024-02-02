module DumpCommand
  def self.mysql(database:, username: 'root', password: nil, dump_options: nil, outfile:)
    params = []
    params << "-u'#{username}'"
    params << "-p'#{password}'" if password
    params << dump_options if dump_options
    return "mysqldump '#{database}' #{params.join(' ')} | bzip2 > '#{outfile}'"
  end

  def self.postgresql(database:, username: 'root', password: nil, dump_options: nil, outfile:)
    params = []
    params << "-U '#{username}'"
    params << dump_options if dump_options
    return "PGPASSWORD='#{password}' pg_dump '#{database}' #{params.join(' ')} | bzip2 > '#{outfile}'"
  end
end
