Gem::Specification.new do |s|
  s.name = 'email_sender'
  s.version = '1.1.0'
  s.date = '2012-12-27'
  s.platform = 'ruby'
  s.required_ruby_version = '>= 1.9.1'
  s.required_rubygems_version = '>= 0'
  s.require_paths = ['lib']
  s.author = 'Peter Bakonyi'
  s.email = 'bakonyi.peter@gmail.com'
  s.homepage = 'https://github.com/BPeti/email_sender'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.rdoc']
  s.files = ['LICENSE', 'VERSION', 'README.rdoc', 'lib/email_sender.rb']
  s.summary = "EmailSender is an easy to use library to send email."
  s.description = "EmailSender is an easy to use library to send email based on Net::SMTP.\nIt supports the well-known encryption and authentication methods, and you can use it very easily with GMail account."
  s.license = 'LGPL-3'
end
