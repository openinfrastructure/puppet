# Report Userdata

This library patches Puppet reports to include a user-defined key/value map.
This map is populated on the agent, sent to the server, and available to custom
report processors.

Tested with puppet agent 5.5.14 and puppetserver version: 5.3.8 (Puppet 5.5.18).

# Installation

Deploy the entry point.  `load_report_userdata.rb` is automatically loaded by
Puppet early in the lifecycle of both the agent and the master.  Note the code
is inert until
`/opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/vendor/report_userdata/enabled`
exists in the filesystem.

    /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/vendor/load_report_userdata.rb

Then, deploy the contents of the following directory.  These files contain the
changes to Puppet's behavior which augment Puppet::Transaction::Report
instances to include userdata.

    /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/vendor/report_userdata/

Agent behavior is modified to include enforced classes from the catalog in the
report userdata.

Master behavior is modified to serialize the userdata to JSON and make the data
available to custom report processors.

Finally, enable the patching by creating the file
`/opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/vendor/report_userdata/enabled`

# Development

The master and the agent share the same code directory:

    /opt/puppetlabs/puppet/lib/ruby/vendor_ruby

Both the server and the agent patch Puppet using
`Puppet::Vendor#load_vendored`.  This mechanism enables separation, upstream
Puppet code distributed via package remains unchanged.  Adding a single file at
`/opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/vendor/load_report_userdata.rb`
is sufficient to patch in the additional behavior.

TODO: The patching behavior may be disabled by setting the
`PUPPET_X_DISABLE_REPORT_USERDATA` environment variable to a non-empty length
string value.

# Debugging

    /opt/puppetlabs/bin/puppetserver gem install pry pry-stack_explorer --no-ri --no-rdoc
    /opt/puppetlabs/puppet/bin/gem install pry pry-stack_explorer --no-ri --no-rdoc

