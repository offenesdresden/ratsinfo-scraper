## mostly copy&paste from: https://github.com/mrcsparker/ruby_tika_app
require 'rubygems'
require 'stringio'
require 'open4'

class TikaApp
    def initialize(document)
        filename = File.basename(document)
        t = Time.now
        puts t.strftime("%H:%M:%S") + ": analyze #{filename}"
        @document = document
        @tika_srv = "http://localhost:9998"
    end

    def tika_running
        out = `curl -X GET http://localhost:9998/tika`
        if out != 'This is Tika Server. Please PUT' then
            abort('Start Tika-server first!')
        end
    end


    def get_xml
        run_tika('tika --header "Accept: text/xml"')
    end

    def get_metadata
        run_tika("meta --header 'Accept: application/json'")
    end

    private

    def run_tika(option)
        final_cmd = "curl -T '#{@document}' #{@tika_srv}/#{option}"
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
