require 'mail'

class Mailer
  def self.send(report, from:, to:, password:, address:, port:, authentication:)
    Mail.defaults do
      delivery_method :smtp, {
        address:              address,
        port:                 port,
        user_name:            from,
        password:             password,
        authentication:       authentication,
        enable_starttls_auto: true
      }
    end
    Mail.deliver(to: to, from: from, subject: generate_subject(report), body: generate_body(report))
  end

  class << self
    private

      def generate_body(report)
        b = []
        report.each do |k, data|
          s = ''
          if data[:error]
            s << "❌ #{k}\n"
            s << '=' * 80 << "\n"
            s << "Backup FAILED!\n"
            s << "  error: #{data[:error]}\n"
          else
            s << "️✅ #{k}\n"
            s << '=' * 80 << "\n"
            s << "Backup SUCCESS!\n"
            s << "  dump size: #{data[:size]} MB\n"
            s << "  time: #{data[:time]} seconds\n"
            s << "  dump saved in: #{data[:path]}\n"
            if data[:extra_copy]
              s << "  extra copy in: #{data[:extra_copy]}\n"
            else
              s << "  no extra copy has been made\n"
            end
          end
          b << s
        end
        return "Report for backups (#{Time.now})\n\n#{b.join("\n\n")}"
      end

      def generate_subject(report)
        errors = report.select { |_k, v| v[:error] }.size
        icon = '✅'
        icon = '⚠️' if errors > 0
        icon = '❌' if errors == report.size
        return "[Backupper] #{report.size - errors}/#{report.size} backups successfully completed #{icon}"
      end
  end
end
