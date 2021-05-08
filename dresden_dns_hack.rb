# HACK around missing DNS record
class TCPSocket
  alias :initialize_old :initialize

  def initialize(host=nil, port=0, local_host=nil, local_port=nil)
    host = "194.49.19.58" if host == "oparl.dresden.de"
    initialize_old(host, port, local_host, local_port)
  end
end
