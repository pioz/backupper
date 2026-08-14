# Backupper

Backupper is a tool to backup all your databases spread all over the world!

## Installation

    $ gem install backupper

## Usage

    $ backupper path/to/config.yml [options]

## Configuration file

A common [YAML](http://yaml.org/) config file for backupper looks like this:

```yaml
mailer:
  from: support@email.com # Gmail account used to send report email
  to: pioz@email.com      # Send report email to this address
  password: Pa$$w0rD      # Gmail account password

default:                  # options here are merged into all database configurations below
  port: 22
  db_username: backup

db1:
  disabled: false                              # true to disable this backup
  dump: '/home/backup/db1'                     # path where to save the dump of the database
  extra_copy: '/mnt/backup-disk/backups/db1'   # path where to save a extra copy of the dump
  username: user                               # server ssh username
  host: '1.2.3.4'                              # server ssh ip
  port: 22                                     # server ssh port
  password: Pa$$w0rD                           # server ssh password (also used as sudo password when sudo is true)
  sudo: false                                  # true to run the dump command with sudo
  adapter: mysql                               # adapter to use to perform the backup (built-in: mysql, postgresql, mydumper — see "Custom adapters")
  database: db_name                            # database name
  db_username: db_user                         # database username
  db_password: db_Pa$$w0rD                     # database password
  dump_options: '--single-transaction --quick' # dump command extra options (shell-style quoted or YAML array)

db2:
  disabled: false
  dump: '/home/backup/db2'
  extra_copy: '/mnt/backup-disk/backups/db2'
  username: user
  host: '1.2.3.4'
  port: 22
  password: Pa$$w0rD
  adapter: postgresql
  database: db_name
  db_username: db_user
  db_password: db_Pa$$w0rD
```

After done all backups a report email is sent to you using gmail smtp service (remember to permit less secure app [here](https://myaccount.google.com/lesssecureapps)).

⚠️ __WARNING__: the backupper configuration file contains many important passwords, so be careful to lock it and protect it with care!

To backup only specific databases you can pass the option `-o db1,db3`. In this way only databases under the key `db1` and `db3` will be backupped,
ignoring the others configuration keys.

## Custom adapters

An adapter is a subclass of `Backupper::Adapter` that declares the extension of the file it produces and builds the shell command used to dump the database:

```ruby
require 'backupper'

class Foodump < Backupper::Adapter
  # Automatically registered as 'foodump' (the underscored class name).
  # Uncomment to use a different name for the `adapter:` configuration key:
  # register 'foo'

  def extension
    return '.sql.gz'
  end

  def command
    params = []
    params << "-u #{username}"
    params << "-p #{password}" if password
    params << dump_options if dump_options
    return "foodump #{database} #{params.join(' ')} | gzip > #{outfile}"
  end
end
```

Inside `command` you never deal with shell escaping: every accessor already returns a shell-escaped value, so interpolate them directly, without wrapping them in quotes.

| accessor       | value                                                                    |
|----------------|--------------------------------------------------------------------------|
| `database`     | database name                                                            |
| `username`     | database username                                                        |
| `password`     | database password, or `nil` if not configured                            |
| `dump_options` | extra options as a single escaped string, or `nil` if not configured     |
| `outfile`      | remote path where the command must write the dump (extension included)  |
| `working_dir`  | empty temporary directory you can use as scratch space                   |

`command` must return a single command string (it is run with `set -o pipefail`, so chaining with `|` and `&&` is fine) and must write the dump to `outfile`. `working_dir` is created before the command runs; both `working_dir` and `outfile` are removed from the server after the download. If two adapters register the same name, the last one loaded wins, so a custom adapter can also replace a built-in one.

⚠️ Upgrading from 0.6: custom adapters written as `DumpCommand` module methods no longer work; port each method to a `Backupper::Adapter` subclass as shown above. Also, `mydumper` archives no longer contain a top-level `<key>__<database>/` directory: the dump files are at the root of the tar, so extract into a dedicated directory (`tar -xf backup.tar -C restore-dir`).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/pioz/backupper.

## Resources
* [Blog post about Backupper](https://tech.uqido.com/2018/07/16/backupper-tool-backup-database/) (italian only).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## About Uqido

[![uqido](https://i.imgur.com/FAo2W7w.png)](http://uqido.com)

Backupper is maintained and funded by [Uqido](https://uqido.com).
The names and logos for Uqido are trademarks of Uqido s.r.l.

The [Uqido team](https://www.uqido.com/en/about-us/).
