## mostly copy&paste from: https://github.com/mrcsparker/ruby_tika_app
require 'rubygems'
require 'stringio'
require 'open4'

class TikaApp
    def initialize(document)
        @document = document
        java_cmd = 'java'
        java_args = '-server -Djava.awt.headless=true'
        tika_path = "tika-app.jar"
        @tika_cmd = "#{java_cmd} #{java_args} -jar '#{tika_path}'"
    end

    def get_xml
        run_tika('--xml')
    end

    def get_metadata
        run_tika('--metadata --json')
    end


    private

    def run_tika(option)
        final_cmd = "#{@tika_cmd} #{option} '#{@document}'"
        pid, stdin, stdout, stderr = Open4::popen4(final_cmd)
        stdout_result = stdout.read.strip
        stderr_result = stderr.read.strip
        unless strip_stderr(stderr_result).empty?
        end

        stdout_result
    ensure
        stdin.close
        stdout.close
        stderr.close
    end

    def strip_stderr(s)
        s.gsub(/^(info|warn) - .*$/i, '').strip
    end
end
