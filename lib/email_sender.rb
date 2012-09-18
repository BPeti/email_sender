# EmailSender library - Easy to use email sending library via SMTP
# Copyright (C) 2012 Péter Bakonyi <bakonyi.peter@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License
# version 3.0 as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License version 3.0 for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with the papyrus library. If not, see
# <http://www.gnu.org/licenses/>.


require 'openssl'
require 'net/smtp'


# == Usage
#   mailer = EmailSender.new(server: "smtp.mail.com", from: "sender@mail.com")
#   mailer = EmailSender.new(server: "smtp.mail.com", port: 465, from: Sender Name <"sender@mail.com">,
#     enctype: :ssl_tls, authtype: :plain, username: "user.name", password: "secret")
#
#   mailer = EmailSender.new_gmail(username: "user.name", password: "secret")
#   mailer = EmailSender.new_gmail(from: "Sender Name <user.name@gmail.com>", password: "secret")
#
#   mailer.send(to: "receiver@mail.com", subject: "Test mail!", content: "This is a test mail!")
#   mailer.send(to: "Receiver Name 1 <receiver1@mail.com>", cc: "Receiver Name 2 <receiver2@mail.com>",
#     subject: "Test mail!", content: "This is a test mail!", attachment: "/path/to/file")
# See the README for more useful examples!
class EmailSender
  # Major version number
  VERSION_MAJOR = 1
  # Minor version number
  VERSION_MINOR = 0
  # Tiny version number
  VERSION_TINY  = 0
  # Version number
  VERSION_CODE  = (VERSION_MAJOR << 16) | (VERSION_MINOR << 8) | VERSION_TINY
  # Version string
  VERSION       = "#{VERSION_MAJOR}.#{VERSION_MINOR}.#{VERSION_TINY}".freeze

  ATTACHMENT_READ_CACHE = 116736 # multiple to 57 #:nodoc:

  Settings = Struct.new(:server, :port, :domain, :esmtp, :enctype, :authtype,
    :username, :password, :from_addr, :to_addrs, :cc_addrs, :bcc_addrs) #:nodoc:

  # Create a new mailer object and initialize connection parameters to SMTP server.
  #   +-----------------------------------------------------------------------------------+
  #   |                             Initialization Parameters                             |
  #   +------------+-------------------------------------------+--------------------------+
  #   |Key         |Possible Values                            |Default Value             |
  #   +------------+-------------------------------------------+--------------------------+
  #   |:server     |<string>                                   |                          |
  #   |:port       |<number>                                   |25, 465 or 587            |
  #   |:domain     |<string>                                   |-> domain of from address |
  #   |:esmtp      |:enabled/true, :disabled/false             |:enabled                  |
  #   |:enctype    |:none, :starttls_auto, :starttls, :ssl_tls |:none                     |
  #   |:authtype   |:none, :plain, :login, :cram_md5           |:none                     |
  #   |:username   |<string>                                   |nil                       |
  #   |:password   |<string>                                   |nil                       |
  #   |:from       |<string>                                   |                          |
  #   |:to         |<string>, <array of string>                |[]                        |
  #   |:cc         |<string>, <array of string>                |[]                        |
  #   |:bcc        |<string>, <array of string>                |[]                        |
  #   +------------+-------------------------------------------+--------------------------+
  def initialize(params)
    renew(params)
  end

  # Update the connection parameters to SMTP server.
  # See the ::new method for initialization parameters.
  def renew(params)
    settings = Settings.new
    settings.from_addr = parse_addr(params[:from])
    settings.to_addrs = parse_addrs(*params[:to])
    settings.cc_addrs = parse_addrs(*params[:cc])
    settings.bcc_addrs = parse_addrs(*params[:bcc])
    settings.domain = params[:domain] || settings.from_addr.last.split('@').last
    settings.esmtp = params[:esmtp] != :disabled and params[:esmtp] != false
    settings.enctype = params[:enctype]
    authtype = params[:authtype]
    username = params[:username]
    password = params[:password]
    if password and username and authtype and authtype != :none
      settings.authtype = authtype
      settings.username = username.encode(Encoding::UTF_8)
      settings.password = password.encode(Encoding::UTF_8)
    end
    settings.server = params[:server].encode(Encoding::UTF_8)
    settings.port = params[:port] || case settings.enctype
      when :starttls then Net::SMTP.default_submission_port
      when :ssl_tls then Net::SMTP.default_tls_port
      else Net::SMTP.default_port
    end
    @settings = settings
  end

  # Create a new mailer object and initialize connection parameters to Gmail server.
  #   +-----------------------------------------------------------------------------------+
  #   |                          Gmail Initialization Parameters                          |
  #   +------------+-------------------------------------------+--------------------------+
  #   |Key         |Possible Values                            |Default Value             |
  #   +------------+-------------------------------------------+--------------------------+
  #   |:username   |<string>                                   |-> from address           |
  #   |:password   |<string>                                   |                          |
  #   |:from       |<string>                                   |-> username parameter     |
  #   |:to         |<string>, <array of string>                |[]                        |
  #   |:cc         |<string>, <array of string>                |[]                        |
  #   |:bcc        |<string>, <array of string>                |[]                        |
  #   +------------+-------------------------------------------+--------------------------+
  def self.new_gmail(params)
    instance = allocate()
    instance.renew_gmail(params)
    instance
  end

  # Update the connection parameters to Gmail server.
  # See the ::new_gmail method for Gmail initialization parameters.
  def renew_gmail(params)
    params = params.dup
    params[:server] = 'smtp.gmail.com'
    params[:port] = 465
    params[:domain] = 'gmail.com'
    params[:esmtp] = :enabled
    params[:enctype] = :ssl_tls
    params[:authtype] = :plain
    username = params[:username]
    from = params[:from]
    if username
      username = username.encode(Encoding::UTF_8)
      params[:username] = username << '@gmail.com' unless username.include?('@')
      params[:from] = username unless from
    end
    if from
      from_name, from_addr = parse_addr(from)
      unless from_addr.include?('@')
        from_addr << '@gmail.com'
        params[:from] = from_name ? "#{from_name} <#{from_addr}>" : from_addr
      end
      params[:username] = from_addr unless username
    end
    renew(params)
  end

  # Send an email with the specified parameters.
  #   +-----------------------------------------------------------------------------------+
  #   |                                Sending Parameters                                 |
  #   +------------+-------------------------------------------+--------------------------+
  #   |Key         |Possible Values                            |Default Value             |
  #   +------------+-------------------------------------------+--------------------------+
  #   |:to         |<string>, <array of string>                |\   values of             |
  #   |:cc         |<string>, <array of string>                | >  initialization        |
  #   |:bcc        |<string>, <array of string>                |/   parameters            |
  #   |:subject    |<string>                                   |''                        |
  #   |:content    |<string>                                   |-> subject parameter      |
  #   |:conttype   |<string>                                   |'text/plain'              |
  #   |:attachment |<string>, <array of string>                |[]                        |
  #   +------------+-------------------------------------------+--------------------------+
  # See the README for more information!
  def send(params={})
    settings = @settings
    subject = params[:subject] || ''
    content = params[:content] || subject
    conttype = params[:conttype] || 'text/plain'
    attachment = *params[:attachment]
    to = *params[:to]
    cc = *params[:cc]
    bcc = *params[:bcc]
    if to.empty? and cc.empty? and bcc.empty?
      to_addrs = settings.to_addrs
      cc_addrs = settings.cc_addrs
      bcc_addrs = settings.bcc_addrs
    else
      to_addrs = parse_addrs(*to)
      cc_addrs = parse_addrs(*cc)
      bcc_addrs = parse_addrs(*bcc)
    end
    unless to_addrs.empty?
      subject = subject.encode(Encoding::UTF_8)
      content = content.encode(Encoding::UTF_8)
      smtp = Net::SMTP.new(settings.server, settings.port)
      smtp.disable_starttls
      smtp.disable_tls
      case settings.enctype
        when :starttls_auto then smtp.enable_starttls_auto
        when :starttls then smtp.enable_starttls
        when :ssl_tls then smtp.enable_tls
      end
      smtp.esmtp = settings.esmtp
      message_id = nil
      smtp.start(settings.domain, settings.username, settings.password, settings.authtype) do
        from_name, from_addr = settings.from_addr
        smtp.open_message_stream(from_addr, *to_addrs.keys, *cc_addrs.keys, *bcc_addrs.keys) do |stream|
          now = Time.now
          random_id = '%04x%04x.%08x.%08x.%08x' % [Process.pid & 0xFFFF, Thread.current.object_id & 0xFFFF,
            now.tv_sec & 0xFFFF_FFFF, now.tv_nsec, rand(0x1_0000_0000)]
          message_id = "#{random_id}@#{settings.domain}"
          boundary = "boundary0_#{random_id}"
          stream.puts("Message-ID: <#{message_id}>")
          stream.puts(now.strftime('Date: %a, %d %b %Y %H:%M:%S %z'))
          stream.puts("From: " << (from_name ? (from_name.ascii_only? ? "#{from_name} <#{from_addr}>" :
            "=?utf-8?B?#{[from_name].pack('m0')}?= <#{from_addr}>") : from_addr))
          to_str = ''
          to_addrs.each do |addr, name|
            to = name ? "#{name.ascii_only? ? name : "=?utf-8?B?#{[name].pack('m0')}?="} <#{addr}>" : addr
            to_str << (to_str.empty? ? "To: #{to}" : ",\n\t#{to}")
          end
          stream.puts(to_str) unless to_str.empty?
          cc_str = ''
          cc_addrs.each do |addr, name|
            cc = name ? "#{name.ascii_only? ? name : "=?utf-8?B?#{[name].pack('m0')}?="} <#{addr}>" : addr
            cc_str << (cc_str.empty? ? "CC: #{cc}" : ",\n\t#{cc}")
          end
          stream.puts(cc_str) unless cc_str.empty?
          stream.puts("Subject: " << (subject.ascii_only? ? subject : "=?utf-8?B?#{[subject].pack('m0')}?="))
          stream.puts("MIME-Version: 1.0")
          unless attachment.empty?
            stream.puts("Content-Type: multipart/mixed; boundary=\"#{boundary}\"")
            stream.puts
            stream.puts("This is a multi-part message in MIME format.")
            stream.puts("--#{boundary}")
          end
          stream.puts("Content-Type: #{conttype}; charset=#{content.ascii_only? ? 'us-ascii' : 'utf-8'}")
          stream.puts("Content-Transfer-Encoding: base64")
          stream.puts
          stream.print([content].pack('m57'))
          unless attachment.empty?
            attachment.each do |file|
              file = file.encode(Encoding::UTF_8)
              basename = File.basename(file)
              filename = basename.ascii_only? ? basename : "=?utf-8?B?#{[basename].pack('m0')}?="
              stream.puts("--#{boundary}")
              stream.puts("Content-Type: application/octet-stream; name=\"#{filename}\"")
              stream.puts("Content-Transfer-Encoding: base64")
              stream.puts("Content-Disposition: attachment; filename=\"#{filename}\"")
              stream.puts
              File.open(file) { |io| stream.print([io.read(ATTACHMENT_READ_CACHE)].pack('m57')) until io.eof? }
            end
            stream.puts("--#{boundary}--")
          end
        end
      end
      message_id
    end
  end

private
  def parse_addr(str)
    str = str.encode(Encoding::UTF_8)
    str.scan(/\A\s*(.*?)\s*<([^<]*?)>\s*\z/).first || [nil, (str.strip!; str)]
  end
  def parse_addrs(*strs)
    addrs = {}
    strs.each do |str|
      name, addr = parse_addr(str)
      addrs[addr] = name
    end
    addrs
  end
end
