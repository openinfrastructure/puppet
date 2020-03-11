require 'puppet/application'

# Extend the Puppet::Transaction::Report class to include a userdata map.  The
# schema is unspecified and reserved for use by end users.
module PuppetX
  # Extend the puppet application lifecycle methods, e.g.
  # Puppet::Application#setup, to extend the rest of the system at the correct
  # time.  The intent is to avoid race conditions.  Specifically,
  # Puppet::Configurer is not yet loaded when Puppet::Vendor executes and loads
  # this file.
  module ApplicationExtensions
    # Patch the Puppet::Transaction::Report class to include the userdata
    # attribute.
    def self.apply_report_userdata_extensions
      return if @apply_report_userdata_extensions
      Puppet::Transaction::Report.send(:include, PuppetX::ReportExtensions)
      @apply_report_userdata_extensions = true
    end

    # This function is called by a patched Application#app_defaults for the
    # agent and the report processor top level scope for the master.
    #
    # The method intentionally assumes puppet/configurer has already been
    # loaded by the agent in order to avoid affecting the load order of Puppet.
    def self.apply_catalog_enforcement_extensions
      return if @apply_catalog_enforcement_extensions
      Puppet::Configurer.send(:include, PuppetX::ConfigurerExtensions)
      @apply_report_userdata_extensions = true
    end
  end

  # Extend Puppet::Transaction::Report to contain a userdata hash populated by
  # the agent, serializable to JSON, and intended for a report processor
  # executing on the master.
  module ReportExtensions
    # User specified data stored as a Hash.  The value must be serializable to
    # JSON.  The intent of this userdata is to allow end users to embed their own
    # data into the report for use with their own custom report processors.
    #
    # @return [Hash] userdata
    attr_accessor :userdata

    def self.included(klass)
      klass.class_eval do
        alias_method :__original_initialize, :initialize

        def initialize(*args)
          @userdata = {}
          send(:__original_initialize, *args)
        end
      end
    end
  end

  # Extend Puppet::Configurer to populate Report#userdata with classes and
  # roles.  The intent is to faciliate queries over a large dataset of reports
  # selecting by role and class.
  module ConfigurerExtensions
    def self.included(klass)
      klass.class_eval do
        alias_method :__original_apply_catalog, :apply_catalog
        # Extend the behavior of apply_catalog to store the classes enforced on the
        # agent in the report so that big queries may select report data grouped by
        # classes.
        def apply_catalog(catalog, options)
          report = __original_apply_catalog(catalog, options)
          classes = catalog.classes.sort
          report.userdata[:roles] = classes.select { |s| s.start_with? "role::" }
          report.userdata[:profiles] = classes.select { |s| s.start_with? "profile::" }
          report.userdata[:classes] = classes
          report
        end
      end
    end
  end
end

class Puppet::Application
  alias_method :__original_app_defaults, :app_defaults

  # Extensions are applied from app_defaults because this is the only method
  # Puppet::Application subclasses call into their superclass.  This provides a
  # single place to perform the patching.
  #
  # Note, puppetserver does NOT trigger app_defaults and so patching is
  # performed from another location inside of puppetserver.  TODO: Mention
  # where here, currently inside the report processor itself.
  def app_defaults
    PuppetX::ApplicationExtensions.apply_report_userdata_extensions
    PuppetX::ApplicationExtensions.apply_catalog_enforcement_extensions
    self.__original_app_defaults
  end
end
