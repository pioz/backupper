require 'shellwords'
require 'sshkit'

module SSHKitSudoExecute
  def sudo_execute(*command, password: nil, sudo: false)
    return execute(*command) unless sudo

    prompt = 'SSHKitSudoPassword'
    execute(
      :sudo,
      '-S',
      '-p', prompt,
      '--',
      'bash', '-c', command.map(&:to_s).join(' ').shellescape,
      interaction_handler: {
        /#{Regexp.escape(prompt)}/ => "#{password}\n"
      }
    )
  end
end
SSHKit::Backend::Abstract.include(SSHKitSudoExecute)
