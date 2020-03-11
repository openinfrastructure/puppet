# e.g. /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/vendor/report_userdata/enabled
enabled_file = File.join([File.dirname(File.expand_path(__FILE__)), "report_userdata/enabled"])
if File.exist?(enabled_file)
  $: << File.join([File.dirname(__FILE__), "report_userdata/lib"])
  require 'report_userdata'
end
